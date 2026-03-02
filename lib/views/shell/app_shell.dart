import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deskclaw/l10n/app_localizations.dart';
import 'package:deskclaw/providers/providers.dart';
import 'package:deskclaw/theme/app_theme.dart';
import 'package:deskclaw/views/sidebar/sidebar_nav.dart';
import 'package:deskclaw/views/chat/chat_list_panel.dart';
import 'package:deskclaw/views/chat/chat_view.dart';
import 'package:deskclaw/views/settings/models_page.dart';
import 'package:deskclaw/views/settings/workspace_page.dart';
import 'package:deskclaw/views/settings/configuration_page.dart';
import 'package:deskclaw/views/settings/channels_page.dart';
import 'package:deskclaw/views/settings/skills_page.dart';
import 'package:deskclaw/views/settings/mcp_page.dart';
import 'package:deskclaw/views/settings/agents_page.dart';
import 'package:deskclaw/views/settings/proxy_page.dart';
import 'package:deskclaw/views/settings/sessions_page.dart';
import 'package:deskclaw/views/settings/cron_jobs_page.dart';
import 'package:deskclaw/views/settings/knowledge_page.dart';
import 'package:deskclaw/views/notification/notification_panel.dart';

/// Root layout shell: Sidebar | Chat List (when in chat) | Main Content
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Load persisted sessions from Rust store on startup
    Future.microtask(() {
      ref.read(sessionsProvider.notifier).loadPersistedSessions();
      // Eagerly initialise the cron notification subscription so events
      // are received even before the user navigates to any cron page.
      ref.read(cronNotificationProvider);
    });
  }

  /// Show a SnackBar when a cron notification arrives
  void _showCronNotification(
    CronNotificationItem? prev,
    CronNotificationItem? next,
  ) {
    if (next == null || next == prev) return;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final title = next.isSuccess
        ? l10n.cronNotifSuccess(next.displayName)
        : l10n.cronNotifFailed(next.displayName);

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      width: 420,
      duration: const Duration(seconds: 4),
      backgroundColor: next.isSuccess ? AppColors.success : AppColors.error,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            l10n.cronNotifDuration(next.durationMs.toString()),
            style: const TextStyle(fontSize: 12),
          ),
          if (next.isMainSession && next.isAgent && next.hasTargetSession)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.cronNotifInjected,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      action: SnackBarAction(
        label: l10n.viewOutput,
        textColor: Colors.white,
        onPressed: () {
          ref.read(currentNavProvider.notifier).state = NavSection.cronJobs;
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final currentNav = ref.watch(currentNavProvider);
    final isChatSection = currentNav == NavSection.chat;
    final isCollapsed = ref.watch(chatListCollapsedProvider);
    final showChatList = isChatSection && !isCollapsed;

    // Listen for new cron notifications and show SnackBar
    ref.listen<CronNotificationState>(cronNotificationProvider, (prev, next) {
      _showCronNotification(prev?.latest, next.latest);
    });

    return Scaffold(
      body: Row(
        children: [
          // Left sidebar navigation
          const SidebarNav(),

          // Chat list panel (only visible in Chat section & not collapsed)
          if (showChatList) const ChatListPanel(),

          // Main content area + notification panel overlay
          Expanded(
            child: Stack(
              children: [
                _buildMainContent(context, currentNav),
                // Notification panel slide-in from right
                _buildNotificationOverlay(ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildMainContent(BuildContext context, NavSection section) {
    return switch (section) {
      NavSection.chat => const ChatView(),
      NavSection.models => const ModelsPage(),
      NavSection.channels => const ChannelsPage(),
      NavSection.workspace => const WorkspacePage(),
      NavSection.configuration => const ConfigurationPage(),
      NavSection.sessions => const SessionsPage(),
      NavSection.cronJobs => const CronJobsPage(),
      NavSection.knowledge => const KnowledgePage(),
      NavSection.skills => const SkillsPage(),
      NavSection.mcp => const McpPage(),
      NavSection.agents => const AgentsPage(),
      NavSection.proxy => const ProxyPage(),
    };
  }

  static Widget _buildNotificationOverlay(WidgetRef ref) {
    final isOpen = ref.watch(notificationPanelOpenProvider);
    return Stack(
      children: [
        // Full-area scrim — tapping anywhere outside the panel closes it
        if (isOpen)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(notificationPanelOpenProvider.notifier).state = false;
            },
            child: const SizedBox.expand(),
          ),
        // Notification panel slides in from right
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          right: isOpen ? 0 : -380,
          child: const NotificationPanel(),
        ),
      ],
    );
  }
}
