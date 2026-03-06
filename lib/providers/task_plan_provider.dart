import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/models/task_plan.dart';

// ── Provider ─────────────────────────────────────────────

/// Per-session task plan state.
///
/// The notifier intercepts `task_plan` tool calls from the agent stream and
/// keeps an in-memory [TaskPlan] that the floating overlay reads.
final taskPlanProvider = StateNotifierProvider<TaskPlanNotifier, TaskPlan>((
  ref,
) {
  return TaskPlanNotifier();
});

/// Whether the task plan overlay is expanded or collapsed.
final taskPlanExpandedProvider = StateProvider<bool>((ref) => true);

/// Draggable offset of the task plan overlay (relative to top-right corner).
/// Null means use the default position.
final taskPlanOffsetProvider = StateProvider<Offset?>((ref) => null);

class TaskPlanNotifier extends StateNotifier<TaskPlan> {
  TaskPlanNotifier() : super(const TaskPlan());

  /// Per-session cache so switching sessions restores the plan.
  final Map<String, TaskPlan> _cache = {};
  String? _activeSessionId;

  // ── Session lifecycle ──────────────────────────────────

  void switchToSession(String? sessionId) {
    // Save current
    if (_activeSessionId != null) {
      _cache[_activeSessionId!] = state;
    }
    _activeSessionId = sessionId;
    if (sessionId != null) {
      state = _cache[sessionId] ?? const TaskPlan();
    } else {
      state = const TaskPlan();
    }
  }

  void removeSession(String sessionId) {
    _cache.remove(sessionId);
    if (_activeSessionId == sessionId) {
      state = const TaskPlan();
      _activeSessionId = null;
    }
  }

  // ── Tool-call processing ───────────────────────────────

  /// Called when a `task_plan` tool call completes.
  ///
  /// [toolArgs] is the raw JSON argument string from the ToolCallStart event.
  /// [toolResult] is the plain-text output from ToolCallEnd.
  void processToolCall(String toolArgs, String? toolResult) {
    final normalizedArgs = toolArgs.trim();
    final normalizedResult = toolResult?.trim() ?? '';

    // Prefer the authoritative tool result snapshot whenever available.
    // The Rust tool now returns the full current task list after every
    // mutation, so this path is much more reliable than pairing start/end args.
    if (_applyStateFromResult(normalizedResult)) {
      if (_activeSessionId != null) {
        _cache[_activeSessionId!] = state;
      }
      return;
    }

    try {
      debugPrint('TaskPlanNotifier.processToolCall: args=$toolArgs');
      final args = jsonDecode(normalizedArgs) as Map<String, dynamic>;
      final action = args['action'] as String? ?? '';

      switch (action) {
        case 'create':
          _handleCreate(args);
          break;
        case 'add':
          _handleAdd(args);
          break;
        case 'update':
          _handleUpdate(args);
          break;
        case 'delete':
          _clearPlan();
          break;
        case 'list':
          // list is read-only — no state change needed.
          // But if we had no local state yet and the result has tasks,
          // we can try to parse it.
          if (state.isEmpty && normalizedResult.isNotEmpty) {
            _tryParseListResult(normalizedResult);
          }
          break;
      }

      // Sync to cache
      if (_activeSessionId != null) {
        _cache[_activeSessionId!] = state;
      }
    } catch (e) {
      debugPrint('TaskPlanNotifier.processToolCall error: $e');

      // Fallback 1: some runtimes may pass a plain action string instead of
      // full JSON arguments (e.g. "delete", "list").
      switch (normalizedArgs) {
        case 'delete':
          _clearPlan();
          break;
        case 'list':
          if (normalizedResult.isNotEmpty) {
            _tryParseListResult(normalizedResult);
          }
          break;
      }

      // Fallback 2: infer clearing from result text even if args were lost.
      if (_looksLikeClearedResult(normalizedResult)) {
        _clearPlan();
      }

      // Fallback 3: reconstruct from list output text.
      if (normalizedResult.contains('[') && normalizedResult.contains(']')) {
        _tryParseListResult(normalizedResult);
      }

      if (_activeSessionId != null) {
        _cache[_activeSessionId!] = state;
      }
    }
  }

  void _clearPlan() {
    state = TaskPlan(items: const []);
  }

  bool _looksLikeClearedResult(String result) {
    if (result.isEmpty) return false;
    return result == 'No tasks.' ||
        result.contains('Task list cleared') ||
        result.contains('task list cleared') ||
        result.contains('No tasks');
  }

  bool _applyStateFromResult(String result) {
    if (result.isEmpty) return false;

    if (_looksLikeClearedResult(result)) {
      _clearPlan();
      return true;
    }

    if (!result.contains('Tasks (')) {
      return false;
    }

    _tryParseListResult(result);
    return true;
  }

  void _handleCreate(Map<String, dynamic> args) {
    final tasksJson = args['tasks'] as List<dynamic>? ?? [];
    final items = <TaskPlanItem>[];
    for (int i = 0; i < tasksJson.length; i++) {
      final entry = tasksJson[i] as Map<String, dynamic>;
      items.add(
        TaskPlanItem(
          id: i + 1,
          title: entry['title'] as String? ?? '',
          status: TaskStatus.fromString(
            entry['status'] as String? ?? 'pending',
          ),
        ),
      );
    }
    state = TaskPlan(items: items);
  }

  void _handleAdd(Map<String, dynamic> args) {
    final title = args['title'] as String? ?? '';
    if (title.isEmpty) return;
    final nextId = state.items.isEmpty ? 1 : state.items.last.id + 1;
    state = state.copyWithAddedItem(
      TaskPlanItem(id: nextId, title: title, status: TaskStatus.pending),
    );
  }

  void _handleUpdate(Map<String, dynamic> args) {
    final idVal = args['id'];
    final id = idVal is int ? idVal : (idVal is num ? idVal.toInt() : 0);
    final statusStr = args['status'] as String? ?? '';
    if (id == 0 || statusStr.isEmpty) return;
    state = state.copyWithUpdatedItem(id, TaskStatus.fromString(statusStr));
  }

  /// Attempt to parse the text output of a `list` action to reconstruct
  /// the task plan — only used when we have no local state yet (e.g.
  /// reconnecting to an existing session).
  void _tryParseListResult(String result) {
    // Output format: "Tasks (2/5 completed):\n- [1] [pending] Fix bug\n..."
    final lines = result.split('\n');
    final items = <TaskPlanItem>[];
    final pattern = RegExp(r'^\-\s*\[(\d+)\]\s*\[(\w+)\]\s*(.+)$');
    for (final line in lines) {
      final m = pattern.firstMatch(line.trim());
      if (m != null) {
        items.add(
          TaskPlanItem(
            id: int.parse(m.group(1)!),
            title: m.group(3)!,
            status: TaskStatus.fromString(m.group(2)!),
          ),
        );
      }
    }
    if (items.isNotEmpty) {
      state = TaskPlan(items: items);
    }
  }
}
