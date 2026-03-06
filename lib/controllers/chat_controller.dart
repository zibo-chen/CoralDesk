import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/providers/chat_provider.dart';
import 'package:coraldesk/providers/task_plan_provider.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/sessions_api.dart' as sessions_api;

/// Riverpod provider for [ChatController].
final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController(ref);
});

/// A pending tool-approval request that the UI should display.
class ToolApprovalRequest {
  final String sessionId;
  final String requestId;
  final String toolName;
  final String toolArgs;
  const ToolApprovalRequest({
    required this.sessionId,
    required this.requestId,
    required this.toolName,
    required this.toolArgs,
  });
}

/// Provider that surfaces a pending tool-approval request to the UI.
/// The [ChatController] writes to it; [ChatView] watches and shows a dialog.
final pendingToolApprovalProvider = StateProvider<ToolApprovalRequest?>(
  (ref) => null,
);

/// Provider that carries a counter incremented every time new streaming
/// content arrives, so views can trigger auto-scroll without coupling to
/// the stream lifecycle.
final streamScrollNotifierProvider = StateProvider<int>((ref) => 0);

/// Orchestrates chat session lifecycle and agent interaction.
///
/// This controller encapsulates the multi-step workflows that previously
/// lived inside [ChatView] and [ChatListPanel]:
///   - Creating / switching / deleting sessions
///   - Preparing and finishing agent message turns
///   - Managing agent stream subscriptions (independent of widget lifecycle)
///   - Persisting sessions to the Rust store
///
/// UI-specific concerns (dialog display, scrolling, l10n strings) remain
/// in the view — the controller returns data needed for those decisions.
class ChatController {
  final Ref _ref;

  ChatController(this._ref);

  // ── Active stream state (per session) ──────────────────
  static final Map<String, _SessionStreamState> _activeStreams = {};

  // ── Session lifecycle ──────────────────────────────────

  /// Create a new session and switch to it.  Returns the new session ID.
  String createSession() {
    // Save current session if any
    _ref.read(messagesProvider.notifier).syncActiveToCache();
    final id = _ref.read(sessionsProvider.notifier).createSession();
    _ref.read(activeSessionIdProvider.notifier).state = id;
    _ref.read(messagesProvider.notifier).switchToSession(id);
    return id;
  }

  /// Switch to an existing session.  Handles cache save/load, Rust-side
  /// context switch, and loading persisted messages when the cache is empty.
  Future<void> switchSession(String sessionId) async {
    final currentId = _ref.read(activeSessionIdProvider);
    if (currentId == sessionId) return;

    // Atomic save + load
    _ref.read(messagesProvider.notifier).switchToSession(sessionId);

    // Switch task plan context
    _ref.read(taskPlanProvider.notifier).switchToSession(sessionId);

    // Update active ID
    _ref.read(activeSessionIdProvider.notifier).state = sessionId;

    // Switch Rust-side agent context
    agent_api.switchSession(sessionId: sessionId);

    // Load attached files for the session
    _ref.read(sessionFilesProvider.notifier).loadForSession(sessionId);

    // If memory cache was empty, try loading from persistent store
    if (_ref.read(messagesProvider).isEmpty) {
      try {
        final detail = await sessions_api.getSessionDetail(
          sessionId: sessionId,
        );
        if (detail != null && detail.messages.isNotEmpty) {
          final messages = detail.messages
              .map(
                (m) => ChatMessage(
                  id: m.id,
                  role: m.role,
                  content: m.content,
                  timestamp: DateTime.fromMillisecondsSinceEpoch(
                    (m.timestamp * 1000).toInt(),
                  ),
                ),
              )
              .toList();
          _ref
              .read(messagesProvider.notifier)
              .setSessionMessages(sessionId, messages);
        }
      } catch (_) {
        // If loading fails, show empty
      }
    }
  }

  /// Delete a session and clean up all associated state.
  void deleteSession(String sessionId) {
    final isActive = _ref.read(activeSessionIdProvider) == sessionId;
    _ref.read(sessionsProvider.notifier).deleteSession(sessionId);
    _ref.read(messagesProvider.notifier).removeSession(sessionId);
    _ref.read(sessionFilesProvider.notifier).removeCache(sessionId);
    _ref.read(taskPlanProvider.notifier).removeSession(sessionId);
    if (isActive) {
      _ref.read(activeSessionIdProvider.notifier).state = null;
      agent_api.clearSession();
    }
  }

  // ── Agent message send ─────────────────────────────────

