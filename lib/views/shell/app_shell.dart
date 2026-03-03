import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/constants.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/sidebar/sidebar_nav.dart';
import 'package:coraldesk/views/chat/chat_list_panel.dart';
import 'package:coraldesk/views/chat/chat_view.dart';
import 'package:coraldesk/views/settings/models_page.dart';
import 'package:coraldesk/views/settings/workspace_page.dart';
import 'package:coraldesk/views/settings/configuration_page.dart';
import 'package:coraldesk/views/settings/channels_page.dart';
import 'package:coraldesk/views/settings/skills_page.dart';
import 'package:coraldesk/views/settings/mcp_page.dart';
import 'package:coraldesk/views/settings/agents_page.dart';
import 'package:coraldesk/views/settings/proxy_page.dart';
import 'package:coraldesk/views/settings/sessions_page.dart';
import 'package:coraldesk/views/settings/cron_jobs_page.dart';
import 'package:coraldesk/views/settings/knowledge_page.dart';
import 'package:coraldesk/views/notification/notification_panel.dart';
import 'package:window_manager/window_manager.dart';

/// Root layout shell: Sidebar | Chat List (when in chat) | Main Content
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
  bool _isMaximized = false;

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

    if (_isDesktop) {
      windowManager.addListener(this);
      Future.microtask(() async {
        _isMaximized = await windowManager.isMaximized();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (!mounted) return;
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted) return;
    setState(() {
      _isMaximized = false;
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

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Left sidebar navigation
              const SidebarNav(),

              // Chat list panel (only visible in Chat section & not collapsed)
              if (showChatList) const ChatListPanel(),

              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Integrated drag header — blends with content background
                    if (_isDesktop &&
                        l10n != null &&
                        currentNav != NavSection.chat)
                      _ContentDragHeader(
                        title: _titleForSection(currentNav, l10n),
                      ),
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
              ),
            ],
          ),
          // Window controls at absolute top-right (Windows & Linux only)
          if (_isDesktop && !_isMacOS)
            Positioned(
              top: 0,
              right: 0,
              child: _WindowControls(isMaximized: _isMaximized),
            ),
        ],
      ),
    );
  }

  String _titleForSection(NavSection section, AppLocalizations l10n) {
    return switch (section) {
      NavSection.chat => l10n.navChat,
      NavSection.models => l10n.navModels,
      NavSection.channels => l10n.navChannels,
      NavSection.workspace => l10n.navWorkspace,
      NavSection.configuration => l10n.navConfiguration,
      NavSection.sessions => l10n.navSessions,
      NavSection.cronJobs => l10n.navCronJobs,
      NavSection.knowledge => l10n.navKnowledge,
      NavSection.skills => l10n.navSkills,
      NavSection.mcp => l10n.navMcp,
      NavSection.agents => l10n.navAgents,
      NavSection.proxy => l10n.navProxy,
    };
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

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

/// Lightweight drag header for the content area.
/// On macOS includes extra top inset for traffic-light buttons.
class _ContentDragHeader extends StatelessWidget {
  const _ContentDragHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final isMacOS = AppConstants.isMacOS;

    return DragToMoveArea(
      child: Container(
        height: isMacOS ? AppConstants.macOSTopInset + 20 : 38,
        color: c.mainBg,
        padding: EdgeInsets.only(
          left: 20,
          right: isMacOS ? 20 : 150,
          top: isMacOS ? AppConstants.macOSTopInset : 0,
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: c.textHint,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Window controls for Windows & Linux (minimize, maximize/restore, close).
class _WindowControls extends StatelessWidget {
  const _WindowControls({required this.isMaximized});

  final bool isMaximized;

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    return Container(
      height: 38,
      color: c.mainBg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WindowControlButton(
            icon: Icons.remove,
            color: c.textSecondary,
            hoverColor: c.inputBg,
            onTap: () => windowManager.minimize(),
          ),
          _WindowControlButton(
            icon: isMaximized ? Icons.filter_none : Icons.crop_square,
            color: c.textSecondary,
            hoverColor: c.inputBg,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowControlButton(
            icon: Icons.close,
            color: c.textSecondary,
            hoverColor: AppColors.error.withValues(alpha: 0.15),
            hoverIconColor: Colors.white,
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
    this.hoverIconColor,
  });

  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;
  final Color? hoverIconColor;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: double.infinity,
          color: _hovered ? widget.hoverColor : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 16,
            color: _hovered && widget.hoverIconColor != null
                ? widget.hoverIconColor
                : widget.color,
          ),
        ),
      ),
    );
  }
}
