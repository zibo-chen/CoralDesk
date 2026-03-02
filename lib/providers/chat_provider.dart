import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deskclaw/models/models.dart';
import 'package:deskclaw/services/settings_service.dart';
import 'package:deskclaw/src/rust/api/agent_api.dart' as agent_api;
import 'package:deskclaw/src/rust/api/config_api.dart' as config_api;
import 'package:deskclaw/src/rust/api/sessions_api.dart' as sessions_api;

/// Navigation section for sidebar
enum NavSection {
  chat,
  channels,
  sessions,
  cronJobs,
  workspace,
  knowledge,
  skills,
  mcp,
  agents,
  configuration,
  models,
  proxy,
}

/// Current navigation state
final currentNavProvider = StateProvider<NavSection>((ref) => NavSection.chat);

/// Current active session ID
final activeSessionIdProvider = StateProvider<String?>((ref) => null);

/// Runtime status
final runtimeStatusProvider = FutureProvider<agent_api.RuntimeStatus>((
  ref,
) async {
  return await agent_api.getRuntimeStatus();
});

/// Current config from Rust
final configProvider = FutureProvider<config_api.AppConfig>((ref) async {
  return await config_api.loadConfig();
});

/// All chat sessions
final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, List<ChatSession>>((ref) {
      return SessionsNotifier();
    });

class SessionsNotifier extends StateNotifier<List<ChatSession>> {
  SessionsNotifier() : super([]);

  /// Load persisted sessions from Rust session store on app startup
  Future<void> loadPersistedSessions() async {
    try {
      final summaries = await sessions_api.listSessions();
      if (summaries.isNotEmpty) {
        final loaded = summaries
            .map(
              (s) => ChatSession(
                id: s.id,
                title: s.title,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  (s.createdAt * 1000).toInt(),
                ),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  (s.updatedAt * 1000).toInt(),
                ),
                messageCount: s.messageCount.toInt(),
                attachedFiles: s.attachedFiles,
              ),
            )
            .toList();
        state = loaded;
      }
    } catch (e) {
      debugPrint('Failed to load persisted sessions: $e');
    }
  }

  String createSession() {
    final now = DateTime.now();
    final id = 'session_${now.millisecondsSinceEpoch}';
    final session = ChatSession(
      id: id,
      title: 'New Chat',
      createdAt: now,
      updatedAt: now,
    );
    state = [session, ...state];
    return id;
  }

  void updateSessionTitle(String id, String title) {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(title: title, updatedAt: DateTime.now());
      }
      return s;
    }).toList();
  }

  void deleteSession(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  void incrementMessageCount(String id) {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(
          messageCount: s.messageCount + 1,
          updatedAt: DateTime.now(),
        );
      }
      return s;
    }).toList();
  }
}

/// Messages for the active session
final messagesProvider =
    StateNotifierProvider<MessagesNotifier, List<ChatMessage>>((ref) {
      return MessagesNotifier();
    });

class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  MessagesNotifier() : super([]);

  /// In-memory cache of messages per session
  final Map<String, List<ChatMessage>> _sessionMessages = {};

  /// Get messages from the cache for a specific session
  List<ChatMessage> getCachedMessages(String sessionId) {
    return _sessionMessages[sessionId] ?? state;
  }

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  void updateLastAssistantMessage(
    String content, {
    bool? isStreaming,
    List<ToolCallInfo>? toolCalls,
  }) {
    if (state.isEmpty) return;
    final last = state.last;
    if (last.isAssistant) {
      state = [
        ...state.sublist(0, state.length - 1),
        last.copyWith(
          content: content,
          isStreaming: isStreaming ?? last.isStreaming,
          toolCalls: toolCalls ?? last.toolCalls,
        ),
      ];
    }
  }

  /// Save current messages to memory cache for a session
  void saveToCache(String sessionId) {
    _sessionMessages[sessionId] = List.from(state);
  }

  /// Load messages from memory cache, or set from persisted data
  void loadFromCache(String sessionId) {
    final cached = _sessionMessages[sessionId];
    if (cached != null) {
      state = List.from(cached);
    } else {
      state = [];
    }
  }

  /// Set messages directly (e.g. from persisted session)
  void setMessages(List<ChatMessage> messages) {
    state = messages;
  }

  /// Remove cached messages for a session
  void removeFromCache(String sessionId) {
    _sessionMessages.remove(sessionId);
  }

  void clear() {
    state = [];
  }

  /// Update the last assistant message in a specific session's cache.
  /// If the session is currently active, also update the global state.
  void updateAssistantMessageForSession(
    String sessionId,
    String activeSessionId,
    String content, {
    bool? isStreaming,
    List<ToolCallInfo>? toolCalls,
  }) {
    // Always update the cache
    final cached = _sessionMessages[sessionId];
    if (cached != null && cached.isNotEmpty) {
      final last = cached.last;
      if (last.isAssistant) {
        cached[cached.length - 1] = last.copyWith(
          content: content,
          isStreaming: isStreaming ?? last.isStreaming,
          toolCalls: toolCalls ?? last.toolCalls,
        );
      }
    }
    // If this session is the currently visible session, also update the UI state
    if (sessionId == activeSessionId) {
      updateLastAssistantMessage(
        content,
        isStreaming: isStreaming,
        toolCalls: toolCalls,
      );
    }
  }

  /// Add a message to a specific session's cache.
  /// If the session is currently active, also update the global state.
  void addMessageForSession(
    String sessionId,
    String activeSessionId,
    ChatMessage message,
  ) {
    // Always update the cache
    _sessionMessages.putIfAbsent(sessionId, () => []);
    _sessionMessages[sessionId]!.add(message);
    // If this session is the currently visible session, also update the UI state
    if (sessionId == activeSessionId) {
      addMessage(message);
    }
  }
}

