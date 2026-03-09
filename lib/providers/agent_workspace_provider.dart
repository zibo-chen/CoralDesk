import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/providers/chat_provider.dart';
import 'package:coraldesk/src/rust/api/agent_workspace_api.dart'
    as workspace_api;

// ── Agent Workspaces ─────────────────────────────────────

/// All available agent workspaces
final agentWorkspacesProvider =
    StateNotifierProvider<
      AgentWorkspacesNotifier,
      List<workspace_api.AgentWorkspaceSummary>
    >((ref) => AgentWorkspacesNotifier());

class AgentWorkspacesNotifier
    extends StateNotifier<List<workspace_api.AgentWorkspaceSummary>> {
  AgentWorkspacesNotifier() : super([]);

  Future<void> load() async {
    try {
      await workspace_api.initAgentWorkspaceStore();
      final workspaces = await workspace_api.listAgentWorkspaces();
      state = workspaces;
    } catch (e) {
      debugPrint('Failed to load agent workspaces: $e');
    }
  }

  Future<void> refresh() async {
    try {
      final workspaces = await workspace_api.listAgentWorkspaces();
      state = workspaces;
    } catch (e) {
      debugPrint('Failed to refresh agent workspaces: $e');
    }
  }
}

// ── Session → Agent binding ──────────────────────────────

/// Tracks which agent workspace is bound to which session.
/// Key: sessionId, Value: workspaceId
final sessionAgentBindingProvider =
    StateNotifierProvider<SessionAgentBindingNotifier, Map<String, String>>(
      (ref) => SessionAgentBindingNotifier(),
    );

class SessionAgentBindingNotifier extends StateNotifier<Map<String, String>> {
  SessionAgentBindingNotifier() : super({});

  /// Initialize bindings from persisted session data (call on app startup).
  void initFromPersisted(Map<String, String> bindings) {
    state = {...state, ...bindings};
  }

  Future<void> bind(String sessionId, String workspaceId) async {
    await workspace_api.bindSessionToAgent(
      sessionId: sessionId,
      workspaceId: workspaceId,
    );
    state = {...state, sessionId: workspaceId};
  }

  Future<void> unbind(String sessionId) async {
    await workspace_api.unbindSessionAgent(sessionId: sessionId);
    state = Map.from(state)..remove(sessionId);
  }

  /// Remove a binding from Dart state only (Rust already cleared it).
  /// Used when Rust-side unbind was done externally (e.g. remove_role_from_project).
  void removeLocal(String sessionId) {
    state = Map.from(state)..remove(sessionId);
  }

  String? getBinding(String sessionId) => state[sessionId];
}

/// Convenience: get agent workspace ID for the active session
final activeSessionAgentProvider = Provider<String?>((ref) {
  final activeId = ref.watch(activeSessionIdProvider);
  if (activeId == null) return null;
  final bindings = ref.watch(sessionAgentBindingProvider);
  return bindings[activeId];
});
