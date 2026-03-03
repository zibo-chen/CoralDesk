import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:coraldesk/constants.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';

/// Chat session list panel (middle panel in reference)
class ChatListPanel extends ConsumerWidget {
  const ChatListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final activeId = ref.watch(activeSessionIdProvider);
    final l10n = AppLocalizations.of(context)!;
    final c = CoralDeskColors.of(context);

    return Container(
      width: AppConstants.chatListWidth,
      decoration: BoxDecoration(
        color: c.chatListBg,
        border: Border(right: BorderSide(color: c.chatListBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — draggable on desktop
          DragToMoveArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                AppConstants.isMacOS ? 48 : 20,
                12,
                12,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.workWithCoralDesk,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.format_indent_decrease, size: 18),
                    color: c.textHint,
                    onPressed: () {
                      ref.read(chatListCollapsedProvider.notifier).state = true;
                    },
                    tooltip: l10n.collapseHistory,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // New Chat button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(chatControllerProvider).createSession();
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  l10n.newChat,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Session list
          Expanded(
            child: sessions.isEmpty
                ? _buildEmptyState(l10n, c)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = session.id == activeId;
                      return _ChatSessionTile(
                        session: session,
                        isActive: isActive,
                        onTap: () async {
                          if (isActive) return;
                          await ref
                              .read(chatControllerProvider)
                              .switchSession(session.id);
                        },
                        onDelete: () {
                          ref
                              .read(chatControllerProvider)
                              .deleteSession(session.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, CoralDeskColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 40, color: c.textHint),
          const SizedBox(height: 12),
          Text(
            l10n.noConversationsYet,
            style: TextStyle(color: c.textHint, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.startNewChat,
            style: TextStyle(color: c.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChatSessionTile extends StatefulWidget {
  final dynamic session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatSessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ChatSessionTile> createState() => _ChatSessionTileState();
}

class _ChatSessionTileState extends State<_ChatSessionTile> {
  CoralDeskColors get c => CoralDeskColors.of(context);
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: widget.isActive ? c.sidebarActiveBg : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: widget.isActive
                        ? c.sidebarActiveText
                        : c.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isActive
                            ? c.sidebarActiveText
                            : c.textPrimary,
                        fontWeight: widget.isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (_hovering)
                    InkWell(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(Icons.close, size: 14, color: c.textHint),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
