import 'package:coraldesk/src/rust/api/sessions_api.dart' as sessions_api;

/// Encapsulates session persistence (Rust-side file store).
///
/// This service owns all CRUD operations for persisted sessions and their
/// attached files.  The UI / provider layer should use this instead of
/// calling [sessions_api] functions directly.
class SessionPersistenceService {
  const SessionPersistenceService();

  // ── Session CRUD ─────────────────────────────────────────

  Future<List<sessions_api.SessionSummary>> listSessions() =>
      sessions_api.listSessions();

  Future<sessions_api.SessionDetail?> getSessionDetail(String sessionId) =>
      sessions_api.getSessionDetail(sessionId: sessionId);

  Future<String> saveSession({
    required String sessionId,
    required String title,
    required List<sessions_api.SessionMessage> messages,
    String projectId = '',
    bool ephemeral = false,
    String agentBinding = '',
  }) => sessions_api.saveSession(
    sessionId: sessionId,
    title: title,
    messages: messages,
    projectId: projectId,
    ephemeral: ephemeral,
    agentBinding: agentBinding,
  );

  Future<void> deleteSession(String sessionId) =>
      sessions_api.deleteSession(sessionId: sessionId);

  Future<void> renameSession(String sessionId, String newTitle) =>
      sessions_api.renameSession(sessionId: sessionId, newTitle: newTitle);

  Future<void> clearAll() => sessions_api.clearAllSessions();

  // ── Stats ────────────────────────────────────────────────

  Future<sessions_api.SessionStats> getStats() =>
      sessions_api.getSessionStats();

  // ── Attached files ───────────────────────────────────────

  Future<List<String>> getSessionFiles(String sessionId) =>
      sessions_api.getSessionFiles(sessionId: sessionId);

  Future<List<String>> addSessionFiles(String sessionId, List<String> paths) =>
      sessions_api.addSessionFiles(sessionId: sessionId, filePaths: paths);

  Future<List<String>> removeSessionFile(String sessionId, String path) =>
      sessions_api.removeSessionFile(sessionId: sessionId, filePath: path);

  Future<void> clearSessionFiles(String sessionId) =>
      sessions_api.clearSessionFiles(sessionId: sessionId);
}
