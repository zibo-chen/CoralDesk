import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/providers/chat_provider.dart';
import 'package:coraldesk/services/settings_service.dart';
import 'package:coraldesk/src/rust/api/project_api.dart' as project_api;

// ── Projects ─────────────────────────────────────────────

/// All projects
final projectsProvider = StateNotifierProvider<ProjectsNotifier, List<Project>>(
  (ref) {
    return ProjectsNotifier();
  },
);

class ProjectsNotifier extends StateNotifier<List<Project>> {
  ProjectsNotifier() : super([]);

  /// Load projects from Rust store on app startup
  Future<void> load() async {
    try {
      await project_api.initProjectStore();
      final summaries = await project_api.listProjects();
      if (summaries.isNotEmpty) {
        final loaded = summaries
            .map(
              (s) => Project(
                id: s.id,
                name: s.name,
                description: s.description,
                icon: s.icon.isNotEmpty ? s.icon : '📁',
                colorTag: s.colorTag.isNotEmpty ? s.colorTag : '#5B6ABF',
                projectType: ProjectType.fromString(s.projectType),
                status: ProjectStatus.fromString(s.status),
                roleIds: s.roleIds,
                defaultRoleId: s.defaultRoleId,
                sessionIds: const [], // Full sessionIds loaded on detail
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  (s.createdAt * 1000).toInt(),
                ),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  (s.updatedAt * 1000).toInt(),
                ),
              ),
            )
            .toList();
        state = loaded;
      }
    } catch (e) {
      debugPrint('Failed to load projects: $e');
    }
  }

  /// Refresh the full project list from Rust
  Future<void> refresh() async {
    try {
      final summaries = await project_api.listProjects();
      final loaded = summaries
          .map(
            (s) => Project(
              id: s.id,
              name: s.name,
              description: s.description,
              icon: s.icon.isNotEmpty ? s.icon : '📁',
              colorTag: s.colorTag.isNotEmpty ? s.colorTag : '#5B6ABF',
              projectType: ProjectType.fromString(s.projectType),
              status: ProjectStatus.fromString(s.status),
              roleIds: s.roleIds,
              defaultRoleId: s.defaultRoleId,
              sessionIds: const [], // Full sessionIds loaded on detail
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                (s.createdAt * 1000).toInt(),
              ),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                (s.updatedAt * 1000).toInt(),
              ),
            ),
          )
          .toList();
      state = loaded;
    } catch (e) {
      debugPrint('Failed to refresh projects: $e');
    }
  }

  /// Create a new project. Returns the project ID.
  Future<String?> createProject({
    required String name,
    String description = '',
    String icon = '📁',
    String colorTag = '#5B6ABF',
    ProjectType projectType = ProjectType.general,
    String projectDir = '',
    List<String> roleIds = const [],
    String defaultRoleId = '',
    List<String> tags = const [],
  }) async {
    try {
      final result = await project_api.upsertProject(
        project: project_api.ProjectDto(
          id: '',
          name: name,
          description: description,
          icon: icon,
          colorTag: colorTag,
          projectType: _toApiType(projectType),
          status: project_api.ProjectStatus.active,
          projectDir: projectDir,
          pinnedContext: '',
          roleIds: roleIds,
          defaultRoleId: defaultRoleId,
          sessionIds: [],
          tags: tags,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      if (result.startsWith('error')) {
        debugPrint('Failed to create project: $result');
        return null;
      }
      SettingsService.hasSeenProjectIntro = true;
      await refresh();
      return result; // returns the new project ID
    } catch (e) {
      debugPrint('Failed to create project: $e');
      return null;
    }
  }

  /// Update an existing project
  Future<bool> updateProject(Project project) async {
    try {
      final result = await project_api.upsertProject(
        project: project_api.ProjectDto(
          id: project.id,
          name: project.name,
          description: project.description,
          icon: project.icon,
          colorTag: project.colorTag,
          projectType: _toApiType(project.projectType),
          status: _toApiStatus(project.status),
          projectDir: project.projectDir,
          pinnedContext: project.pinnedContext,
          roleIds: project.roleIds,
          defaultRoleId: project.defaultRoleId,
          sessionIds: project.sessionIds,
          tags: project.tags,
          createdAt: project.createdAt.millisecondsSinceEpoch ~/ 1000,
          updatedAt: 0,
        ),
      );
      if (result.startsWith('error')) return false;
      await refresh();
      return true;
    } catch (e) {
      debugPrint('Failed to update project: $e');
      return false;
    }
  }

  /// Delete a project
  Future<void> deleteProject(String projectId) async {
    try {
      await project_api.deleteProject(projectId: projectId);
      state = state.where((p) => p.id != projectId).toList();
    } catch (e) {
      debugPrint('Failed to delete project: $e');
    }
  }

  /// Add a session to a project
  Future<void> addSession(String projectId, String sessionId) async {
    try {
      await project_api.addSessionToProject(
        projectId: projectId,
        sessionId: sessionId,
      );
      await refresh();
    } catch (e) {
      debugPrint('Failed to add session to project: $e');
    }
  }

  /// Remove a session from a project
  Future<void> removeSession(String projectId, String sessionId) async {
    try {
      await project_api.removeSessionFromProject(
        projectId: projectId,
        sessionId: sessionId,
      );
      await refresh();
    } catch (e) {
      debugPrint('Failed to remove session from project: $e');
    }
  }

  /// Add a role (agent workspace) to a project
  Future<void> addRole(String projectId, String roleId) async {
    try {
      await project_api.addRoleToProject(projectId: projectId, roleId: roleId);
      await refresh();
    } catch (e) {
      debugPrint('Failed to add role to project: $e');
    }
  }

  /// Remove a role from a project
  Future<void> removeRole(String projectId, String roleId) async {
    try {
      await project_api.removeRoleFromProject(
        projectId: projectId,
        roleId: roleId,
      );
      await refresh();
    } catch (e) {
      debugPrint('Failed to remove role from project: $e');
    }
  }

  /// Set the default role for a project
  Future<void> setDefaultRole(String projectId, String roleId) async {
    try {
      await project_api.setProjectDefaultRole(
        projectId: projectId,
        roleId: roleId,
      );
      await refresh();
    } catch (e) {
      debugPrint('Failed to set default role: $e');
    }
  }

  /// Update pinned context for a project
  Future<void> updatePinnedContext(String projectId, String context) async {
    try {
      await project_api.updateProjectContext(
        projectId: projectId,
        pinnedContext: context,
      );
      // Update local state optimistically
      state = state.map((p) {
        if (p.id == projectId) {
          return p.copyWith(pinnedContext: context, updatedAt: DateTime.now());
        }
        return p;
      }).toList();
    } catch (e) {
      debugPrint('Failed to update project context: $e');
    }
  }

  /// Update project status (active, paused, archived, completed)
  Future<bool> updateStatus(String projectId, ProjectStatus status) async {
    try {
      final result = await project_api.updateProjectStatus(
        projectId: projectId,
        status: _toApiStatus(status),
      );
      if (result.startsWith('error')) return false;
      // Update local state optimistically
      state = state.map((p) {
        if (p.id == projectId) {
          return p.copyWith(status: status, updatedAt: DateTime.now());
        }
        return p;
      }).toList();
      return true;
    } catch (e) {
      debugPrint('Failed to update project status: $e');
      return false;
    }
  }

  project_api.ProjectType _toApiType(ProjectType t) {
    switch (t) {
      case ProjectType.general:
        return project_api.ProjectType.general;
      case ProjectType.codeProject:
        return project_api.ProjectType.codeProject;
      case ProjectType.dataProcessing:
        return project_api.ProjectType.dataProcessing;
      case ProjectType.writing:
        return project_api.ProjectType.writing;
      case ProjectType.automation:
        return project_api.ProjectType.automation;
    }
  }

  project_api.ProjectStatus _toApiStatus(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.active:
        return project_api.ProjectStatus.active;
      case ProjectStatus.paused:
        return project_api.ProjectStatus.paused;
      case ProjectStatus.archived:
        return project_api.ProjectStatus.archived;
      case ProjectStatus.completed:
        return project_api.ProjectStatus.completed;
    }
  }
}

