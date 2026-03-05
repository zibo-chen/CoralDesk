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
import 'package:coraldesk/services/tray_service.dart';

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

  @override
  void onWindowClose() async {
    // Instead of quitting, hide the window and keep running in the background.
    // Route through TrayService so the macOS Dock icon is also hidden and the
    // tray menu state is updated correctly.
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await TrayService.instance.hideWindow();
    }
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

/// Window controls for Windows & Linux (minimize, maximize/restore, close).
/// Features smooth hover animations and modern Windows 11 style design.
class _WindowControls extends StatelessWidget {
  const _WindowControls({required this.isMaximized});

  final bool isMaximized;

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    return Container(
      height: AppConstants.windowControlHeight,
      decoration: BoxDecoration(color: c.mainBg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WindowControlButton(
            icon: Icons.horizontal_rule_rounded,
            tooltip: 'Minimize',
            defaultColor: c.textSecondary,
            hoverBgColor: c.inputBg,
            hoverIconColor: c.textPrimary,
            onTap: () => windowManager.minimize(),
          ),
          _WindowControlButton(
            icon: isMaximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            tooltip: isMaximized ? 'Restore' : 'Maximize',
            defaultColor: c.textSecondary,
            hoverBgColor: c.inputBg,
            hoverIconColor: c.textPrimary,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowControlButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            defaultColor: c.textSecondary,
            hoverBgColor: AppColors.error,
            hoverIconColor: Colors.white,
            isClose: true,
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

/// Individual window control button with smooth hover animation.
class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.tooltip,
    required this.defaultColor,
    required this.hoverBgColor,
    required this.hoverIconColor,
    required this.onTap,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final Color defaultColor;
  final Color hoverBgColor;
  final Color hoverIconColor;
  final VoidCallback onTap;
  final bool isClose;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter() {
    _controller.forward();
  }

  void _onExit() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final bgColor = Color.lerp(
                Colors.transparent,
                widget.hoverBgColor,
                _animation.value,
              )!;
              final iconColor = Color.lerp(
                widget.defaultColor,
                widget.hoverIconColor,
                _animation.value,
              )!;

              return Container(
                width: AppConstants.windowControlWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: widget.isClose
                      ? const BorderRadius.only(bottomLeft: Radius.circular(8))
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  size: widget.isClose ? 18 : 16,
                  color: iconColor,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
