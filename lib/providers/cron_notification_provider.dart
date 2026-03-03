import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/providers/chat_provider.dart';
import 'package:coraldesk/src/rust/api/cron_notification_api.dart'
    as cron_notif_api;
import 'package:coraldesk/src/rust/api/sessions_api.dart' as sessions_api;

/// A single notification record shown in the UI.
class CronNotificationItem {
  final String jobId;
  final String jobName;
  final String jobType;
  final String sessionTarget;
  final String targetSessionId;
  final String status;
  final String output;
  final String prompt;
  final int durationMs;
  final DateTime finishedAt;

  const CronNotificationItem({
    required this.jobId,
    required this.jobName,
    required this.jobType,
    required this.sessionTarget,
    required this.targetSessionId,
    required this.status,
    required this.output,
    required this.prompt,
    required this.durationMs,
    required this.finishedAt,
  });

  bool get isSuccess => status == 'ok';
  bool get isAgent => jobType == 'agent';
  bool get isMainSession => sessionTarget == 'main';

  /// Whether we have a specific target session to inject into
  bool get hasTargetSession => targetSessionId.isNotEmpty;
  String get displayName => jobName.isNotEmpty ? jobName : jobId;
}

/// Holds the latest notification (for SnackBar display) and the history list.
class CronNotificationState {
  final List<CronNotificationItem> history;
  final CronNotificationItem? latest;
  final int unreadCount;

  const CronNotificationState({
    this.history = const [],
    this.latest,
    this.unreadCount = 0,
  });

  CronNotificationState copyWith({
    List<CronNotificationItem>? history,
    CronNotificationItem? latest,
    int? unreadCount,
  }) {
    return CronNotificationState(
      history: history ?? this.history,
      latest: latest ?? this.latest,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Provider that subscribes to the Rust cron notification stream.
final cronNotificationProvider =
    StateNotifierProvider<CronNotificationNotifier, CronNotificationState>(
      (ref) => CronNotificationNotifier(ref),
    );

class CronNotificationNotifier extends StateNotifier<CronNotificationState> {
  final Ref _ref;
  StreamSubscription? _sub;

  CronNotificationNotifier(this._ref) : super(const CronNotificationState()) {
    _subscribe();
  }

  void _subscribe() {
    final stream = cron_notif_api.subscribeCronNotifications();
    _sub = stream.listen(
      _onNotification,
      onError: (e) {
        debugPrint('Cron notification stream error: $e');
        // Retry after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _subscribe();
        });
      },
      onDone: () {
        debugPrint('Cron notification stream closed, resubscribing...');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _subscribe();
        });
      },
    );
  }

  void _onNotification(cron_notif_api.CronNotification n) {
    final item = CronNotificationItem(
      jobId: n.jobId,
      jobName: n.jobName,
      jobType: n.jobType,
      sessionTarget: n.sessionTarget,
      targetSessionId: n.targetSessionId,
      status: n.status,
      output: n.output,
      prompt: n.prompt,
      durationMs: n.durationMs.toInt(),
      finishedAt: DateTime.fromMillisecondsSinceEpoch(
        n.finishedAt.toInt() * 1000,
      ),
    );

    // Update state: prepend to history, set latest, bump unread
    final newHistory = [item, ...state.history].take(100).toList();
    state = state.copyWith(
      history: newHistory,
      latest: item,
      unreadCount: state.unreadCount + 1,
    );

    // If session_target == "main" and job_type == "agent" and we have a target session,
    // inject into that specific session (not the currently active one)
    if (item.isMainSession && item.isAgent && item.hasTargetSession) {
      _injectIntoSession(item);
    }
  }

  /// Inject the cron execution result as messages into the target session
  /// that was recorded when the cron job was created.
  void _injectIntoSession(CronNotificationItem item) {
    final targetSessionId = item.targetSessionId;

    final now = DateTime.now();
    final msgsNotifier = _ref.read(messagesProvider.notifier);
    final sessionsNotifier = _ref.read(sessionsProvider.notifier);

    // 1. Add a system-like "user" message showing the cron prompt
    final userMsg = ChatMessage(
      id: 'cron_${item.jobId}_${now.millisecondsSinceEpoch}_user',
      role: 'user',
      content: '⏰ [${item.displayName}] ${item.prompt}',
      timestamp: now,
    );
    msgsNotifier.addMessageToSession(targetSessionId, userMsg);
    sessionsNotifier.incrementMessageCount(targetSessionId);

    // 2. Add the assistant response
    final statusIcon = item.isSuccess ? '✅' : '❌';
    final assistantMsg = ChatMessage(
      id: 'cron_${item.jobId}_${now.millisecondsSinceEpoch}_assistant',
      role: 'assistant',
      content: '$statusIcon [${item.displayName}]\n\n${item.output}',
      timestamp: now,
    );
    msgsNotifier.addMessageToSession(targetSessionId, assistantMsg);
    sessionsNotifier.incrementMessageCount(targetSessionId);

    // 3. Persist to session store
    _persistSession(targetSessionId);
  }

  Future<void> _persistSession(String sessionId) async {
    try {
      final msgsNotifier = _ref.read(messagesProvider.notifier);
      final messages = msgsNotifier.getSessionMessages(sessionId);
      final sessions = _ref.read(sessionsProvider);
      final session = sessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => ChatSession(
          id: sessionId,
          title: 'Chat',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final sessionMessages = messages
          .map(
            (m) => sessions_api.SessionMessage(
              id: m.id,
              role: m.role,
              content: m.content,
              timestamp: m.timestamp.millisecondsSinceEpoch ~/ 1000,
            ),
          )
          .toList();

      await sessions_api.saveSession(
        sessionId: sessionId,
        title: session.title,
        messages: sessionMessages,
      );
    } catch (e) {
      debugPrint('Failed to persist cron-injected session: $e');
    }
  }

  void clearUnread() {
    state = state.copyWith(unreadCount: 0);
  }

  void clearHistory() {
    state = const CronNotificationState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