// ── Active Project ───────────────────────────────────────

/// The currently active project ID (null = no project / free chat)
final activeProjectIdProvider = StateProvider<String?>((ref) => null);

/// Get the full Project object for the active project
final activeProjectProvider = Provider<Project?>((ref) {
  final projectId = ref.watch(activeProjectIdProvider);
  if (projectId == null) return null;
  final projects = ref.watch(projectsProvider);
  return projects.where((p) => p.id == projectId).firstOrNull;
});

/// Get the full Project detail (with session_ids) from Rust
final projectDetailProvider = FutureProvider.family<Project?, String>((
  ref,
  projectId,
) async {
  try {
    final dto = await project_api.getProject(projectId: projectId);
    if (dto == null) return null;
    return Project(
      id: dto.id,
      name: dto.name,
      description: dto.description,
      icon: dto.icon.isNotEmpty ? dto.icon : '📁',
      colorTag: dto.colorTag.isNotEmpty ? dto.colorTag : '#5B6ABF',
      projectType: ProjectType.fromString(
        _projectTypeToString(dto.projectType),
      ),
      status: ProjectStatus.fromString(_statusToString(dto.status)),
      projectDir: dto.projectDir,
      pinnedContext: dto.pinnedContext,
      roleIds: dto.roleIds,
      defaultRoleId: dto.defaultRoleId,
      sessionIds: dto.sessionIds,
      tags: dto.tags,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (dto.createdAt * 1000).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (dto.updatedAt * 1000).toInt(),
      ),
    );
  } catch (e) {
    debugPrint('Failed to load project detail: $e');
    return null;
  }
});

/// Derive the project for the current active session.
/// Returns null if the session is a free chat / ephemeral without project.
final activeSessionProjectProvider = Provider<Project?>((ref) {
  final activeId = ref.watch(activeSessionIdProvider);
  if (activeId == null) return null;
  final sessions = ref.watch(sessionsProvider);
  final session = sessions.where((s) => s.id == activeId).firstOrNull;
  if (session == null || session.projectId == null) return null;
  final projects = ref.watch(projectsProvider);
  return projects.where((p) => p.id == session.projectId).firstOrNull;
});

String _projectTypeToString(project_api.ProjectType t) => switch (t) {
  project_api.ProjectType.general => 'general',
  project_api.ProjectType.codeProject => 'code_project',
  project_api.ProjectType.dataProcessing => 'data_processing',
  project_api.ProjectType.writing => 'writing',
  project_api.ProjectType.automation => 'automation',
};

String _statusToString(project_api.ProjectStatus s) => switch (s) {
  project_api.ProjectStatus.active => 'active',
  project_api.ProjectStatus.paused => 'paused',
  project_api.ProjectStatus.archived => 'archived',
  project_api.ProjectStatus.completed => 'completed',
};
