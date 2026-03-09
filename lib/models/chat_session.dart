/// Represents a chat session
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final List<String> attachedFiles;

  /// Whether this session uses multi-agent role mode.
  final bool isMultiAgent;

  /// Active role names in this session (e.g. ['architect', 'coder', 'critic']).
  final List<String> activeRoles;

  /// Project this session belongs to (null = free/independent chat).
  final String? projectId;

  /// Whether this is an ephemeral (temporary) session that should NOT be
  /// persisted to disk. Ephemeral sessions are destroyed when closed.
  final bool ephemeral;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
    this.attachedFiles = const [],
    this.isMultiAgent = false,
    this.activeRoles = const [],
    this.projectId,
    this.ephemeral = false,
  });

  /// Whether this session belongs to a project.
  bool get isProjectSession => projectId != null;

  /// Whether this is a free/independent chat (no project, not ephemeral).
  bool get isFreeChat => projectId == null && !ephemeral;

  /// Use [clearProjectId] = true to explicitly set projectId to null.
  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    int? messageCount,
    List<String>? attachedFiles,
    bool? isMultiAgent,
    List<String>? activeRoles,
    String? projectId,
    bool clearProjectId = false,
    bool? ephemeral,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
      attachedFiles: attachedFiles ?? this.attachedFiles,
      isMultiAgent: isMultiAgent ?? this.isMultiAgent,
      activeRoles: activeRoles ?? this.activeRoles,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      ephemeral: ephemeral ?? this.ephemeral,
    );
  }
}
