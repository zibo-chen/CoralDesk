import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:coraldesk/constants.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/notification/notification_panel.dart';

/// Left sidebar navigation matching the reference design
class SidebarNav extends ConsumerStatefulWidget {
  const SidebarNav({super.key});

  @override
  ConsumerState<SidebarNav> createState() => _SidebarNavState();
}

class _SidebarNavState extends ConsumerState<SidebarNav> {
  final Map<String, bool> _sectionExpanded = {
    'chat': true,
    'control': true,
    'agent': true,
    'settings': true,
  };

  void _toggleSection(String key) {
    setState(() {
      _sectionExpanded[key] = !(_sectionExpanded[key] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentNav = ref.watch(currentNavProvider);
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final l10n = AppLocalizations.of(context)!;
    final c = CoralDeskColors.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isCollapsed
          ? AppConstants.sidebarCollapsedWidth
          : AppConstants.sidebarWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.sidebarBg,
        border: Border(right: BorderSide(color: c.chatListBorder, width: 1)),
      ),
      child: isCollapsed
          ? _buildCollapsedRail(context, ref, currentNav, l10n, c)
          : _buildExpandedContent(context, ref, currentNav, l10n, c),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    WidgetRef ref,
    NavSection currentNav,
    AppLocalizations l10n,
    CoralDeskColors c,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        _buildLogo(c, ref),
        const SizedBox(height: 8),

        // Chat section
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNavSection(
                  c,
                  icon: Icons.chat_bubble_outline,
                  title: l10n.navSectionChat,
                  isExpanded: _sectionExpanded['chat'] ?? true,
                  onToggle: () => _toggleSection('chat'),
                  children: [
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.circle_outlined,
                      label: l10n.navChat,
                      section: NavSection.chat,
                      isActive: currentNav == NavSection.chat,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.folder_outlined,
                      label: l10n.navProjects,
                      section: NavSection.projects,
                      isActive: currentNav == NavSection.projects,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Control section
                _buildNavSection(
                  c,
                  icon: Icons.wifi_tethering,
                  title: l10n.navSectionControl,
                  isExpanded: _sectionExpanded['control'] ?? true,
                  onToggle: () => _toggleSection('control'),
                  children: [
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.wifi,
                      label: l10n.navChannels,
                      section: NavSection.channels,
                      isActive: currentNav == NavSection.channels,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.people_outline,
                      label: l10n.navSessions,
                      section: NavSection.sessions,
                      isActive: currentNav == NavSection.sessions,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.schedule,
                      label: l10n.navCronJobs,
                      section: NavSection.cronJobs,
                      isActive: currentNav == NavSection.cronJobs,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.open_in_browser,
                      label: l10n.featureBrowser,
                      section: NavSection.browser,
                      isActive: currentNav == NavSection.browser,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.router_outlined,
                      label: l10n.navGateway,
                      section: NavSection.gateway,
                      isActive: currentNav == NavSection.gateway,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Agent section
                _buildNavSection(
                  c,
                  icon: Icons.auto_awesome,
                  title: l10n.navSectionAgent,
                  isExpanded: _sectionExpanded['agent'] ?? true,
                  onToggle: () => _toggleSection('agent'),
                  children: [
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.menu_book,
                      label: l10n.navKnowledge,
                      section: NavSection.knowledge,
                      isActive: currentNav == NavSection.knowledge,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.psychology,
                      label: l10n.navSkills,
                      section: NavSection.skills,
                      isActive: currentNav == NavSection.skills,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.extension,
                      label: l10n.navMcp,
                      section: NavSection.mcp,
                      isActive: currentNav == NavSection.mcp,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.hub_outlined,
                      label: l10n.navAgents,
                      section: NavSection.agents,
                      isActive: currentNav == NavSection.agents,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.business,
                      label: l10n.navWorkspace,
                      section: NavSection.workspace,
                      isActive: currentNav == NavSection.workspace,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.tune,
                      label: l10n.pageTools,
                      section: NavSection.tools,
                      isActive: currentNav == NavSection.tools,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.settings,
                      label: l10n.navConfiguration,
                      section: NavSection.configuration,
                      isActive: currentNav == NavSection.configuration,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Settings section
                _buildNavSection(
                  c,
                  icon: Icons.settings_outlined,
                  title: l10n.navSectionSettings,
                  isExpanded: _sectionExpanded['settings'] ?? true,
                  onToggle: () => _toggleSection('settings'),
                  children: [
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.model_training,
                      label: l10n.navModels,
                      section: NavSection.models,
                      isActive: currentNav == NavSection.models,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.vpn_key,
                      label: l10n.navProxy,
                      section: NavSection.proxy,
                      isActive: currentNav == NavSection.proxy,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.bug_report_outlined,
                      label: 'LLM Debug',
                      section: NavSection.llmDebug,
                      isActive: currentNav == NavSection.llmDebug,
                    ),
                    _buildNavItem(
                      c,
                      ref: ref,
                      icon: Icons.tune_rounded,
                      label: l10n.navAppSettings,
                      section: NavSection.appSettings,
                      isActive: currentNav == NavSection.appSettings,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom bar: notification bell + language toggle + theme toggle
        _buildBottomBar(context, ref, l10n, c),
      ],
    );
  }

  Widget _buildCollapsedRail(
    BuildContext context,
    WidgetRef ref,
    NavSection currentNav,
    AppLocalizations l10n,
    CoralDeskColors c,
  ) {
    final unreadCount = ref.watch(
      cronNotificationProvider.select((s) => s.unreadCount),
    );
    final isNotifOpen = ref.watch(notificationPanelOpenProvider);

    // All nav items as (icon, section, label)
    final navItems = [
      (Icons.circle_outlined, NavSection.chat, l10n.navChat),
      (Icons.folder_outlined, NavSection.projects, l10n.navProjects),
      (Icons.wifi, NavSection.channels, l10n.navChannels),
      (Icons.people_outline, NavSection.sessions, l10n.navSessions),
      (Icons.schedule, NavSection.cronJobs, l10n.navCronJobs),
      (Icons.open_in_browser, NavSection.browser, l10n.featureBrowser),
      (Icons.router_outlined, NavSection.gateway, l10n.navGateway),
      (Icons.menu_book, NavSection.knowledge, l10n.navKnowledge),
      (Icons.psychology, NavSection.skills, l10n.navSkills),
      (Icons.extension, NavSection.mcp, l10n.navMcp),
      (Icons.hub_outlined, NavSection.agents, l10n.navAgents),
      (Icons.business, NavSection.workspace, l10n.navWorkspace),
      (Icons.tune, NavSection.tools, l10n.pageTools),
      (Icons.settings, NavSection.configuration, l10n.navConfiguration),
      (Icons.model_training, NavSection.models, l10n.navModels),
      (Icons.vpn_key, NavSection.proxy, l10n.navProxy),
      (Icons.bug_report_outlined, NavSection.llmDebug, 'LLM Debug'),
      (Icons.tune_rounded, NavSection.appSettings, l10n.navAppSettings),
    ];

    return Column(
      children: [
        // Header: logo icon + expand button (same position as collapse btn in expanded mode)
        DragToMoveArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              11,
              AppConstants.isMacOS ? 32 : 12,
              11,
              8,
            ),
            child: Column(
              children: [
                Tooltip(
                  message: 'CoralDesk',
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.pets,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Expand button — same vertical zone as collapse button in expanded state
                Tooltip(
                  message: l10n.expandSidebar,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        ref.read(sidebarCollapsedProvider.notifier).state =
                            false;
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: c.sidebarText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Nav icons
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: navItems.map((item) {
                final isActive = currentNav == item.$2;
                return Tooltip(
                  message: item.$3,
                  preferBelow: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          ref.read(currentNavProvider.notifier).state = item.$2;
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isActive
                                ? c.sidebarActiveBg
                                : Colors.transparent,
                          ),
                          child: Icon(
                            item.$1,
                            size: 18,
                            color: isActive
                                ? c.sidebarActiveText
                                : c.sidebarText,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Bottom: notification + theme + expand button
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              // Notification bell
              Tooltip(
                message: l10n.notificationPanelTitle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final willOpen = !isNotifOpen;
                        ref.read(notificationPanelOpenProvider.notifier).state =
                            willOpen;
                        if (willOpen) {
                          ref
                              .read(cronNotificationProvider.notifier)
                              .clearUnread();
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              isNotifOpen
                                  ? Icons.notifications
                                  : Icons.notifications_none_outlined,
                              size: 18,
                              color: isNotifOpen
                                  ? AppColors.primary
                                  : c.sidebarText,
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Settings shortcut
              Tooltip(
                message: l10n.navAppSettings,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        ref.read(currentNavProvider.notifier).state =
                            NavSection.appSettings;
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          currentNav == NavSection.appSettings
                              ? Icons.tune_rounded
                              : Icons.tune_outlined,
                          size: 18,
                          color: currentNav == NavSection.appSettings
                              ? AppColors.primary
                              : c.sidebarText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(CoralDeskColors c, WidgetRef ref) {
    final l10n = AppLocalizations.of(ref.context)!;
    // Reduced top padding: macOS only needs space for traffic lights
    final topPadding = AppConstants.isMacOS ? 32.0 : 12.0;
    return DragToMoveArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding, 8, 8),
        child: Row(
          children: [
            // Logo icon - claw paw
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pets, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    AppConstants.appVersion,
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
            ),
            // Collapse sidebar button
            Tooltip(
              message: l10n.collapseSidebar,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    ref.read(sidebarCollapsedProvider.notifier).state = true;
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.chevron_left,
                      size: 18,
                      color: c.sidebarText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavSection(
    CoralDeskColors c, {
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: c.sidebarSection),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.sidebarSection,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: c.sidebarSection,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...children,
      ],
    );
  }

  Widget _buildNavItem(
    CoralDeskColors c, {
    required WidgetRef ref,
    required IconData icon,
    required String label,
    required NavSection section,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            ref.read(currentNavProvider.notifier).state = section;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isActive ? c.sidebarActiveBg : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? c.sidebarActiveText : c.sidebarText,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? c.sidebarActiveText : c.sidebarText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    CoralDeskColors c,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.chatListBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notification bell
          _buildNotificationBell(ref, c),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(WidgetRef ref, CoralDeskColors c) {
    final unreadCount = ref.watch(
      cronNotificationProvider.select((s) => s.unreadCount),
    );
    final isOpen = ref.watch(notificationPanelOpenProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        final willOpen = !isOpen;
        ref.read(notificationPanelOpenProvider.notifier).state = willOpen;
        if (willOpen) {
          ref.read(cronNotificationProvider.notifier).clearUnread();
        }
      },
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isOpen
                    ? Icons.notifications
                    : Icons.notifications_none_outlined,
                size: 18,
                color: isOpen ? AppColors.primary : c.sidebarText,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(ref.context)!.notificationPanelTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isOpen ? FontWeight.w600 : FontWeight.w400,
                color: isOpen ? AppColors.primary : c.sidebarText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
