import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:coraldesk/views/project/project_detail_view.dart';
import 'package:coraldesk/views/project/project_create_dialog.dart';

/// Projects page — list, search, filter, and manage projects
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  bool _loading = true;
  String? _message;
  bool _isError = false;
  String _searchQuery = '';
  ProjectStatus? _statusFilter; // null = all

  /// When non-null, show the detail view for this project.
  String? _selectedProjectId;

  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    await ref.read(projectsProvider.notifier).load();
    if (mounted) setState(() => _loading = false);
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

  Future<void> _openCreateDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<ProjectFormResult>(
      context: context,
      builder: (ctx) => const ProjectCreateDialog(),
    );
    if (result == null || !mounted) return;

    final projectId = await ref
        .read(projectsProvider.notifier)
        .createProject(
          name: result.name,
          description: result.description,
          icon: result.icon,
          colorTag: result.colorTag,
          projectType: result.projectType,
          projectDir: result.projectDir,
        );

    if (projectId != null) {
      _showMessage(l10n.projectCreated);
    } else {
      _showMessage(l10n.projectCreateFailed, isError: true);
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
    _showMessage(l10n.projectDeleted);
  }

  Future<void> _changeStatus(Project project, ProjectStatus status) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(projectsProvider.notifier)
        .updateStatus(project.id, status);
    if (ok) {
      _showMessage(l10n.projectStatusChanged);
    }
  }

  List<Project> _filteredProjects(List<Project> projects) {
    var result = projects;
    if (_statusFilter != null) {
      result = result.where((p) => p.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projects = ref.watch(projectsProvider);

    // If a project is selected, show its detail view
    if (_selectedProjectId != null) {
      return ProjectDetailView(
        projectId: _selectedProjectId!,
        onBack: () => setState(() => _selectedProjectId = null),
      );
    }

    return SettingsScaffold(
      title: l10n.navProjects,
      icon: Icons.folder_outlined,
      isLoading: _loading,
      useScrollView: false,
      actions: [
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
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: l10n.tooltipRefresh,
          onPressed: _loadProjects,
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.projectCreate),
          onPressed: _openCreateDialog,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const SizedBox(width: 16),
      ],
      body: projects.isEmpty && !_loading
          ? _buildEmptyState(l10n)
          : _buildBody(projects, l10n),
    );
  }

  Widget _buildBody(List<Project> allProjects, AppLocalizations l10n) {
    final filtered = _filteredProjects(allProjects);

    return Column(
      children: [
        _buildToolbar(allProjects, l10n),
        Expanded(
          child: filtered.isEmpty
              ? _buildNoResults()
              : _buildProjectGrid(filtered, l10n),
        ),
      ],
    );
  }

  Widget _buildToolbar(List<Project> allProjects, AppLocalizations l10n) {
    final statusCounts = <ProjectStatus?, int>{};
    statusCounts[null] = allProjects.length;
    for (final s in ProjectStatus.values) {
      final count = allProjects.where((p) => p.status == s).length;
      if (count > 0) statusCounts[s] = count;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // Search bar
          SizedBox(
            height: 38,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: l10n.projectSearchHint,
                prefixIcon: Icon(Icons.search, size: 18, color: c.textHint),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                isDense: true,
              ),
              style: TextStyle(fontSize: 13, color: c.textPrimary),
            ),
          ),
          const SizedBox(height: 12),

          // Status filter chips
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  l10n.projectFilterAll,
                  null,
                  statusCounts[null] ?? 0,
                ),
                if (statusCounts.containsKey(ProjectStatus.active))
                  _buildFilterChip(
                    l10n.projectStatusActive,
                    ProjectStatus.active,
                    statusCounts[ProjectStatus.active]!,
                  ),
                if (statusCounts.containsKey(ProjectStatus.paused))
                  _buildFilterChip(
                    l10n.projectStatusPaused,
                    ProjectStatus.paused,
                    statusCounts[ProjectStatus.paused]!,
                  ),
                if (statusCounts.containsKey(ProjectStatus.archived))
                  _buildFilterChip(
                    l10n.projectStatusArchived,
                    ProjectStatus.archived,
                    statusCounts[ProjectStatus.archived]!,
                  ),
                if (statusCounts.containsKey(ProjectStatus.completed))
                  _buildFilterChip(
                    l10n.projectStatusCompleted,
                    ProjectStatus.completed,
                    statusCounts[ProjectStatus.completed]!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ProjectStatus? status, int count) {
    final isActive = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _statusFilter = status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : c.inputBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? AppColors.primary : c.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : c.inputBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primary : c.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.projectEmpty,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.projectEmptyHint,
            style: TextStyle(fontSize: 13, color: c.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.projectCreate),
            onPressed: _openCreateDialog,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: c.textHint),
          const SizedBox(height: 12),
          Text(
            'No matching projects',
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectGrid(List<Project> projects, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900
              ? 3
              : constraints.maxWidth > 600
              ? 2
              : 1;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.85,
            ),
            itemCount: projects.length,
            itemBuilder: (ctx, i) => _ProjectCard(
              project: projects[i],
              onTap: () => setState(() => _selectedProjectId = projects[i].id),
              onDelete: () => _deleteProject(projects[i]),
              onChangeStatus: (s) => _changeStatus(projects[i], s),
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────── Project Card ──────────────────────────

class _ProjectCard extends ConsumerStatefulWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
    required this.onChangeStatus,
  });

  final Project project;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<ProjectStatus> onChangeStatus;

  @override
  ConsumerState<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<_ProjectCard> {
  bool _hovering = false;

  CoralDeskColors get c => CoralDeskColors.of(context);

  Color get _projectColor {
    try {
      final cleaned = widget.project.colorTag.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Color get _statusColor {
    switch (widget.project.status) {
      case ProjectStatus.active:
        return AppColors.success;
      case ProjectStatus.paused:
        return AppColors.warning;
      case ProjectStatus.archived:
        return const Color(0xFF9E9E9E);
      case ProjectStatus.completed:
        return const Color(0xFF2196F3);
    }
  }

  IconData get _statusIcon {
    switch (widget.project.status) {
      case ProjectStatus.active:
        return Icons.circle;
      case ProjectStatus.paused:
        return Icons.pause_circle_filled;
      case ProjectStatus.archived:
        return Icons.archive;
      case ProjectStatus.completed:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final color = _projectColor;
    final sessionCount = ref
        .watch(sessionsProvider)
        .where((s) => s.projectId == project.id)
        .length;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering
                  ? color.withValues(alpha: 0.4)
                  : c.inputBorder.withValues(alpha: 0.5),
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: icon + name + menu
              Row(
                children: [
                  // Project type icon with color
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        projectTypeIcon(project.projectType),
                        size: 20,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(_statusIcon, size: 10, color: _statusColor),
                            const SizedBox(width: 4),
                            Text(
                              project.status.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: _statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                project.projectType.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildContextMenu(),
                ],
              ),
              const SizedBox(height: 10),

              // Description
              if (project.description.isNotEmpty)
                Expanded(
                  child: Text(
                    project.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),

              // Footer stats
              _buildFooter(sessionCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextMenu() {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 18, color: c.textHint),
      padding: EdgeInsets.zero,
      splashRadius: 16,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (action) {
        switch (action) {
          case 'archive':
            widget.onChangeStatus(ProjectStatus.archived);
          case 'pause':
            widget.onChangeStatus(ProjectStatus.paused);
          case 'activate':
            widget.onChangeStatus(ProjectStatus.active);
          case 'complete':
            widget.onChangeStatus(ProjectStatus.completed);
          case 'delete':
            widget.onDelete();
        }
      },
      itemBuilder: (ctx) {
        final items = <PopupMenuEntry<String>>[];
        final project = widget.project;

        if (project.status != ProjectStatus.active) {
          items.add(
            PopupMenuItem(
              value: 'activate',
              child: _menuRow(
                Icons.play_circle_outline,
                l10n.projectStatusActive,
                AppColors.success,
              ),
            ),
          );
        }
        if (project.status != ProjectStatus.paused) {
          items.add(
            PopupMenuItem(
              value: 'pause',
              child: _menuRow(
                Icons.pause_circle_outline,
                l10n.projectStatusPaused,
                AppColors.warning,
              ),
            ),
          );
        }
        if (project.status != ProjectStatus.completed) {
          items.add(
            PopupMenuItem(
              value: 'complete',
              child: _menuRow(
                Icons.check_circle_outline,
                l10n.projectStatusCompleted,
                const Color(0xFF2196F3),
              ),
            ),
          );
        }
        if (project.status != ProjectStatus.archived) {
          items.add(
            PopupMenuItem(
              value: 'archive',
              child: _menuRow(
                Icons.archive_outlined,
                l10n.projectStatusArchived,
                c.textHint,
              ),
            ),
          );
        }
        items.add(const PopupMenuDivider());
        items.add(
          PopupMenuItem(
            value: 'delete',
            child: _menuRow(Icons.delete_outline, l10n.delete, Colors.red),
          ),
        );
        return items;
      },
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }

  Widget _buildFooter(int sessionCount) {
    final project = widget.project;
    return Row(
      children: [
        Icon(Icons.chat_bubble_outline, size: 13, color: c.textHint),
        const SizedBox(width: 4),
        Text(
          '$sessionCount',
          style: TextStyle(
            fontSize: 11,
            color: c.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (project.hasProjectDir) ...[
          const SizedBox(width: 12),
          Icon(Icons.folder_open_outlined, size: 13, color: c.textHint),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              project.projectDir.split('/').last,
              style: TextStyle(fontSize: 11, color: c.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Map project type to Material icon
IconData projectTypeIcon(ProjectType type) {
  switch (type) {
    case ProjectType.general:
      return Icons.folder_outlined;
    case ProjectType.codeProject:
      return Icons.code;
    case ProjectType.dataProcessing:
      return Icons.analytics_outlined;
    case ProjectType.writing:
      return Icons.edit_note;
    case ProjectType.automation:
      return Icons.smart_toy_outlined;
  }
}
