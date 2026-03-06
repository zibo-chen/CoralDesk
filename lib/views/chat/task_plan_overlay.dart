import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/models/task_plan.dart';
import 'package:coraldesk/providers/task_plan_provider.dart';
import 'package:coraldesk/theme/app_theme.dart';

/// Default offset from top-right when no user drag has occurred.
const _kDefaultTop = 56.0;
const _kDefaultRight = 16.0;

/// Floating, draggable task plan overlay for the chat window.
///
/// Shows a compact progress badge when collapsed, and a full task checklist
/// when expanded. Users can drag to reposition; position is remembered.
class TaskPlanOverlay extends ConsumerStatefulWidget {
  const TaskPlanOverlay({super.key});

  @override
  ConsumerState<TaskPlanOverlay> createState() => _TaskPlanOverlayState();
}

class _TaskPlanOverlayState extends ConsumerState<TaskPlanOverlay> {
  /// Temporary drag delta accumulated during an active drag gesture.
  Offset _dragDelta = Offset.zero;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(taskPlanProvider);
    if (plan.isEmpty) return const SizedBox.shrink();

    final isExpanded = ref.watch(taskPlanExpandedProvider);
    final savedOffset = ref.watch(taskPlanOffsetProvider);

    // Compute position: saved offset or default (top-right, below top bar).
    final baseOffset =
        savedOffset ?? const Offset(_kDefaultRight, _kDefaultTop);
    final offset = baseOffset + _dragDelta;

    return Positioned(
      top: max(4, offset.dy),
      right: max(4, offset.dx),
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (d) {
          setState(() {
            // Right-anchored: dragging right means decreasing dx.
            _dragDelta += Offset(-d.delta.dx, d.delta.dy);
          });
        },
        onPanEnd: (_) {
          // Commit the drag to the provider.
          final committed = baseOffset + _dragDelta;
          ref.read(taskPlanOffsetProvider.notifier).state = Offset(
            max(4, committed.dx),
            max(4, committed.dy),
          );
          setState(() {
            _dragDelta = Offset.zero;
            _isDragging = false;
          });
        },
        child: MouseRegion(
          cursor: _isDragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: isExpanded
                ? _ExpandedPanel(key: const ValueKey('expanded'), plan: plan)
                : _CollapsedBadge(key: const ValueKey('collapsed'), plan: plan),
          ),
        ),
      ),
    );
  }
}

// ── Collapsed badge ──────────────────────────────────────

class _CollapsedBadge extends ConsumerWidget {
  final TaskPlan plan;

  const _CollapsedBadge({super.key, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CoralDeskColors.of(context);
    final progress = plan.progress;
    final isAllDone = plan.completed == plan.total;
    final accentColor = isAllDone ? AppColors.success : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(taskPlanExpandedProvider.notifier).state = true,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: c.surfaceBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  backgroundColor: c.inputBorder.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation(accentColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${plan.completed}/${plan.total}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 16, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Expanded panel ───────────────────────────────────────

class _ExpandedPanel extends ConsumerWidget {
  final TaskPlan plan;

  const _ExpandedPanel({super.key, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CoralDeskColors.of(context);
    final isAllDone = plan.completed == plan.total;
    final accentColor = isAllDone ? AppColors.success : AppColors.primary;

    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.chatListBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle + Header
          _buildHeader(ref, c, isAllDone, accentColor),
          // Progress bar
          _buildProgressBar(c, isAllDone, accentColor),
          // Task list with separators
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 10, top: 2),
              shrinkWrap: true,
              itemCount: plan.items.length,
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: c.chatListBorder.withValues(alpha: 0.6),
                ),
              ),
              itemBuilder: (context, index) {
                return _TaskRow(
                  item: plan.items[index],
                  c: c,
                  index: index,
                  total: plan.items.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    WidgetRef ref,
    CoralDeskColors c,
    bool isAllDone,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8, top: 10, bottom: 8),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(
          bottom: BorderSide(color: c.chatListBorder.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isAllDone ? Icons.check_circle_rounded : Icons.checklist_rounded,
              size: 15,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Task Plan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          // Progress count pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${plan.completed}/${plan.total}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _HoverIconButton(
            icon: Icons.expand_less_rounded,
            size: 18,
            color: c.textSecondary,
            onTap: () {
              ref.read(taskPlanExpandedProvider.notifier).state = false;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    CoralDeskColors c,
    bool isAllDone,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: plan.progress,
              minHeight: 5,
              backgroundColor: c.inputBorder.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hover icon button ────────────────────────────────────

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _hovering ? c.inputBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        ),
      ),
    );
  }
}

// ── Individual task row ──────────────────────────────────

class _TaskRow extends StatefulWidget {
  final TaskPlanItem item;
  final CoralDeskColors c;
  final int index;
  final int total;

  const _TaskRow({
    required this.item,
    required this.c,
    required this.index,
    required this.total,
  });

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = widget.c;
    final isCompleted = item.status == TaskStatus.completed;
    final isInProgress = item.status == TaskStatus.inProgress;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: _hovering
            ? (isInProgress
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : c.inputBg.withValues(alpha: 0.5))
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Step number
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.12)
                    : isInProgress
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : c.inputBorder.withValues(alpha: 0.3),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: AppColors.success,
                    )
                  : isInProgress
                  ? SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: c.textHint,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            // Title
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isCompleted ? c.textHint : c.textPrimary,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: c.textHint.withValues(alpha: 0.5),
                  fontWeight: isInProgress ? FontWeight.w500 : FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ),
            // Status badge for in-progress
            if (isInProgress) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'RUNNING',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
