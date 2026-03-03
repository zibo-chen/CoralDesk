import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';

/// Whether the notification panel overlay is visible.
final notificationPanelOpenProvider = StateProvider<bool>((ref) => false);

/// A slide-in notification panel that appears on the right side.
class NotificationPanel extends ConsumerWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cronNotificationProvider);
    final l10n = AppLocalizations.of(context)!;
    final c = CoralDeskColors.of(context);

    return Material(
      elevation: 8,
      color: c.surfaceBg,
      child: SizedBox(
        width: 380,
        child: Column(
          children: [
            _buildHeader(context, ref, l10n, c, state),
            const Divider(height: 1),
            Expanded(
              child: state.history.isEmpty
                  ? _buildEmpty(l10n, c)
                  : _buildList(ref, l10n, c, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    CoralDeskColors c,
    CronNotificationState state,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined, size: 20),
          const SizedBox(width: 8),
          Text(
            l10n.notificationPanelTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          if (state.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${state.unreadCount}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (state.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: l10n.clearNotifications,
              onPressed: () {
                ref.read(cronNotificationProvider.notifier).clearHistory();
              },
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.close,
            onPressed: () {
              ref.read(notificationPanelOpenProvider.notifier).state = false;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n, CoralDeskColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: c.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noNotifications,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.noNotificationsHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    WidgetRef ref,
    AppLocalizations l10n,
    CoralDeskColors c,
    CronNotificationState state,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.history.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: c.chatListBorder,
      ),
      itemBuilder: (context, index) {
        return _NotificationTile(
          item: state.history[index],
          l10n: l10n,
          c: c,
          onTapViewCron: () {
            ref.read(currentNavProvider.notifier).state = NavSection.cronJobs;
            ref.read(notificationPanelOpenProvider.notifier).state = false;
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final CronNotificationItem item;
  final AppLocalizations l10n;
  final CoralDeskColors c;
  final VoidCallback onTapViewCron;

  const _NotificationTile({
    required this.item,
    required this.l10n,
    required this.c,
    required this.onTapViewCron,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = item.isSuccess;
    final isAgent = item.isAgent;
    final statusColor = isSuccess ? AppColors.success : AppColors.error;
    final typeColor = isAgent ? AppColors.primary : AppColors.warning;

    return InkWell(
      onTap: onTapViewCron,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status icon
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildChip(isAgent ? 'Agent' : 'Shell', typeColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Output preview
                  if (item.output.isNotEmpty)
                    _OutputPreview(output: item.output, c: c),
                  const SizedBox(height: 6),
                  // Meta row
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: c.textHint),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(item.finishedAt),
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.timer_outlined, size: 12, color: c.textHint),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(item.durationMs),
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                      if (item.isMainSession &&
                          item.isAgent &&
                          item.hasTargetSession) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.cronNotifInjected,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
    return '${(ms / 60000).toStringAsFixed(1)}min';
  }
}

/// Expandable output preview with copy button
class _OutputPreview extends StatefulWidget {
  final String output;
  final CoralDeskColors c;
  const _OutputPreview({required this.output, required this.c});

  @override
  State<_OutputPreview> createState() => _OutputPreviewState();
}

class _OutputPreviewState extends State<_OutputPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final truncated = widget.output.length > 120;
    final displayText = (!_expanded && truncated)
        ? '${widget.output.substring(0, 120)}...'
        : widget.output;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.c.chatListBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.c.chatListBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayText,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: widget.c.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (truncated)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded
                            ? AppLocalizations.of(context)!.collapse
                            : AppLocalizations.of(context)!.expandOutput,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.output));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.copiedToClipboard,
                          ),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          width: 200,
                        ),
                      );
                    },
                    child: Icon(Icons.copy, size: 14, color: widget.c.textHint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