  /// Prepare a user message and start a streaming agent turn.
  ///
  /// Returns the session ID and the event stream, or `null` if the session
  /// is already processing.  After consuming the stream, the caller **must**
  /// call [finishAgentTurn] or [handleAgentError].
  ({String sessionId, Stream<agent_api.AgentEvent> stream})? prepareAndSend(
    String text,
  ) {
    // Ensure active session exists
    var sessionId = _ref.read(activeSessionIdProvider);
    sessionId ??= createSession();

    // Guard against double-submit
    final processing = _ref.read(processingSessionsProvider);
    if (processing.contains(sessionId)) return null;

    // Add user message
    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    _ref
        .read(messagesProvider.notifier)
        .addMessageToSession(sessionId, userMsg);
    _ref.read(sessionsProvider.notifier).incrementMessageCount(sessionId);

    // Auto-title from first user message
    final sessions = _ref.read(sessionsProvider);
    final session = sessions.firstWhere((s) => s.id == sessionId);
    if (session.messageCount <= 1) {
      final title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      _ref.read(sessionsProvider.notifier).updateSessionTitle(sessionId, title);
    }

    // Mark session as processing
    _ref.read(processingSessionsProvider.notifier).state = {
      ..._ref.read(processingSessionsProvider),
      sessionId,
    };

    // Add streaming assistant placeholder
    final assistantMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_assistant',
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    _ref
        .read(messagesProvider.notifier)
        .addMessageToSession(sessionId, assistantMsg);

    // Open the stream
    final stream = agent_api.sendMessageStream(
      sessionId: sessionId,
      message: text,
    );

    return (sessionId: sessionId, stream: stream);
  }

  // ── Agent stream processing (widget-lifecycle independent) ──

  /// Regex to strip raw tool-call XML/JSON tags that some providers
  /// leak into the text stream.
  static final _toolCallTagPattern = RegExp(
    r'<\s*tool_call\s*>[\s\S]*?<\s*/\s*tool_call\s*>'
    r'|<\|tool[▁_]call\|>[\s\S]*?$'
    r'|\{[\s\S]*?"(?:name|function)"[\s\S]*?"arguments"[\s\S]*?\}',
    caseSensitive: false,
  );

  /// Start processing an agent event stream for [sessionId].
  ///
  /// The stream subscription is managed here, **not** in the widget, so it
  /// survives navigation.  [thinkingText] and [errorOccurredFormat] are
  /// the already-localised strings captured at call-site.
  void processAgentStream({
    required String sessionId,
    required Stream<agent_api.AgentEvent> stream,
    required String thinkingText,
    required String Function(String) errorOccurredFormat,
    required String Function(String) errorGenericFormat,
  }) {
    // Cancel a previous stream for the same session (shouldn't normally
    // happen because of the processing guard, but be safe).
    _activeStreams[sessionId]?.subscription.cancel();

    final state = _SessionStreamState(
      sessionId: sessionId,
      thinkingText: thinkingText,
      errorOccurredFormat: errorOccurredFormat,
    );

    state.subscription = stream.listen(
      (event) => _handleStreamEvent(state, event),
      onDone: () => _handleStreamDone(state),
      onError: (e) =>
          _handleStreamError(state, errorGenericFormat(e.toString())),
    );

    _activeStreams[sessionId] = state;
  }

  /// Whether [sessionId] has an active agent stream.
  bool hasActiveStream(String sessionId) =>
      _activeStreams.containsKey(sessionId);

  /// Cancel an active stream initiated by the user (stop button).
  void cancelActiveStream(String sessionId) {
    final state = _activeStreams.remove(sessionId);
    if (state != null) {
      state.subscription.cancel();
      agent_api.cancelGeneration(sessionId: sessionId);
      cancelGeneration(sessionId);
    }
  }

  // ── Stream event handlers ──────────────────────────────

