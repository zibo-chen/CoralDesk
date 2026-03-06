import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:coraldesk/constants.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/chat/message_bubble.dart';
import 'package:coraldesk/views/chat/input_bar.dart';
import 'package:coraldesk/views/chat/file_attachment_bar.dart';
import 'package:coraldesk/views/chat/workspace_files_panel.dart';
import 'package:coraldesk/views/chat/task_plan_overlay.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;

/// Main chat view (right main area in reference)
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final ScrollController _scrollController = ScrollController();
  CoralDeskColors get c => CoralDeskColors.of(context);
  bool _isDragging = false;
  bool _showFilesPanel = false;

  static const int _totalSuggestions = 8;
  late List<int> _selectedIndices;

  @override
  void initState() {
    super.initState();
    final pool = List<int>.generate(_totalSuggestions, (i) => i)
      ..shuffle(Random());
    _selectedIndices = pool.take(2).toList();
  }

  void _randomizeSuggestions() {
    final pool = List<int>.generate(_totalSuggestions, (i) => i)
      ..shuffle(Random());
    setState(() {
      _selectedIndices = pool.take(2).toList();
    });
  }

  /// Handle files dropped onto the chat view
  void _handleFileDrop(DropDoneDetails details) {
    final paths = details.files
        .map((f) => f.path)
        .where((p) => p.isNotEmpty)
        .toList();
    if (paths.isEmpty) return;

    final controller = ref.read(chatControllerProvider);
    var sessionId = ref.read(activeSessionIdProvider);
    sessionId ??= controller.createSession();

    ref.read(sessionFilesProvider.notifier).addFiles(sessionId, paths);
  }

  /// Load session files when switching sessions
  void _loadSessionFiles(String? sessionId) {
    if (sessionId != null) {
      ref.read(sessionFilesProvider.notifier).loadForSession(sessionId);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Stream subscriptions are managed by ChatController and survive
    // widget disposal — no stream cleanup needed here.
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String text) {
    if (text.trim().isEmpty) return;

    final controller = ref.read(chatControllerProvider);
    final result = controller.prepareAndSend(text);
    if (result == null) return; // already processing

    final l10n = AppLocalizations.of(context)!;
    _scrollToBottom();
    controller.processAgentStream(
      sessionId: result.sessionId,
      stream: result.stream,
      thinkingText: l10n.thinking,
      errorOccurredFormat: l10n.errorOccurred,
      errorGenericFormat: l10n.errorGeneric,
    );
  }

  void _showToolApprovalDialog(ToolApprovalRequest request) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.toolApprovalTitle,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.toolApprovalBody(request.toolName),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    request.toolArgs,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              agent_api.respondToToolApproval(decision: 'no');
            },
            child: Text(l10n.deny, style: const TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              agent_api.respondToToolApproval(decision: 'yes');
            },
            child: Text(l10n.approve),
          ),
        ],
      ),
    );
  }

  /// Cancel the active generation for the current session.
  void _cancelGeneration() {
    final sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) return;
    ref.read(chatControllerProvider).cancelActiveStream(sessionId);
  }

  void _handleSuggestion(String text) {
    _handleSend(text);
  }

  /// Edit a user message: truncate everything after it, re-send with new text.
  void _handleEditMessage(int index, String newText) {
    final sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) return;

    final controller = ref.read(chatControllerProvider);
    controller.truncateFrom(sessionId, index);
    _handleSend(newText);
  }

  /// Retry a message: for user messages, re-send the same content.
  /// For assistant messages, find the preceding user message and re-generate.
  void _handleRetry(int index) {
    final sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) return;

    final messages = ref.read(messagesProvider);
    if (index < 0 || index >= messages.length) return;

    final msg = messages[index];
    final controller = ref.read(chatControllerProvider);

    if (msg.isUser) {
      // Re-send user message: truncate from this message and resend
      controller.truncateFrom(sessionId, index);
      _handleSend(msg.content);
    } else if (msg.isAssistant) {
      // Regenerate assistant: find the preceding user message and resend
      int userMsgIndex = index - 1;
      while (userMsgIndex >= 0 && !messages[userMsgIndex].isUser) {
        userMsgIndex--;
      }
      if (userMsgIndex >= 0) {
        final userMsg = messages[userMsgIndex];
        // Truncate from the user message (keeping it) and resend
        controller.truncateFrom(sessionId, userMsgIndex);
        _handleSend(userMsg.content);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    ref.listen(activeSessionIdProvider, (prev, next) {
      if (prev != next) {
        _randomizeSuggestions();
        _loadSessionFiles(next);
      }
    });

    // Auto-scroll when the controller pushes new streaming content.
    ref.listen(streamScrollNotifierProvider, (prev, next) {
      if (prev != next) {
        _scrollToBottom();
      }
    });

    // Show tool-approval dialog when the controller requests it.
    ref.listen<ToolApprovalRequest?>(pendingToolApprovalProvider, (prev, next) {
      if (next != null && next != prev) {
        // Clear the provider first so re-navigation doesn't re-show it.
        ref.read(pendingToolApprovalProvider.notifier).state = null;
        _showToolApprovalDialog(next);
      }
    });

    final l10n = AppLocalizations.of(context)!;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        _handleFileDrop(details);
      },
      child: Stack(
        children: [
          Row(
            children: [
              // Main chat area
              Expanded(
                child: Column(
                  children: [
                    // Top bar
                    _buildTopBar(l10n),

                    // Main content
                    Expanded(
                      child: messages.isEmpty
                          ? _buildWelcomeView(l10n)
                          : _buildMessageList(messages),
                    ),

                    // File attachment bar
                    const FileAttachmentBar(),

                    // Input bar
                    ChatInputBar(
                      onSend: _handleSend,
                      onCancel: _cancelGeneration,
                    ),
                  ],
                ),
              ),

              // Workspace files side panel
              if (_showFilesPanel)
                WorkspaceFilesPanel(
                  onClose: () => setState(() => _showFilesPanel = false),
                ),
            ],
          ),

          // Task plan floating overlay (top-right of chat area)
          const TaskPlanOverlay(),

          // Drag overlay
          if (_isDragging) _buildDragOverlay(l10n),
        ],
      ),
    );
  }

  Widget _buildDragOverlay(AppLocalizations l10n) {
    return Positioned.fill(
      child: Container(
        color: AppColors.primary.withValues(alpha: 0.08),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            decoration: BoxDecoration(
              color: c.surfaceBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.file_upload_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.dropFilesHere,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.dropFilesHint,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    final isCollapsed = ref.watch(chatListCollapsedProvider);
    final isMacOS = AppConstants.isMacOS;
    final isDesktop = AppConstants.isDesktop;

    // 减少高度: macOS 从 56+28 减少到 48+20, Windows/Linux 从 56 减少到 48
    final topBarHeight = isMacOS ? 48 + AppConstants.macOSTopInset : 48.0;

    return Container(
      height: topBarHeight,
      padding: EdgeInsets.only(
        left: 24,
        right: isDesktop && !isMacOS ? 140 : 24,
        top: isMacOS ? AppConstants.macOSTopInset : 0,
      ),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        border: Border(bottom: BorderSide(color: c.chatListBorder, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  // Show expand button when chat list is collapsed
                  if (isCollapsed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.menu_open, size: 20),
                        color: c.textSecondary,
                        tooltip: l10n.expandHistory,
                        onPressed: () {
                          ref.read(chatListCollapsedProvider.notifier).state =
                              false;
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                  Text(
                    l10n.chatTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  // Multi-agent indicator
                  if (ref.watch(isMultiAgentProvider)) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.groups,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Team',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Toggle workspace files panel
          IconButton(
            icon: Icon(
              _showFilesPanel ? Icons.folder_open : Icons.folder_outlined,
              size: 20,
            ),
            color: _showFilesPanel ? AppColors.primary : c.textSecondary,
            tooltip: l10n.workspaceFiles,
            onPressed: () => setState(() => _showFilesPanel = !_showFilesPanel),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
          // Open workspace folder in system
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            color: c.textSecondary,
            tooltip: l10n.openWorkspaceFolder,
            onPressed: () async {
              final sessionId = ref.read(activeSessionIdProvider);
              if (sessionId == null) return;
              final dir = await agent_api.getSessionWorkspaceDir(
                sessionId: sessionId,
              );
              await agent_api.openInSystem(path: dir);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeView(AppLocalizations l10n) {
    final allSuggestions = [
      l10n.suggestionWhatCanYouDo,
      l10n.suggestionWriteArticle,
      l10n.suggestionExplainML,
      l10n.suggestionWriteEmail,
      l10n.suggestionImproveProductivity,
      l10n.suggestionRecommendBooks,
      l10n.suggestionPlanTrip,
      l10n.suggestionBrainstorm,
    ];
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo icon
            _buildWelcomeLogo(),
            const SizedBox(height: 20),

            // Welcome text
            Text(
              l10n.welcomeTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.welcomeSubtitle,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            const SizedBox(height: 32),

            // Suggestion cards (2 random from all)
            _buildSuggestionCard(allSuggestions[_selectedIndices[0]]),
            _buildSuggestionCard(allSuggestions[_selectedIndices[1]]),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeLogo() {
    return Column(
      children: [
        // Three dots on top
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(AppColors.primary, 8),
            const SizedBox(width: 6),
            _buildDot(AppColors.primaryLight, 8),
          ],
        ),
        const SizedBox(height: 8),
        // Main circle
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.textPrimary,
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 28),
        ),
      ],
    );
  }

  Widget _buildDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildSuggestionCard(String suggestion) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSuggestion(suggestion),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.chatListBorder),
              color: c.surfaceBg,
            ),
            child: Row(
              children: [
                const Icon(Icons.add, size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    suggestion,
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                  ),
                ),
                Icon(Icons.arrow_forward, size: 16, color: c.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages) {
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          return MessageBubble(
            message: msg,
            onEdit: msg.isUser
                ? (newText) => _handleEditMessage(index, newText)
                : null,
            onRetry: () => _handleRetry(index),
          );
        },
      ),
    );
  }
}
