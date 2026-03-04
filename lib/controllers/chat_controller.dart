import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/providers/chat_provider.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/sessions_api.dart' as sessions_api;

/// Riverpod provider for [ChatController].
final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController(ref);
});

/// Orchestrates chat session lifecycle and agent interaction.
///
/// This controller encapsulates the multi-step workflows that previously
/// lived inside [ChatView] and [ChatListPanel]:
///   - Creating / switching / deleting sessions
///   - Preparing and finishing agent message turns
///   - Persisting sessions to the Rust store
///
/// UI-specific concerns (dialog display, scrolling, l10n strings) remain
/// in the view — the controller returns data needed for those decisions.
class ChatController {
  final Ref _ref;

  const ChatController(this._ref);

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
    _ref
        .read(messagesProvider.notifier)
        .stopStreaming(sessionId);
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
