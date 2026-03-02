import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deskclaw/constants.dart';
import 'package:deskclaw/l10n/app_localizations.dart';
import 'package:deskclaw/providers/providers.dart';
import 'package:deskclaw/theme/app_theme.dart';
import 'package:deskclaw/views/notification/notification_panel.dart';

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
    final c = DeskClawColors.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: isCollapsed
          ? AppConstants.sidebarCollapsedWidth
          : AppConstants.sidebarWidth,
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
    DeskClawColors c,
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
                      icon: Icons.business,
                      label: l10n.navWorkspace,
                      section: NavSection.workspace,
                      isActive: currentNav == NavSection.workspace,
                    ),
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
    DeskClawColors c,
  ) {
    final unreadCount = ref.watch(
      cronNotificationProvider.select((s) => s.unreadCount),
    );
    final isNotifOpen = ref.watch(notificationPanelOpenProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    // All nav items as (icon, section, label)
    final navItems = [
      (Icons.circle_outlined, NavSection.chat, l10n.navChat),
      (Icons.wifi, NavSection.channels, l10n.navChannels),
      (Icons.people_outline, NavSection.sessions, l10n.navSessions),
      (Icons.schedule, NavSection.cronJobs, l10n.navCronJobs),
      (Icons.business, NavSection.workspace, l10n.navWorkspace),
      (Icons.menu_book, NavSection.knowledge, l10n.navKnowledge),
      (Icons.psychology, NavSection.skills, l10n.navSkills),
      (Icons.extension, NavSection.mcp, l10n.navMcp),
      (Icons.hub_outlined, NavSection.agents, l10n.navAgents),
      (Icons.settings, NavSection.configuration, l10n.navConfiguration),
      (Icons.model_training, NavSection.models, l10n.navModels),
      (Icons.vpn_key, NavSection.proxy, l10n.navProxy),
    ];

    return Column(
      children: [
        // Header: logo icon + expand button (same position as collapse btn in expanded mode)
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 20, 11, 8),
          child: Column(
            children: [
              Tooltip(
                message: 'DeskClaw',
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pets, color: Colors.white, size: 20),
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
                      ref.read(sidebarCollapsedProvider.notifier).state = false;
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
              // Theme toggle
              Tooltip(
                message: isDark ? l10n.darkMode : l10n.lightMode,
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
                        ref.read(themeModeProvider.notifier).state = isDark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          size: 18,
                          color: c.sidebarText,
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

  Widget _buildLogo(DeskClawColors c, WidgetRef ref) {
    final l10n = AppLocalizations.of(ref.context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
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
    );
  }

  Widget _buildNavSection(
    DeskClawColors c, {
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
    DeskClawColors c, {
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
    DeskClawColors c,
  ) {
    final locale = ref.watch(localeProvider);
    final isZh = locale.languageCode == 'zh';
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
          const SizedBox(height: 8),
          // Language toggle
          Row(
            children: [
              Icon(Icons.language, size: 16, color: c.sidebarText),
              const SizedBox(width: 8),
              _buildLangChip(
                c,
                label: 'EN',
                selected: !isZh,
                onTap: () {
                  ref.read(localeProvider.notifier).state = const Locale('en');
                },
              ),
              const SizedBox(width: 4),
              _buildLangChip(
                c,
                label: '中文',
                selected: isZh,
                onTap: () {
                  ref.read(localeProvider.notifier).state = const Locale('zh');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Theme toggle
          _buildThemeToggle(context, ref, c),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(WidgetRef ref, DeskClawColors c) {
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

  Widget _buildLangChip(
    DeskClawColors c, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primary : c.chatListBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.sidebarText,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(
    BuildContext context,
    WidgetRef ref,
    DeskClawColors c,
  ) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        ref.read(themeModeProvider.notifier).state = isDark
            ? ThemeMode.light
            : ThemeMode.dark;
      },
      child: Row(
        children: [
          Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            size: 18,
            color: c.sidebarText,
          ),
          const SizedBox(width: 10),
          Text(
            isDark
                ? AppLocalizations.of(context)!.darkMode
                : AppLocalizations.of(context)!.lightMode,
            style: TextStyle(fontSize: 13, color: c.sidebarText),
          ),
        ],
      ),
    );
  }
}