/// Set of session IDs that are currently processing
final processingSessionsProvider = StateProvider<Set<String>>((ref) => {});

/// Convenience: whether the currently active session is processing
final isCurrentSessionProcessingProvider = Provider<bool>((ref) {
  final activeId = ref.watch(activeSessionIdProvider);
  final processing = ref.watch(processingSessionsProvider);
  if (activeId == null) return false;
  return processing.contains(activeId);
});

/// Language / Locale setting — initialised from persisted preference
final localeProvider = StateProvider<Locale>(
  (ref) => Locale(SettingsService.locale),
);

/// Theme mode — initialised from persisted preference
final themeModeProvider = StateProvider<ThemeMode>(
  (ref) =>
      SettingsService.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
);

/// Whether the chat list panel is collapsed
final chatListCollapsedProvider = StateProvider<bool>((ref) => false);

/// Whether the left sidebar is collapsed to icon rail
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Attached files for the active session
final sessionFilesProvider =
    StateNotifierProvider<SessionFilesNotifier, List<String>>((ref) {
      return SessionFilesNotifier();
    });

class SessionFilesNotifier extends StateNotifier<List<String>> {
  SessionFilesNotifier() : super([]);

  /// In-memory cache of files per session
  final Map<String, List<String>> _sessionFiles = {};

  /// Load files from Rust session store for a given session
  Future<void> loadForSession(String sessionId) async {
    // Check memory cache first
    if (_sessionFiles.containsKey(sessionId)) {
      state = List.from(_sessionFiles[sessionId]!);
      return;
    }
    try {
      final files = await sessions_api.getSessionFiles(sessionId: sessionId);
      _sessionFiles[sessionId] = List.from(files);
      state = List.from(files);
    } catch (e) {
      debugPrint('Failed to load session files: $e');
      state = [];
    }
  }

  /// Add files to the active session
  Future<void> addFiles(String sessionId, List<String> paths) async {
    try {
      final updated = await sessions_api.addSessionFiles(
        sessionId: sessionId,
        filePaths: paths,
      );
      _sessionFiles[sessionId] = List.from(updated);
      state = List.from(updated);
    } catch (e) {
      debugPrint('Failed to add session files: $e');
    }
  }

  /// Remove a file from the active session
  Future<void> removeFile(String sessionId, String path) async {
    try {
      final updated = await sessions_api.removeSessionFile(
        sessionId: sessionId,
        filePath: path,
      );
      _sessionFiles[sessionId] = List.from(updated);
      state = List.from(updated);
    } catch (e) {
      debugPrint('Failed to remove session file: $e');
    }
  }

  /// Clear all files for a session
  Future<void> clearFiles(String sessionId) async {
    try {
      await sessions_api.clearSessionFiles(sessionId: sessionId);
      _sessionFiles[sessionId] = [];
      state = [];
    } catch (e) {
      debugPrint('Failed to clear session files: $e');
    }
  }

  /// Switch active view to another session's files
  void switchSession(String sessionId) {
    state = List.from(_sessionFiles[sessionId] ?? []);
  }

  /// Remove cache for a deleted session
  void removeCache(String sessionId) {
    _sessionFiles.remove(sessionId);
  }
}
