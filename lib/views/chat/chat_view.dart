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

    final controller = ref.read(chatControllerProvider);
    final result = controller.prepareAndSend(text);
    if (result == null) return; // already processing

    _scrollToBottom();
    _callAgent(result.sessionId, result.stream);
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

  Future<void> _callAgent(
    String sessionId,
    Stream<agent_api.AgentEvent> stream,
  ) async {
    final controller = ref.read(chatControllerProvider);
    _scrollToBottomIfActive(sessionId);

    // ── Parts-based accumulation ─────────────────────────
    final parts = <MessagePart>[];
    var currentTextBuffer = StringBuffer();
    var isThinking = false;

    /// Regex to strip raw tool-call XML/JSON tags that some providers
    /// leak into the text stream (e.g. <tool_call>…</tool_call>,
    /// <|tool▁call|>, {"name":…,"arguments":…} blocks, etc.)
    final toolCallTagPattern = RegExp(
      r'<\s*tool_call\s*>[\s\S]*?<\s*/\s*tool_call\s*>'
      r'|<\|tool[▁_]call\|>[\s\S]*?$'
      r'|\{[\s\S]*?"(?:name|function)"[\s\S]*?"arguments"[\s\S]*?\}',
      caseSensitive: false,
    );

    /// Ensure the last part is a TextPart reflecting currentTextBuffer.
    void ensureTextPart() {
      if (parts.isEmpty || parts.last is! TextPart) {
        parts.add(TextPart(currentTextBuffer.toString()));
      } else {
        parts[parts.length - 1] = TextPart(currentTextBuffer.toString());
      }
    }

    /// Finalise the current text segment (push it to parts) and start a
    /// fresh buffer.  This is called before adding a ToolCallPart so that
    /// text and tool-call segments don't overlap.
    void finalizeCurrentTextSegment() {
      if (currentTextBuffer.isNotEmpty) {
        ensureTextPart();
      }
      currentTextBuffer = StringBuffer();
    }

    /// Remove a "Thinking…" placeholder when real content arrives.
    void clearThinkingIfNeeded() {
      if (isThinking) {
        isThinking = false;
        currentTextBuffer.clear();
        if (parts.isNotEmpty && parts.last is TextPart) {
          parts.removeLast();
        }
      }
    }

    /// Derive a flat content string from parts (for persistence / copy).
    String computeContent() {
      return parts
          .whereType<TextPart>()
          .map((p) => p.text)
          .where((t) => t.isNotEmpty)
          .join('\n\n');
    }

    /// Derive a flat tool-call list from parts (for persistence).
    List<ToolCallInfo>? computeToolCalls() {
      final tcs = parts
          .whereType<ToolCallPart>()
          .map((p) => p.toolCall)
          .toList();
      return tcs.isNotEmpty ? tcs : null;
    }

    /// Push current state to the UI.
    void updateUI() {
      if (!mounted) return;
      controller.updateStreamingContent(
        sessionId,
        computeContent(),
        toolCalls: computeToolCalls(),
        parts: List<MessagePart>.from(parts),
      );
      _scrollToBottomIfActive(sessionId);
    }

    try {
      await for (final event in stream) {
        if (!mounted) break;
        event.when(
          thinking: () {
            if (!mounted) return;
            final l10n = AppLocalizations.of(context)!;
            // If we are already showing a thinking placeholder, refresh it in
            // place instead of appending another one.
            if (isThinking) {
              currentTextBuffer = StringBuffer(l10n.thinking);
              if (parts.isNotEmpty && parts.last is TextPart) {
                parts[parts.length - 1] = TextPart(
                  currentTextBuffer.toString(),
                );
              } else {
                parts.add(TextPart(currentTextBuffer.toString()));
              }
              updateUI();
              return;
            }
            // Finalise any real text from the previous segment so it is not
            // overwritten by the "Thinking…" placeholder.
            finalizeCurrentTextSegment();
            currentTextBuffer = StringBuffer(l10n.thinking);
            isThinking = true;
            // Always add a NEW TextPart (previous text is already saved).
            parts.add(TextPart(currentTextBuffer.toString()));
            updateUI();
          },
          textDelta: (text) {
            clearThinkingIfNeeded();
            currentTextBuffer.write(text);
            ensureTextPart();
            updateUI();
          },
          clearStreamedContent: () {
            // The CLEAR sentinel means the streamed text *might* contain
            // raw <tool_call> XML tags that should not be shown.  Instead
            // of wholesale removal (which causes visible content flashing),
            // strip only the known tag patterns and keep clean text.
            isThinking = false;
            final raw = currentTextBuffer.toString();
            final cleaned = raw.replaceAll(toolCallTagPattern, '').trim();
            if (cleaned.isEmpty) {
              // Nothing useful left — remove the text segment entirely.
              currentTextBuffer.clear();
              if (parts.isNotEmpty && parts.last is TextPart) {
                parts.removeLast();
              }
            } else {
              // Keep the clean portion.
              currentTextBuffer = StringBuffer(cleaned);
              ensureTextPart();
            }
            updateUI();
          },
          toolCallStart: (name, args) {
            clearThinkingIfNeeded();
            // Finalise current text (if any) into its own part.
            finalizeCurrentTextSegment();

            final tc = ToolCallInfo(
              id: 'tc_${parts.whereType<ToolCallPart>().length}',
              name: name,
              arguments: args,
              status: ToolCallStatus.running,
            );
            parts.add(ToolCallPart(tc));
            updateUI();
          },
          toolCallEnd: (name, result, success) {
            // Match the last *running* tool with this name (handles same-name
            // tools like two "shell" calls in one turn).
            for (int i = parts.length - 1; i >= 0; i--) {
              final part = parts[i];
              if (part is ToolCallPart &&
                  part.toolCall.name == name &&
                  part.toolCall.status == ToolCallStatus.running) {
                parts[i] = ToolCallPart(
                  part.toolCall.copyWith(
                    result: result,
                    success: success,
                    status: success
                        ? ToolCallStatus.completed
                        : ToolCallStatus.failed,
                  ),
                );
                break;
              }
            }
            updateUI();
          },
          toolApprovalRequest: (requestId, name, args) {
            if (!mounted) return;
            clearThinkingIfNeeded();
            finalizeCurrentTextSegment();

            final tc = ToolCallInfo(
              id: 'approval_$requestId',
              name: name,
              arguments: args,
              status: ToolCallStatus.running,
              result: '⏳ Waiting for approval...',
            );
            parts.add(ToolCallPart(tc));
            updateUI();
            _showToolApprovalDialog(requestId, name, args);
          },
          messageComplete: (inputTokens, outputTokens) {
            // Message is complete
          },
          error: (message) {
            if (!mounted) return;
            final l10n = AppLocalizations.of(context)!;
            clearThinkingIfNeeded();
            if (currentTextBuffer.isNotEmpty) {
              currentTextBuffer.writeln();
              currentTextBuffer.writeln();
            }
            currentTextBuffer.write(l10n.errorOccurred(message));
            ensureTextPart();
          },
        );
      }

      // Mark as complete
      if (mounted) {
        controller.finishAgentTurn(
          sessionId,
          computeContent(),
          toolCalls: computeToolCalls(),
          parts: List<MessagePart>.from(parts),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        controller.handleAgentError(sessionId, l10n.errorGeneric(e.toString()));
      }
    } finally {
      if (mounted) _scrollToBottomIfActive(sessionId);
    }
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
