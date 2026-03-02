import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:deskclaw/constants.dart';
import 'package:deskclaw/l10n/app_localizations.dart';
import 'package:deskclaw/models/models.dart';
import 'package:deskclaw/providers/providers.dart';
import 'package:deskclaw/theme/app_theme.dart';
import 'package:deskclaw/views/chat/message_bubble.dart';
import 'package:deskclaw/views/chat/input_bar.dart';
import 'package:deskclaw/views/chat/file_attachment_bar.dart';
import 'package:deskclaw/views/chat/workspace_files_panel.dart';
import 'package:deskclaw/src/rust/api/agent_api.dart' as agent_api;
import 'package:deskclaw/src/rust/api/sessions_api.dart' as sessions_api;

/// Main chat view (right main area in reference)
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final ScrollController _scrollController = ScrollController();
  DeskClawColors get c => DeskClawColors.of(context);
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

    // Ensure there's an active session
    var sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) {
      sessionId = ref.read(sessionsProvider.notifier).createSession();
      ref.read(activeSessionIdProvider.notifier).state = sessionId;
    }

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

  /// Only scroll if the given session is the currently active one
  void _scrollToBottomIfActive(String sessionId) {
    if (ref.read(activeSessionIdProvider) == sessionId) {
      _scrollToBottom();
    }
  }

  void _handleSend(String text) {
    if (text.trim().isEmpty) return;

    // Ensure there's an active session
    var sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) {
      sessionId = ref.read(sessionsProvider.notifier).createSession();
      ref.read(activeSessionIdProvider.notifier).state = sessionId;
    }

    // Check if THIS session is already processing
    final processingSessions = ref.read(processingSessionsProvider);
    if (processingSessions.contains(sessionId)) return;

    // Add user message
    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    // Save current messages to cache before adding (ensures cache is in sync)
    ref.read(messagesProvider.notifier).saveToCache(sessionId);
    ref
        .read(messagesProvider.notifier)
        .addMessageForSession(
          sessionId,
          ref.read(activeSessionIdProvider) ?? '',
          userMsg,
        );
    ref.read(sessionsProvider.notifier).incrementMessageCount(sessionId);

    // Update session title from first user message
    final sessions = ref.read(sessionsProvider);
    final session = sessions.firstWhere((s) => s.id == sessionId);
    if (session.messageCount <= 1) {
      final title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      ref.read(sessionsProvider.notifier).updateSessionTitle(sessionId, title);
    }

    _scrollToBottom();

    // Call the real zeroclaw agent
    _callAgent(sessionId);
  }

  void _showToolApprovalDialog(
    String requestId,
    String toolName,
    String toolArgs,
  ) {
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
                  l10n.toolApprovalBody(toolName),
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
                    toolArgs,
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

  Future<void> _callAgent(String sessionId) async {
    // Mark this session as processing
    ref.read(processingSessionsProvider.notifier).state = {
      ...ref.read(processingSessionsProvider),
      sessionId,
    };

    // Add streaming placeholder to this session
    final assistantMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_assistant',
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    ref
        .read(messagesProvider.notifier)
        .addMessageForSession(
          sessionId,
          ref.read(activeSessionIdProvider) ?? '',
          assistantMsg,
        );
    _scrollToBottomIfActive(sessionId);

    try {
      // Get the last user message from this session's cache
      final messagesNotifier = ref.read(messagesProvider.notifier);
      final sessionMessages = messagesNotifier.getCachedMessages(sessionId);
      final lastUserMsg = sessionMessages.lastWhere((m) => m.isUser);

      // Helper to get current active session ID
      String activeId() => ref.read(activeSessionIdProvider) ?? '';

      // Use the streaming API for real-time updates
      final toolCalls = <ToolCallInfo>[];
      final responseBuffer = StringBuffer();

      final stream = agent_api.sendMessageStream(
        sessionId: sessionId,
        message: lastUserMsg.content,
      );

      await for (final event in stream) {
        if (!mounted) break;
        event.when(
          thinking: () {
            if (!mounted) return;
            // Show thinking indicator
            final l10n = AppLocalizations.of(context)!;
            ref
                .read(messagesProvider.notifier)
                .updateAssistantMessageForSession(
                  sessionId,
                  activeId(),
                  l10n.thinking,
                  isStreaming: true,
                );
            _scrollToBottomIfActive(sessionId);
          },
          textDelta: (text) {
            responseBuffer.write(text);
            if (!mounted) return;
            ref
                .read(messagesProvider.notifier)
                .updateAssistantMessageForSession(
                  sessionId,
                  activeId(),
                  responseBuffer.toString(),
                  isStreaming: true,
                  toolCalls: toolCalls.isNotEmpty ? List.from(toolCalls) : null,
                );
            _scrollToBottomIfActive(sessionId);
          },
          toolCallStart: (name, args) {
            toolCalls.add(
              ToolCallInfo(
                id: 'tc_${toolCalls.length}',
                name: name,
                arguments: args,
                status: ToolCallStatus.running,
              ),
            );
            if (!mounted) return;
            ref
                .read(messagesProvider.notifier)
                .updateAssistantMessageForSession(
                  sessionId,
                  activeId(),
                  responseBuffer.toString(),
                  isStreaming: true,
                  toolCalls: List.from(toolCalls),
                );
            _scrollToBottomIfActive(sessionId);
          },
          toolCallEnd: (name, result, success) {
            final idx = toolCalls.lastIndexWhere((tc) => tc.name == name);
            if (idx >= 0) {
              toolCalls[idx] = toolCalls[idx].copyWith(
                result: result,
                success: success,
                status: success
                    ? ToolCallStatus.completed
                    : ToolCallStatus.failed,
              );
            }
            if (!mounted) return;
            ref
                .read(messagesProvider.notifier)
                .updateAssistantMessageForSession(
                  sessionId,
                  activeId(),
                  responseBuffer.toString(),
                  isStreaming: true,
                  toolCalls: List.from(toolCalls),
                );
            _scrollToBottomIfActive(sessionId);
          },
          toolApprovalRequest: (requestId, name, args) {
            if (!mounted) return;
            // Show approval dialog inline - add a pending approval tool call
            toolCalls.add(
              ToolCallInfo(
                id: 'approval_$requestId',
                name: name,
                arguments: args,
                status: ToolCallStatus.running,
                result: '⏳ Waiting for approval...',
              ),
            );
            ref
                .read(messagesProvider.notifier)
                .updateAssistantMessageForSession(
                  sessionId,
                  activeId(),
                  responseBuffer.toString(),
                  isStreaming: true,
                  toolCalls: List.from(toolCalls),
                );
            _scrollToBottomIfActive(sessionId);
            // Show approval dialog
            _showToolApprovalDialog(requestId, name, args);
          },
          messageComplete: (inputTokens, outputTokens) {
            // Message is complete
          },
          error: (message) {
            if (!mounted) return;
            final l10n = AppLocalizations.of(context)!;
            responseBuffer.clear();
            responseBuffer.write(l10n.errorOccurred(message));
          },
        );
      }

      // Mark as complete
      if (mounted) {
        ref
            .read(messagesProvider.notifier)
            .updateAssistantMessageForSession(
              sessionId,
              activeId(),
              responseBuffer.toString(),
              isStreaming: false,
              toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
            );
        ref.read(sessionsProvider.notifier).incrementMessageCount(sessionId);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ref
            .read(messagesProvider.notifier)
            .updateAssistantMessageForSession(
              sessionId,
              ref.read(activeSessionIdProvider) ?? '',
              l10n.errorGeneric(e.toString()),
              isStreaming: false,
            );
      }
    } finally {
      if (mounted) {
        // Remove this session from the processing set
        final current = ref.read(processingSessionsProvider);
        ref.read(processingSessionsProvider.notifier).state = {...current}
          ..remove(sessionId);
        _scrollToBottomIfActive(sessionId);
      }
      _persistCurrentSession(sessionId);
    }
  }

  void _handleSuggestion(String text) {
    _handleSend(text);
  }

  /// Persist the current session & messages to disk via Rust
  Future<void> _persistCurrentSession(String sessionId) async {
    if (!mounted) return;
    try {
      // Use cached messages for the specific session to support background persistence
      final messagesNotifier = ref.read(messagesProvider.notifier);
      final messages = messagesNotifier.getCachedMessages(sessionId);
      final sessions = ref.read(sessionsProvider);
      final session = sessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => ChatSession(
          id: sessionId,
          title: 'Chat',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final sessionMessages = messages
          .map(
            (m) => sessions_api.SessionMessage(
              id: m.id,
              role: m.role,
              content: m.content,
              timestamp: m.timestamp.millisecondsSinceEpoch ~/ 1000,
            ),
          )
          .toList();

      await sessions_api.saveSession(
        sessionId: sessionId,
        title: session.title,
        messages: sessionMessages,
      );
    } catch (e) {
      debugPrint('Failed to persist session: $e');
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
                    ChatInputBar(onSend: _handleSend),
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

    return Container(
      height: 56 + (isMacOS ? AppConstants.macOSTopInset : 0),
      padding: EdgeInsets.only(
        left: 24,
        right: isDesktop && !isMacOS ? 152 : 24,
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
    return ListView.builder(
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
        );
      },
    );
  }

  /// Edit a user message: truncate everything after it, re-send with new text.
  void _handleEditMessage(int index, String newText) {
    final sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) return;

    // Truncate messages from [index] onward
    final current = ref.read(messagesProvider);
    final truncated = current.sublist(0, index);
    ref.read(messagesProvider.notifier).setMessages(truncated);
    ref.read(messagesProvider.notifier).saveToCache(sessionId);

    // Send the edited text as a new user message
    _handleSend(newText);
  }
}
