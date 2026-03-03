import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;

/// Encapsulates all agent-related Rust FFI calls.
///
/// Provides a testable boundary between the UI / state layer and the Rust
/// bridge.  In tests a mock [AgentService] can be substituted via Riverpod
/// overrides.
class AgentService {
  const AgentService();

  /// Stream agent events for a chat turn (real-time tokens, tool calls, etc.).
  Stream<agent_api.AgentEvent> sendMessageStream({
    required String sessionId,
    required String message,
  }) => agent_api.sendMessageStream(sessionId: sessionId, message: message);

  /// Respond to a pending tool-approval request from the Rust side.
  Future<String> respondToToolApproval(String decision) =>
      agent_api.respondToToolApproval(decision: decision);

  /// Switch the Rust-side agent context to another session.
  Future<void> switchSession(String sessionId) =>
      agent_api.switchSession(sessionId: sessionId);

  /// Clear the Rust-side agent conversation history.
  Future<void> clearSession() => agent_api.clearSession();

  /// Runtime health check.
  Future<agent_api.RuntimeStatus> getRuntimeStatus() =>
      agent_api.getRuntimeStatus();

  /// Get workspace directory for a session.
  Future<String> getSessionWorkspaceDir(String sessionId) =>
      agent_api.getSessionWorkspaceDir(sessionId: sessionId);

  /// List files in a session's workspace.
  Future<List<agent_api.SessionFileEntry>> listSessionWorkspaceFiles(
    String sessionId,
  ) => agent_api.listSessionWorkspaceFiles(sessionId: sessionId);

  /// Open a file/directory with the system default application.
  Future<String> openInSystem(String path) =>
      agent_api.openInSystem(path: path);

  /// Copy a workspace file to a user-chosen destination.
  Future<String> copyFileTo(String src, String dst) =>
      agent_api.copyFileTo(src: src, dst: dst);

  /// List available tools.
  List<agent_api.ToolSpecDto> listTools() => agent_api.listTools();
}