  void _handleStreamEvent(_SessionStreamState s, agent_api.AgentEvent event) {
    event.when(
      thinking: () {
        if (s.isThinking) {
          s.currentTextBuffer = StringBuffer(s.thinkingText);
          if (s.parts.isNotEmpty && s.parts.last is TextPart) {
            s.parts[s.parts.length - 1] = TextPart(
              s.currentTextBuffer.toString(),
            );
          } else {
            s.parts.add(TextPart(s.currentTextBuffer.toString()));
          }
          _pushStreamState(s);
          return;
        }
        s.finalizeCurrentTextSegment();
        s.currentTextBuffer = StringBuffer(s.thinkingText);
        s.isThinking = true;
        s.parts.add(TextPart(s.currentTextBuffer.toString()));
        _pushStreamState(s);
      },
      textDelta: (text, roleName) {
        s.clearThinkingIfNeeded();
        s.currentTextBuffer.write(text);
        s.ensureTextPart();
        // Track the current role for multi-agent sessions
        if (roleName != null) {
          s.currentRole = roleName;
        }
        _pushStreamState(s);
      },
      clearStreamedContent: () {
        s.isThinking = false;
        final raw = s.currentTextBuffer.toString();
        final cleaned = raw.replaceAll(_toolCallTagPattern, '').trim();
        if (cleaned.isEmpty) {
          s.currentTextBuffer.clear();
          if (s.parts.isNotEmpty && s.parts.last is TextPart) {
            s.parts.removeLast();
          }
        } else {
          s.currentTextBuffer = StringBuffer(cleaned);
          s.ensureTextPart();
        }
        _pushStreamState(s);
      },
      toolCallStart: (name, args, roleName) {
        s.clearThinkingIfNeeded();
        s.finalizeCurrentTextSegment();
        final tc = ToolCallInfo(
          id: 'tc_${s.parts.whereType<ToolCallPart>().length}',
          name: name,
          arguments: args,
          status: ToolCallStatus.running,
        );
        s.parts.add(ToolCallPart(tc));
        // Track task_plan args for later processing
        if (name == 'task_plan') {
          s.pendingTaskPlanArgs = args;
        }
        _pushStreamState(s);
      },
      toolCallEnd: (name, result, success) {
        for (int i = s.parts.length - 1; i >= 0; i--) {
          final part = s.parts[i];
          if (part is ToolCallPart &&
              part.toolCall.name == name &&
              part.toolCall.status == ToolCallStatus.running) {
            s.parts[i] = ToolCallPart(
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
        // Intercept task_plan tool calls to update the overlay state
        if (name == 'task_plan' && success) {
          _ref
              .read(taskPlanProvider.notifier)
              .processToolCall(s.pendingTaskPlanArgs ?? '{}', result);
          s.pendingTaskPlanArgs = null;
        }
        _pushStreamState(s);
      },
      toolApprovalRequest: (requestId, name, args) {
        s.clearThinkingIfNeeded();
        s.finalizeCurrentTextSegment();
        final tc = ToolCallInfo(
          id: 'approval_$requestId',
          name: name,
          arguments: args,
          status: ToolCallStatus.running,
          result: '⏳ Waiting for approval...',
        );
        s.parts.add(ToolCallPart(tc));
        _pushStreamState(s);
        // Notify UI to show approval dialog
        _ref
            .read(pendingToolApprovalProvider.notifier)
            .state = ToolApprovalRequest(
          sessionId: s.sessionId,
          requestId: requestId,
          toolName: name,
          toolArgs: args,
        );
      },
      roleSwitch: (roleName, roleColor, roleIcon) {
        // Finalize any pending text before inserting the role header
        s.finalizeCurrentTextSegment();
        s.currentRole = roleName;
        s.parts.add(
          RoleHeaderPart(
            roleName: roleName,
            roleColor: roleColor,
            roleIcon: roleIcon,
          ),
        );
        _pushStreamState(s);
      },
      roleHandoff: (fromRole, toRole, summary) {
        // Insert a handoff marker between role sections
        s.finalizeCurrentTextSegment();
        s.parts.add(
          RoleHandoffPart(fromRole: fromRole, toRole: toRole, summary: summary),
        );
        _pushStreamState(s);
      },
      messageComplete: (inputTokens, outputTokens) {
        // Message is complete — onDone will finalise.
      },
      error: (message) {
        s.clearThinkingIfNeeded();
        if (s.currentTextBuffer.isNotEmpty) {
          s.currentTextBuffer.writeln();
          s.currentTextBuffer.writeln();
        }
        s.currentTextBuffer.write(s.errorOccurredFormat(message));
        s.ensureTextPart();
        // Don't push yet — onDone/onError will finalise.
      },
    );
  }

  void _handleStreamDone(_SessionStreamState s) {
    _activeStreams.remove(s.sessionId);
    finishAgentTurn(
      s.sessionId,
      s.computeContent(),
      toolCalls: s.computeToolCalls(),
      parts: List<MessagePart>.from(s.parts),
    );
  }

  void _handleStreamError(_SessionStreamState s, String errorMessage) {
    _activeStreams.remove(s.sessionId);
    handleAgentError(s.sessionId, errorMessage);
  }

  /// Push the current accumulated state to the messages provider and
  /// bump the scroll notifier so the UI can auto-scroll.
  void _pushStreamState(_SessionStreamState s) {
    updateStreamingContent(
      s.sessionId,
      s.computeContent(),
      toolCalls: s.computeToolCalls(),
      parts: List<MessagePart>.from(s.parts),
    );
    // Bump scroll notifier
    _ref.read(streamScrollNotifierProvider.notifier).state++;
  }

  /// Update the assistant bubble while streaming.
  void updateStreamingContent(
    String sessionId,
    String content, {
    bool isStreaming = true,
    List<ToolCallInfo>? toolCalls,
    List<MessagePart>? parts,
  }) {
    _ref
        .read(messagesProvider.notifier)
        .updateAssistant(
          sessionId,
          content,
          isStreaming: isStreaming,
          toolCalls: toolCalls,
          parts: parts,
        );
  }

  /// Finalise a successful agent turn.
  void finishAgentTurn(
    String sessionId,
    String content, {
    List<ToolCallInfo>? toolCalls,
    List<MessagePart>? parts,
  }) {
    _ref
        .read(messagesProvider.notifier)
        .updateAssistant(
          sessionId,
          content,
          isStreaming: false,
          toolCalls: toolCalls,
          parts: parts,
        );
    _ref.read(sessionsProvider.notifier).incrementMessageCount(sessionId);
    _clearProcessing(sessionId);
    persistSession(sessionId);
  }

  /// Finalise a failed agent turn.
  void handleAgentError(String sessionId, String errorMessage) {
    _ref
        .read(messagesProvider.notifier)
        .updateAssistant(sessionId, errorMessage, isStreaming: false);
    _clearProcessing(sessionId);
    persistSession(sessionId);
  }

  /// Cancel an active generation: mark the assistant message as complete
  /// with whatever content has been streamed so far.
  void cancelGeneration(String sessionId) {
    _ref.read(messagesProvider.notifier).stopStreaming(sessionId);
    _clearProcessing(sessionId);
    persistSession(sessionId);
  }

  void _clearProcessing(String sessionId) {
    final current = _ref.read(processingSessionsProvider);
    _ref.read(processingSessionsProvider.notifier).state = {...current}
      ..remove(sessionId);
  }

  // ── Message editing ────────────────────────────────────

  /// Truncate the conversation from [index] and return the truncated list.
  void truncateFrom(String sessionId, int index) {
    final current = _ref.read(messagesProvider);
    final truncated = current.sublist(0, index);
    _ref
        .read(messagesProvider.notifier)
        .setSessionMessages(sessionId, truncated);
  }

  // ── Persistence ────────────────────────────────────────

  /// Persist a session's messages to Rust-side storage.
  Future<void> persistSession(String sessionId) async {
    try {
      final messages = _ref
          .read(messagesProvider.notifier)
          .getSessionMessages(sessionId);
      final sessions = _ref.read(sessionsProvider);
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
}

// ── Per-session stream accumulation state ─────────────────

class _SessionStreamState {
  final String sessionId;
  final String thinkingText;
  final String Function(String) errorOccurredFormat;

  late StreamSubscription<agent_api.AgentEvent> subscription;

  final List<MessagePart> parts = [];
  StringBuffer currentTextBuffer = StringBuffer();
  bool isThinking = false;

  /// The current delegate agent role name (null = main agent).
  String? currentRole;

  /// Pending task_plan tool call arguments (saved at toolCallStart,
  /// consumed at toolCallEnd).
  String? pendingTaskPlanArgs;

  _SessionStreamState({
    required this.sessionId,
    required this.thinkingText,
    required this.errorOccurredFormat,
  });

  void ensureTextPart() {
    if (parts.isEmpty || parts.last is! TextPart) {
      parts.add(TextPart(currentTextBuffer.toString()));
    } else {
      parts[parts.length - 1] = TextPart(currentTextBuffer.toString());
    }
  }

  void finalizeCurrentTextSegment() {
    if (currentTextBuffer.isNotEmpty) {
      ensureTextPart();
    }
    currentTextBuffer = StringBuffer();
  }

  void clearThinkingIfNeeded() {
    if (isThinking) {
      isThinking = false;
      currentTextBuffer.clear();
      if (parts.isNotEmpty && parts.last is TextPart) {
        parts.removeLast();
      }
    }
  }

  String computeContent() {
    return parts
        .whereType<TextPart>()
        .map((p) => p.text)
        .where((t) => t.isNotEmpty)
        .join('\n\n');
  }

  List<ToolCallInfo>? computeToolCalls() {
    final tcs = parts.whereType<ToolCallPart>().map((p) => p.toolCall).toList();
    return tcs.isNotEmpty ? tcs : null;
  }
}
