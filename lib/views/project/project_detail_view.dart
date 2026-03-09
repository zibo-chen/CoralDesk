import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/agent_workspace_api.dart'
    as workspace_api;
import 'package:coraldesk/views/project/projects_page.dart'
    show projectTypeIcon;
import 'package:coraldesk/views/project/project_edit_dialog.dart';

/// Detail view for a project — tabs: Overview, Sessions, Settings
class ProjectDetailView extends ConsumerStatefulWidget {
  const ProjectDetailView({
    super.key,
    required this.projectId,
    required this.onBack,
  });

  final String projectId;
  final VoidCallback onBack;

  @override
  ConsumerState<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends ConsumerState<ProjectDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _editingContext = false;
  late TextEditingController _contextCtrl;
  String? _message;
  bool _isError = false;
  String _sessionSearch = '';

  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _contextCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    setState(() {
      _message = msg;
      _isError = isError;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _createSessionInProject(Project project) {
    final controller = ref.read(chatControllerProvider);
    final sessionId = controller.createSessionInProject(
      project.id,
      defaultRoleId: project.defaultRoleId,
    );
    ref.read(projectsProvider.notifier).addSession(project.id, sessionId);
    ref.read(currentNavProvider.notifier).state = NavSection.chat;
  }

  void _openSession(String sessionId, {String defaultRoleId = ''}) {
    if (defaultRoleId.isNotEmpty) {
      final currentBinding = ref
          .read(sessionAgentBindingProvider.notifier)
          .getBinding(sessionId);
      if (currentBinding == null) {
        ref
            .read(sessionAgentBindingProvider.notifier)
            .bind(sessionId, defaultRoleId);
      }
    }
    ref.read(chatControllerProvider).switchSession(sessionId);
    ref.read(currentNavProvider.notifier).state = NavSection.chat;
  }

  Future<void> _removeSession(Project project, String sessionId) async {
    final l10n = AppLocalizations.of(context)!;
    await ref
        .read(projectsProvider.notifier)
        .removeSession(project.id, sessionId);
    ref.invalidate(projectDetailProvider(project.id));
    _showMessage(l10n.projectSessionRemoved);
  }

  Future<void> _saveContext(String projectId) async {
    final l10n = AppLocalizations.of(context)!;
    await ref
        .read(projectsProvider.notifier)
        .updatePinnedContext(projectId, _contextCtrl.text);
    if (!mounted) return;
    setState(() => _editingContext = false);
    _showMessage(l10n.projectContextSaved);
  }

  Future<void> _changeStatus(Project project, ProjectStatus status) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(projectsProvider.notifier)
        .updateStatus(project.id, status);
    if (ok) {
      ref.invalidate(projectDetailProvider(project.id));
      _showMessage(l10n.projectStatusChanged);
    }
  }

  Future<void> _showEditDialog(Project project) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ProjectEditDialog(project: project),
    );
    if (result == true) {
      ref.invalidate(projectDetailProvider(project.id));
      _showMessage(l10n.projectUpdated);
    }
  }

  Future<void> _deleteProject(Project project) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.projectDeleteTitle),
        content: Text(l10n.projectDeleteConfirm(project.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(projectsProvider.notifier).deleteProject(project.id);
    widget.onBack();
  }

  // ── Roles ──

  Future<void> _showAddRoleDialog(Project project) async {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.read(agentWorkspacesProvider);
    final available =
        workspaces.where((w) => !project.roleIds.contains(w.id)).toList();

    if (available.isEmpty) {
      _showMessage(l10n.projectAllRolesAdded);
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.projectAddRole),
        children: available.map((w) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, w.id),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child:
                        Text(w.avatar, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (w.description.isNotEmpty)
                        Text(
                          w.description,
                          style: TextStyle(fontSize: 12, color: c.textHint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected == null || !mounted) return;
    await ref.read(projectsProvider.notifier).addRole(project.id, selected);
    if (project.roleIds.isEmpty) {
      await ref
          .read(projectsProvider.notifier)
          .setDefaultRole(project.id, selected);
    }
    ref.invalidate(projectDetailProvider(project.id));
    _showMessage(l10n.projectRoleAdded);
  }

  Future<void> _removeRole(Project project, String roleId) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(projectsProvider.notifier).removeRole(project.id, roleId);

    // Sync Dart-side bindings
    final bindings = ref.read(sessionAgentBindingProvider);
    final sessions = ref.read(sessionsProvider);
    for (final s in sessions.where((s) => s.projectId == project.id)) {
      if (bindings[s.id] == roleId) {
        ref.read(sessionAgentBindingProvider.notifier).removeLocal(s.id);
      }
    }

    ref.invalidate(projectDetailProvider(project.id));
    _showMessage(l10n.projectRoleRemoved);
  }

  Future<void> _setDefaultRole(Project project, String roleId) async {
    await ref
        .read(projectsProvider.notifier)
        .setDefaultRole(project.id, roleId);
    ref.invalidate(projectDetailProvider(project.id));
    _showMessage('Default role updated');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectAsync = ref.watch(projectDetailProvider(widget.projectId));

    return projectAsync.when(
      loading: () => _scaffold(l10n.navProjects, true, const SizedBox.shrink()),
      error: (e, _) =>
          _scaffold(l10n.navProjects, false, Center(child: Text('Error: $e'))),
      data: (project) {
        if (project == null) {
          return _scaffold(
            l10n.navProjects,
            false,
            Center(child: Text(l10n.projectNotFound)),
          );
        }
        return _buildDetail(project, l10n);
      },
    );
  }

  Widget _scaffold(String title, bool loading, Widget body) {
    return Column(
      children: [
        _buildHeaderBar(title, null),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : body,
        ),
      ],
    );
  }

  Widget _buildDetail(Project project, AppLocalizations l10n) {
    final color = _parseColor(project.colorTag);

    return Column(
      children: [
        // Top header with back, project info, actions
        _buildProjectHeader(project, color, l10n),

        // Tab bar
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: c.chatListBorder, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: c.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabs: [
              Tab(text: l10n.projectTabOverview),
              Tab(text: l10n.projectTabSessions),
              Tab(text: l10n.projectTabSettings),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildOverviewTab(project, l10n),
              _buildSessionsTab(project, l10n),
              _buildSettingsTab(project, l10n),
            ],
          ),
        ),
      ],
    );
  }

  // ── Header ──

  Widget _buildHeaderBar(String title, Project? project) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        border: Border(
          bottom: BorderSide(color: c.chatListBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            tooltip: l10n.back,
            onPressed: widget.onBack,
          ),
          const SizedBox(width: 8),
          Icon(Icons.folder_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          if (_message != null) ...[
            const Spacer(),
            Text(
              _message!,
              style: TextStyle(
                fontSize: 13,
                color: _isError ? AppColors.error : AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectHeader(
    Project project,
    Color color,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        border: Border(
          bottom: BorderSide(color: c.chatListBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: widget.onBack,
            tooltip: l10n.back,
          ),
          const SizedBox(width: 12),

          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                projectTypeIcon(project.projectType),
                size: 22,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _statusBadge(project),
                    _infoBadge(
                      Icons.chat_bubble_outline,
                      l10n.projectSessionCount(project.sessionIds.length),
                    ),
                    if (project.hasRoles)
                      _infoBadge(
                        Icons.people_outline,
                        l10n.projectRoleCount(project.roleCount),
                      ),
                    if (project.hasProjectDir)
                      _infoBadge(
                        Icons.folder_open_outlined,
                        project.projectDir.split('/').last,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Message
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _message!,
                style: TextStyle(
                  fontSize: 13,
                  color: _isError ? AppColors.error : AppColors.success,
                ),
              ),
            ),

          // Actions
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: l10n.projectEdit,
            onPressed: () => _showEditDialog(project),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.projectNewSession),
            onPressed: () => _createSessionInProject(project),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(Project project) {
    Color statusColor;
    IconData statusIcon;
    switch (project.status) {
      case ProjectStatus.active:
        statusColor = AppColors.success;
        statusIcon = Icons.circle;
      case ProjectStatus.paused:
        statusColor = AppColors.warning;
        statusIcon = Icons.pause_circle_filled;
      case ProjectStatus.archived:
        statusColor = const Color(0xFF9E9E9E);
        statusIcon = Icons.archive;
      case ProjectStatus.completed:
        statusColor = const Color(0xFF2196F3);
        statusIcon = Icons.check_circle;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 10, color: statusColor),
          const SizedBox(width: 4),
          Text(
            project.status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.textHint),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: c.textHint),
          ),
        ],
      ),
    );
  }

  // ── Overview Tab ──

  Widget _buildOverviewTab(Project project, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (project.description.isNotEmpty) ...[
            Text(
              project.description,
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Pinned Context
          _buildPinnedContextSection(project, l10n),
          const SizedBox(height: 24),

          // Roles
          _buildRolesSection(project, l10n),
        ],
      ),
    );
  }

  Widget _buildPinnedContextSection(Project project, AppLocalizations l10n) {
    if (!_editingContext) {
      _contextCtrl.text = project.pinnedContext;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.inputBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin_outlined, size: 16, color: c.textSecondary),
              const SizedBox(width: 6),
              Text(
                l10n.projectPinnedContext,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              if (!_editingContext)
                _iconTextButton(
                  Icons.edit_outlined,
                  l10n.edit,
                  () => setState(() => _editingContext = true),
                )
              else ...[
                TextButton(
                  onPressed: () => setState(() => _editingContext = false),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _saveContext(project.id),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(l10n.save),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_editingContext)
            TextField(
              controller: _contextCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n.projectContextHint,
                filled: true,
                fillColor: c.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.inputBorder),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minHeight: 60),
              child: Text(
                project.pinnedContext.isNotEmpty
                    ? project.pinnedContext
                    : l10n.projectContextEmpty,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: project.pinnedContext.isNotEmpty
                      ? c.textPrimary
                      : c.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRolesSection(Project project, AppLocalizations l10n) {
    final workspaces = ref.watch(agentWorkspacesProvider);
    final projectRoles =
        workspaces.where((w) => project.roleIds.contains(w.id)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.inputBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, size: 16, color: c.textSecondary),
              const SizedBox(width: 6),
              Text(
                l10n.projectRoles,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              _iconTextButton(
                Icons.add,
                l10n.projectAddRole,
                () => _showAddRoleDialog(project),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (projectRoles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.projectNoRoles,
                style: TextStyle(fontSize: 13, color: c.textHint),
              ),
            )
          else
            Column(
              children: projectRoles.map((role) {
                final isDefault = role.id == project.defaultRoleId;
                return _RoleTile(
                  role: role,
                  isDefault: isDefault,
                  onSetDefault: () =>
                      _setDefaultRole(project, role.id),
                  onRemove: () => _removeRole(project, role.id),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Sessions Tab ──

  Widget _buildSessionsTab(Project project, AppLocalizations l10n) {
    final allSessions = ref.watch(sessionsProvider);
    final projectSessions =
        allSessions.where((s) => project.sessionIds.contains(s.id)).toList();

    // Filter by search
    var filtered = projectSessions;
    if (_sessionSearch.isNotEmpty) {
      final q = _sessionSearch.toLowerCase();
      filtered =
          filtered.where((s) => s.title.toLowerCase().contains(q)).toList();
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: SizedBox(
            height: 36,
            child: TextField(
              onChanged: (v) => setState(() => _sessionSearch = v),
              decoration: InputDecoration(
                hintText: l10n.projectSearchSessions,
                prefixIcon:
                    Icon(Icons.search, size: 18, color: c.textHint),
                filled: true,
                fillColor: c.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.inputBorder),
                ),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: TextStyle(fontSize: 13, color: c.textPrimary),
            ),
          ),
        ),

        // Session list
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptySessions(project, l10n)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final session = filtered[i];
                    return _SessionTile(
                      session: session,
                      project: project,
                      onOpen: () => _openSession(
                        session.id,
                        defaultRoleId: project.defaultRoleId,
                      ),
                      onRemove: () =>
                          _removeSession(project, session.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySessions(Project project, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: c.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.projectNoSessions,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.projectNewSession),
            onPressed: () => _createSessionInProject(project),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings Tab ──

  Widget _buildSettingsTab(Project project, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status management
          _buildSettingsSection(
            icon: Icons.flag_outlined,
            title: 'Status',
            child: _buildStatusSelector(project, l10n),
          ),
          const SizedBox(height: 20),

          // Project Info (read-only, click to edit)
          _buildSettingsSection(
            icon: Icons.info_outline,
            title: 'Project Info',
            trailing: _iconTextButton(
              Icons.edit_outlined,
              l10n.edit,
              () => _showEditDialog(project),
            ),
            child: _buildInfoCards(project, l10n),
          ),
          const SizedBox(height: 20),

          // Danger zone
          _buildSettingsSection(
            icon: Icons.warning_amber,
            title: l10n.projectDangerZone,
            isDanger: true,
            child: _buildDangerZone(project, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
    bool isDanger = false,
  }) {
    final borderColor = isDanger
        ? Colors.red.withValues(alpha: 0.3)
        : c.inputBorder.withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDanger ? Colors.red : c.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDanger ? Colors.red : c.textPrimary,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusSelector(Project project, AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ProjectStatus.values.map((status) {
        final isActive = project.status == status;
        Color statusColor;
        IconData statusIcon;
        String statusLabel;
        switch (status) {
          case ProjectStatus.active:
            statusColor = AppColors.success;
            statusIcon = Icons.play_circle_outline;
            statusLabel = l10n.projectStatusActive;
          case ProjectStatus.paused:
            statusColor = AppColors.warning;
            statusIcon = Icons.pause_circle_outline;
            statusLabel = l10n.projectStatusPaused;
          case ProjectStatus.archived:
            statusColor = const Color(0xFF9E9E9E);
            statusIcon = Icons.archive_outlined;
            statusLabel = l10n.projectStatusArchived;
          case ProjectStatus.completed:
            statusColor = const Color(0xFF2196F3);
            statusIcon = Icons.check_circle_outline;
            statusLabel = l10n.projectStatusCompleted;
        }
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isActive ? null : () => _changeStatus(project, status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? statusColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? statusColor.withValues(alpha: 0.5)
                      : c.inputBorder.withValues(alpha: 0.5),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? statusColor : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCards(Project project, AppLocalizations l10n) {
    return Column(
      children: [
        _infoRow(l10n.projectName, project.name),
        _infoRow(l10n.projectDescription,
            project.description.isEmpty ? '—' : project.description),
        _infoRow(l10n.projectType, project.projectType.label),
        _infoRow(
          l10n.projectDirectory,
          project.hasProjectDir ? project.projectDir : '—',
        ),
        _infoRow(
          'Created',
          _formatDate(project.createdAt),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: c.textHint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(Project project, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.projectDangerDeleteHint,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline, size: 16),
          label: Text(l10n.delete),
          onPressed: () => _deleteProject(project),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  Widget _iconTextButton(IconData icon, String text, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon, size: 14),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

// ──────────────────── Role Tile ──────────────────────────

class _RoleTile extends StatefulWidget {
  const _RoleTile({
    required this.role,
    required this.isDefault,
    required this.onSetDefault,
    required this.onRemove,
  });

  final workspace_api.AgentWorkspaceSummary role;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  @override
  State<_RoleTile> createState() => _RoleTileState();
}

class _RoleTileState extends State<_RoleTile> {
  bool _hovering = false;

  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isDefault
              ? AppColors.primary.withValues(alpha: 0.06)
              : _hovering
                  ? c.inputBg
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isDefault
                ? AppColors.primary.withValues(alpha: 0.3)
                : c.inputBorder.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  widget.role.avatar,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.role.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      if (widget.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.projectDefaultRoleBadge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.role.description.isNotEmpty)
                    Text(
                      widget.role.description,
                      style: TextStyle(fontSize: 11, color: c.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Actions on hover
            if (_hovering || widget.isDefault) ...[
              if (!widget.isDefault)
                Tooltip(
                  message: l10n.projectSetDefaultRole,
                  child: IconButton(
                    icon: const Icon(Icons.star_border, size: 16),
                    onPressed: widget.onSetDefault,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 14,
                  ),
                ),
              Tooltip(
                message: l10n.delete,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: c.textHint,
                  ),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────── Session Tile ──────────────────────

class _SessionTile extends StatefulWidget {
  const _SessionTile({
    required this.session,
    required this.project,
    required this.onOpen,
    required this.onRemove,
  });

  final ChatSession session;
  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _hovering = false;

  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = widget.session;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovering ? c.inputBg : c.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : c.inputBorder.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 18, color: c.textHint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.messageCount} messages · ${_formatDate(session.updatedAt)}',
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                  ],
                ),
              ),
              if (_hovering) ...[
                Tooltip(
                  message: l10n.projectRemoveSession,
                  child: IconButton(
                    icon: Icon(Icons.link_off, size: 16, color: c.textHint),
                    onPressed: widget.onRemove,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 14,
                  ),
                ),
              ],
              Icon(Icons.chevron_right, size: 18, color: c.textHint),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
