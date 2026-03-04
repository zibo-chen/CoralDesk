import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/services/settings_service.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/config_api.dart' as config_api;
import 'package:coraldesk/src/rust/api/sessions_api.dart' as sessions_api;

// ── Navigation ───────────────────────────────────────────

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

// ── Runtime / Config ─────────────────────────────────────

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

// ── Sessions ─────────────────────────────────────────────

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

// ── Messages (refactored — single source of truth) ──────

/// Messages for the active session.
///
/// The notifier keeps an internal per-session cache so that background
/// sessions retain their messages even when not visible.
/// Callers should **not** manually save/load the cache — use
/// [switchToSession] for atomic session switches.
final messagesProvider =
    StateNotifierProvider<MessagesNotifier, List<ChatMessage>>((ref) {
      return MessagesNotifier();
    });

class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  MessagesNotifier() : super([]);

  /// Per-session message cache.
  final Map<String, List<ChatMessage>> _cache = {};

  /// The session whose messages are currently exposed as [state].
  String? _activeSessionId;

  // ── Session switching (atomic) ──────────────────────────

  /// Atomically save the current session and load [sessionId].
  void switchToSession(String? sessionId) {
    // Save current
    _flushActiveToCache();
    _activeSessionId = sessionId;
    // Load new
    if (sessionId != null) {
      state = List.from(_cache[sessionId] ?? []);
    } else {
      state = [];
    }
  }

  /// Flush active session state into the cache (called internally and
  /// before persistence).
  void syncActiveToCache() => _flushActiveToCache();

  void _flushActiveToCache() {
    if (_activeSessionId != null) {
      _cache[_activeSessionId!] = List.from(state);
    }
  }

  // ── Mutations (session-aware) ──────────────────────────

  /// Add a message to a specific session.
  void addMessageToSession(String sessionId, ChatMessage message) {
    _cache.putIfAbsent(sessionId, () => []);
    _cache[sessionId]!.add(message);
    if (sessionId == _activeSessionId) {
      state = List.from(_cache[sessionId]!);
    }
  }

  /// Update the last assistant message in a specific session.
  void updateAssistant(
    String sessionId,
    String content, {
    bool? isStreaming,
    List<ToolCallInfo>? toolCalls,
    List<MessagePart>? parts,
  }) {
    final messages = _cache[sessionId];
    if (messages != null && messages.isNotEmpty && messages.last.isAssistant) {
      messages[messages.length - 1] = messages.last.copyWith(
        content: content,
        isStreaming: isStreaming ?? messages.last.isStreaming,
        toolCalls: toolCalls ?? messages.last.toolCalls,
        parts: parts,
      );
    }
    if (sessionId == _activeSessionId) {
      state = List.from(_cache[sessionId] ?? []);
    }
  }

  /// Stop streaming for the last assistant message in a specific session.
  /// Keeps whatever content has been accumulated so far.
  void stopStreaming(String sessionId) {
    final messages = _cache[sessionId];
    if (messages != null && messages.isNotEmpty && messages.last.isAssistant) {
      messages[messages.length - 1] = messages.last.copyWith(
        isStreaming: false,
      );
    }
    if (sessionId == _activeSessionId) {
      state = List.from(_cache[sessionId] ?? []);
    }
  }

  // ── Read helpers ───────────────────────────────────────

  /// Get all messages for a session (used for persistence).
  List<ChatMessage> getSessionMessages(String sessionId) {
    if (sessionId == _activeSessionId) _flushActiveToCache();
    return List.from(_cache[sessionId] ?? []);
  }

  // ── Direct setters (disk loads, edits) ─────────────────

  /// Replace messages for a session (e.g. loaded from disk, or after edit).
  void setSessionMessages(String sessionId, List<ChatMessage> messages) {
    _cache[sessionId] = List.from(messages);
    if (sessionId == _activeSessionId) {
      state = List.from(messages);
    }
  }

  /// Remove a session from the cache entirely.
  void removeSession(String sessionId) {
    _cache.remove(sessionId);
    if (sessionId == _activeSessionId) {
      _activeSessionId = null;
      state = [];
    }
  }

  /// Clear the active session's messages.
  void clear() {
    if (_activeSessionId != null) {
      _cache[_activeSessionId!] = [];
    }
    state = [];
  }
}

// ── Processing state ─────────────────────────────────────

/// Set of session IDs that are currently processing
final processingSessionsProvider = StateProvider<Set<String>>((ref) => {});

/// Convenience: whether the currently active session is processing
final isCurrentSessionProcessingProvider = Provider<bool>((ref) {
  final activeId = ref.watch(activeSessionIdProvider);
  final processing = ref.watch(processingSessionsProvider);
  if (activeId == null) return false;
  return processing.contains(activeId);
});

// ── User preferences ─────────────────────────────────────

/// Language / Locale setting — initialised from persisted preference
final localeProvider = StateProvider<Locale>(
  (ref) => Locale(SettingsService.locale),
);

/// Theme mode — initialised from persisted preference
final themeModeProvider = StateProvider<ThemeMode>(
  (ref) =>
      SettingsService.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
);

// ── UI layout state ──────────────────────────────────────

/// Whether the chat list panel is collapsed
final chatListCollapsedProvider = StateProvider<bool>((ref) => false);

/// Whether the left sidebar is collapsed to icon rail
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

// ── Attached files ───────────────────────────────────────

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
