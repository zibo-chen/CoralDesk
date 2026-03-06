/// Data model for the task_plan tool — mirrors the Rust `TaskItem` struct.
///
/// Each [TaskPlanItem] has an [id], [title], and [status] that matches the
/// Rust enum variants: `pending`, `in_progress`, `completed`.
enum TaskStatus {
  pending,
  inProgress,
  completed;

  /// Parse from the Rust/JSON string representation.
  static TaskStatus fromString(String s) {
    switch (s) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  String get icon {
    switch (this) {
      case TaskStatus.pending:
        return '○';
      case TaskStatus.inProgress:
        return '◐';
      case TaskStatus.completed:
        return '●';
    }
  }
}

class TaskPlanItem {
  final int id;
  final String title;
  final TaskStatus status;

  const TaskPlanItem({
    required this.id,
    required this.title,
    required this.status,
  });

  /// Parse from JSON map (as received in tool call arguments).
  factory TaskPlanItem.fromJson(Map<String, dynamic> json) {
    return TaskPlanItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      status: TaskStatus.fromString(json['status'] as String? ?? 'pending'),
    );
  }

  TaskPlanItem copyWith({int? id, String? title, TaskStatus? status}) {
    return TaskPlanItem(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }
}

/// Immutable snapshot of a task plan for a given session.
class TaskPlan {
  final List<TaskPlanItem> items;

  const TaskPlan({this.items = const []});

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get total => items.length;
  int get completed =>
      items.where((t) => t.status == TaskStatus.completed).length;
  int get inProgress =>
      items.where((t) => t.status == TaskStatus.inProgress).length;
  int get pending => items.where((t) => t.status == TaskStatus.pending).length;

  double get progress => total == 0 ? 0 : completed / total;

  TaskPlan copyWithUpdatedItem(int id, TaskStatus status) {
    final newItems = items.map((item) {
      if (item.id == id) return item.copyWith(status: status);
      return item;
    }).toList();
    return TaskPlan(items: newItems);
  }

  TaskPlan copyWithAddedItem(TaskPlanItem item) {
    return TaskPlan(items: [...items, item]);
  }
}
