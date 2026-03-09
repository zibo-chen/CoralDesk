/// Project type classification
enum ProjectType {
  general,
  codeProject,
  dataProcessing,
  writing,
  automation;

  String get label {
    switch (this) {
      case ProjectType.general:
        return 'General';
      case ProjectType.codeProject:
        return 'Code Project';
      case ProjectType.dataProcessing:
        return 'Data Processing';
      case ProjectType.writing:
        return 'Writing';
      case ProjectType.automation:
        return 'Automation';
    }
  }

  String get icon {
    switch (this) {
      case ProjectType.general:
        return '📁';
      case ProjectType.codeProject:
        return '💻';
      case ProjectType.dataProcessing:
        return '📊';
      case ProjectType.writing:
        return '✍️';
      case ProjectType.automation:
        return '⚙️';
    }
  }

  static ProjectType fromString(String s) {
    switch (s) {
      case 'code_project':
        return ProjectType.codeProject;
      case 'data_processing':
        return ProjectType.dataProcessing;
      case 'writing':
        return ProjectType.writing;
      case 'automation':
        return ProjectType.automation;
      default:
        return ProjectType.general;
    }
  }

  String toApiString() {
    switch (this) {
      case ProjectType.general:
        return 'general';
      case ProjectType.codeProject:
        return 'code_project';
      case ProjectType.dataProcessing:
        return 'data_processing';
      case ProjectType.writing:
        return 'writing';
      case ProjectType.automation:
        return 'automation';
    }
  }
}

/// Project status
enum ProjectStatus {
  active,
  paused,
  archived,
  completed;

  String get label {
    switch (this) {
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.paused:
        return 'Paused';
      case ProjectStatus.archived:
        return 'Archived';
      case ProjectStatus.completed:
        return 'Completed';
    }
  }

  String get icon {
    switch (this) {
      case ProjectStatus.active:
        return '🟢';
      case ProjectStatus.paused:
        return '⏸️';
      case ProjectStatus.archived:
        return '📦';
      case ProjectStatus.completed:
        return '✅';
    }
  }

  static ProjectStatus fromString(String s) {
    switch (s) {
      case 'paused':
        return ProjectStatus.paused;
      case 'archived':
        return ProjectStatus.archived;
      case 'completed':
        return ProjectStatus.completed;
      default:
        return ProjectStatus.active;
    }
  }
}

/// Represents a project — a top-level container that groups related sessions.
class Project {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String colorTag;
  final ProjectType projectType;
  final ProjectStatus status;
  final String projectDir;
  final String pinnedContext;

  /// Bound role (agent workspace) IDs — a project can have multiple roles
  final List<String> roleIds;

  /// Default role ID for new sessions within this project
  final String defaultRoleId;
  final List<String> sessionIds;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = '📁',
    this.colorTag = '#5B6ABF',
    this.projectType = ProjectType.general,
    this.status = ProjectStatus.active,
    this.projectDir = '',
    this.pinnedContext = '',
    this.roleIds = const [],
    this.defaultRoleId = '',
    this.sessionIds = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get sessionCount => sessionIds.length;
  int get roleCount => roleIds.length;
  bool get hasProjectDir => projectDir.isNotEmpty;
  bool get hasRoles => roleIds.isNotEmpty;

  Project copyWith({
    String? name,
    String? description,
    String? icon,
    String? colorTag,
    ProjectType? projectType,
    ProjectStatus? status,
    String? projectDir,
    String? pinnedContext,
    List<String>? roleIds,
    String? defaultRoleId,
    List<String>? sessionIds,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      colorTag: colorTag ?? this.colorTag,
      projectType: projectType ?? this.projectType,
      status: status ?? this.status,
      projectDir: projectDir ?? this.projectDir,
      pinnedContext: pinnedContext ?? this.pinnedContext,
      roleIds: roleIds ?? this.roleIds,
      defaultRoleId: defaultRoleId ?? this.defaultRoleId,
      sessionIds: sessionIds ?? this.sessionIds,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
