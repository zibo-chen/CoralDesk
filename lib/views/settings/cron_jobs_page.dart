import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/providers/chat_provider.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:coraldesk/views/settings/widgets/desktop_dialog.dart';
import 'package:coraldesk/src/rust/api/cron_api.dart' as cron_api;

/// Cron Jobs management page - list, add, edit, delete scheduled tasks
class CronJobsPage extends ConsumerStatefulWidget {
  const CronJobsPage({super.key});

  @override
  ConsumerState<CronJobsPage> createState() => _CronJobsPageState();
}

class _CronJobsPageState extends ConsumerState<CronJobsPage> {
  cron_api.CronConfigDto? _config;
  List<cron_api.CronJobDto> _jobs = [];
  bool _loading = true;
  String? _message;
  String? _expandedJobId; // For viewing run history
  List<cron_api.CronRunDto> _runs = [];
  String? _runningJobId; // Track which job is currently being run manually
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final config = await cron_api.getCronConfig();
    final jobs = await cron_api.listCronJobs();
    if (mounted) {
      setState(() {
        _config = config;
        _jobs = jobs;
        _loading = false;
      });
    }
  }

  Future<void> _loadRuns(String jobId) async {
    if (_expandedJobId == jobId) {
      setState(() {
        _expandedJobId = null;
        _runs = [];
      });
      return;
    }
    final runs = await cron_api.listCronRuns(jobId: jobId, limit: 20);
    setState(() {
      _expandedJobId = jobId;
      _runs = runs;
    });
  }

  Future<void> _deleteJob(String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteCronJobTitle),
        content: Text(AppLocalizations.of(context)!.deleteCronJobConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final result = await cron_api.removeCronJob(jobId: jobId);
      if (!mounted) return;
      if (result == 'ok') {
        _showMessage(AppLocalizations.of(context)!.deleted);
        _loadAll();
      } else {
        _showMessage(
          AppLocalizations.of(context)!.deleteFailedWithError(result),
        );
      }
    }
  }

  Future<void> _toggleJob(String jobId, bool enabled) async {
    final result = enabled
        ? await cron_api.resumeCronJob(jobId: jobId)
        : await cron_api.pauseCronJob(jobId: jobId);
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(
        enabled
            ? AppLocalizations.of(context)!.cronJobEnabled
            : AppLocalizations.of(context)!.cronJobPaused,
      );
      _loadAll();
    } else {
      _showMessage('${AppLocalizations.of(context)!.operationFailed}: $result');
    }
  }

  Future<void> _runJobNow(String jobId) async {
    setState(() => _runningJobId = jobId);
    try {
      final result = await cron_api.runCronJobNow(jobId: jobId);
      if (!mounted) return;
      if (result.startsWith('ok')) {
        _showMessage(AppLocalizations.of(context)!.executionSuccess);
      } else {
        _showMessage(
          AppLocalizations.of(context)!.executionFailedWithError(result),
        );
      }
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        AppLocalizations.of(context)!.executionErrorWithError(e.toString()),
      );
    } finally {
      if (mounted) setState(() => _runningJobId = null);
    }
  }

  Future<void> _showAddDialog() async {
    final result = await showDialog<_NewJobData>(
      context: context,
      builder: (ctx) => const _AddJobDialog(),
    );
    if (result == null) return;

    String apiResult;
    if (result.jobType == 'shell') {
      apiResult = await cron_api.addShellCronJob(
        name: result.name.isNotEmpty ? result.name : null,
        scheduleType: result.scheduleType,
        expression: result.expression,
        command: result.command,
      );
    } else {
      // When session_target is "main", capture the current active session ID
      // so cron results get injected into that specific session later
      final String? targetSessionId = result.sessionTarget == 'main'
          ? ref.read(activeSessionIdProvider)
          : null;

      apiResult = await cron_api.addAgentCronJob(
        name: result.name.isNotEmpty ? result.name : null,
        scheduleType: result.scheduleType,
        expression: result.expression,
        prompt: result.prompt,
        sessionTarget: result.sessionTarget,
        model: result.model.isNotEmpty ? result.model : null,
        deleteAfterRun: result.deleteAfterRun,
        targetSessionId: targetSessionId,
      );
    }

    if (!mounted) return;
    if (!apiResult.startsWith('error')) {
      _showMessage(AppLocalizations.of(context)!.cronJobCreated);
      _loadAll();
    } else {
      _showMessage(
        AppLocalizations.of(context)!.createFailedWithError(apiResult),
      );
    }
  }

  void _showMessage(String msg) {
    setState(() => _message = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: AppLocalizations.of(context)!.pageCronJobs,
      icon: Icons.schedule,
      isLoading: _loading,
      useScrollView: false,
      actions: [
        if (_config != null) ...[
          _statBadge(
            '${_config!.totalJobs}',
            AppLocalizations.of(context)!.totalCount,
          ),
          const SizedBox(width: 8),
          _statBadge(
            '${_config!.activeJobs}',
            AppLocalizations.of(context)!.running,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          if (_config!.pausedJobs > 0)
            _statBadge(
              '${_config!.pausedJobs}',
              AppLocalizations.of(context)!.paused,
              color: AppColors.warning,
            ),
        ],
        if (_message != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _message!,
              style: const TextStyle(color: AppColors.success, fontSize: 13),
            ),
          ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: AppLocalizations.of(context)!.refresh,
          onPressed: _loadAll,
        ),
        const SizedBox(width: 4),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add, size: 18),
          label: Text(AppLocalizations.of(context)!.newTask),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
      body: _buildContent(),
    );
  }

  Widget _statBadge(String value, String label, {Color? color}) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildContent() {
    if (_jobs.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _jobs.length,
      itemBuilder: (ctx, i) => _buildJobCard(_jobs[i]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: c.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noCronJobs,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noCronJobsHint,
            style: TextStyle(fontSize: 14, color: c.textHint),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.newTask),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(cron_api.CronJobDto job) {
    final isAgent = job.jobType == 'agent';
    final isExpanded = _expandedJobId == job.id;
    final nextRun = DateTime.fromMillisecondsSinceEpoch(job.nextRun * 1000);
    final nextRunStr = _formatDateTime(nextRun);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Job header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    // Type icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isAgent
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isAgent ? Icons.smart_toy : Icons.terminal,
                        size: 20,
                        color: isAgent ? AppColors.primary : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.name.isNotEmpty ? job.name : job.id,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _chipLabel(
                                isAgent ? 'Agent' : 'Shell',
                                color: isAgent
                                    ? AppColors.primary
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              _chipLabel(
                                job.scheduleDisplay,
                                color: c.textSecondary,
                              ),
                              if (isAgent && job.sessionTarget == 'main') ...[
                                const SizedBox(width: 6),
                                _chipLabel(
                                  AppLocalizations.of(context)!.mainSession,
                                  color: AppColors.success,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status + actions
                    Switch(
                      value: job.enabled,
                      activeTrackColor: AppColors.success,
                      onChanged: (v) => _toggleJob(job.id, v),
                    ),
                    // Run Now button
                    _runningJobId == job.id
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.play_arrow, size: 22),
                            tooltip: AppLocalizations.of(context)!.runNow,
                            color: AppColors.success,
                            onPressed: () => _runJobNow(job.id),
                          ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 20, color: c.textHint),
                      onSelected: (action) {
                        if (action == 'run') _runJobNow(job.id);
                        if (action == 'history') _loadRuns(job.id);
                        if (action == 'delete') _deleteJob(job.id);
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'run',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_arrow,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context)!.runNow),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'history',
                          child: Row(
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isExpanded
                                    ? AppLocalizations.of(
                                        context,
                                      )!.collapseHistory
                                    : AppLocalizations.of(context)!.runHistory,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.delete,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Command/prompt
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.mainBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: c.chatListBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    isAgent ? job.prompt : job.command,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      fontFamily: isAgent ? null : 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Info row
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: c.textHint),
                    const SizedBox(width: 4),
                    Text(
                      '${AppLocalizations.of(context)!.nextExecution}: $nextRunStr',
                      style: TextStyle(fontSize: 12, color: c.textHint),
                    ),
                    if (job.lastStatus.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(
                        job.lastStatus == 'ok'
                            ? Icons.check_circle
                            : Icons.error,
                        size: 14,
                        color: job.lastStatus == 'ok'
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${AppLocalizations.of(context)!.lastRun}: ${job.lastStatus}',
                        style: TextStyle(
                          fontSize: 12,
                          color: job.lastStatus == 'ok'
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                    if (isAgent && job.model.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.memory, size: 14, color: c.textHint),
                      const SizedBox(width: 4),
                      Text(
                        job.model,
                        style: TextStyle(fontSize: 12, color: c.textHint),
                      ),
                    ],
                    if (job.deleteAfterRun) ...[
                      const SizedBox(width: 16),
                      _chipLabel(
                        AppLocalizations.of(context)!.oneTime,
                        color: AppColors.warning,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Run history (expandable)
          if (isExpanded) _buildRunHistory(),
        ],
      ),
    );
  }

  Widget _chipLabel(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRunHistory() {
    if (_runs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.chatListBorder, width: 1)),
        ),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noRunHistory,
            style: TextStyle(fontSize: 13, color: c.textHint),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.chatListBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.runHistoryRecent(_runs.length),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ),
          ..._runs.map((r) => _buildRunItem(r)),
        ],
      ),
    );
  }

  Widget _buildRunItem(cron_api.CronRunDto run) {
    final started = DateTime.fromMillisecondsSinceEpoch(run.startedAt * 1000);
    final isOk = run.status == 'ok';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.chatListBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: isOk ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            _formatDateTime(started),
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
          const SizedBox(width: 12),
          Text(
            '${run.durationMs}ms',
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              run.output,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: c.textHint,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────── Add Job Dialog ───────────────────

class _NewJobData {
  final String name;
  final String jobType;
  final String scheduleType;
  final String expression;
  final String command;
  final String prompt;
  final String sessionTarget;
  final String model;
  final bool deleteAfterRun;

  _NewJobData({
    required this.name,
    required this.jobType,
    required this.scheduleType,
    required this.expression,
    required this.command,
    required this.prompt,
    required this.sessionTarget,
    required this.model,
    required this.deleteAfterRun,
  });
}

class _AddJobDialog extends StatefulWidget {
  const _AddJobDialog();

  @override
  State<_AddJobDialog> createState() => _AddJobDialogState();
}

class _AddJobDialogState extends State<_AddJobDialog> {
  String _jobType = 'shell';
  String _scheduleType = 'cron';
  String _sessionTarget = 'isolated';
  bool _deleteAfterRun = false;

  final _nameCtl = TextEditingController();
  final _exprCtl = TextEditingController(text: '*/5 * * * *');
  final _commandCtl = TextEditingController();
  final _promptCtl = TextEditingController();
  final _modelCtl = TextEditingController();

  @override
  void dispose() {
    _nameCtl.dispose();
    _exprCtl.dispose();
    _commandCtl.dispose();
    _promptCtl.dispose();
    _modelCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopDialog(
      title: AppLocalizations.of(context)!.newCronJob,
      icon: Icons.schedule_outlined,
      width: 700,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Basic ──
          DialogSection(
            title: 'BASIC',
            icon: Icons.badge_outlined,
            children: [
              FieldRow(
                children: [
                  TextField(
                    controller: _nameCtl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.taskNameOptional,
                      hintText: 'my-backup-task',
                    ),
                  ),
                  // Job type selector inline
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.taskType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: CoralDeskColors.of(context).textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'shell',
                            label: Text(
                              AppLocalizations.of(context)!.shellCommand,
                            ),
                            icon: const Icon(Icons.terminal, size: 18),
                          ),
                          ButtonSegment(
                            value: 'agent',
                            label: Text(AppLocalizations.of(context)!.aiAgent),
                            icon: const Icon(Icons.smart_toy, size: 18),
                          ),
                        ],
                        selected: {_jobType},
                        onSelectionChanged: (v) =>
                            setState(() => _jobType = v.first),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ── Schedule ──
          DialogSection(
            title: 'SCHEDULE',
            icon: Icons.timer_outlined,
            children: [
              FieldRow(
                children: [
                  // Schedule type selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.scheduleType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: CoralDeskColors.of(context).textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: [
                          const ButtonSegment(
                            value: 'cron',
                            label: Text('Cron'),
                          ),
                          ButtonSegment(
                            value: 'every',
                            label: Text(AppLocalizations.of(context)!.interval),
                          ),
                          ButtonSegment(
                            value: 'at',
                            label: Text(
                              AppLocalizations.of(context)!.scheduled,
                            ),
                          ),
                        ],
                        selected: {_scheduleType},
                        onSelectionChanged: (v) {
                          setState(() {
                            _scheduleType = v.first;
                            if (v.first == 'cron') {
                              _exprCtl.text = '*/5 * * * *';
                            } else if (v.first == 'every') {
                              _exprCtl.text = '60000';
                            } else {
                              _exprCtl.text = '';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  // Expression
                  TextField(
                    controller: _exprCtl,
                    decoration: InputDecoration(
                      labelText: _scheduleType == 'cron'
                          ? AppLocalizations.of(context)!.cronExpression
                          : _scheduleType == 'every'
                          ? AppLocalizations.of(context)!.intervalMs
                          : AppLocalizations.of(context)!.executionTime,
                      hintText: _scheduleType == 'cron'
                          ? '*/5 * * * *'
                          : _scheduleType == 'every'
                          ? '60000'
                          : '2025-12-31T23:59:00Z',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Content ──
          DialogSection(
            title: _jobType == 'shell' ? 'SHELL COMMAND' : 'AI AGENT',
            icon: _jobType == 'shell' ? Icons.terminal : Icons.smart_toy,
            children: [
              if (_jobType == 'shell')
                FieldColumn(
                  child: TextField(
                    controller: _commandCtl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      )!.shellCommandLabel,
                      hintText: 'echo "hello world"',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              if (_jobType == 'agent') ...[
                FieldColumn(
                  child: TextField(
                    controller: _promptCtl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.aiPromptLabel,
                      hintText: '检查系统日志并总结异常...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                FieldRow(
                  children: [
                    TextField(
                      controller: _modelCtl,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.modelOptional,
                        hintText: AppLocalizations.of(context)!.useDefaultModel,
                      ),
                    ),
                    // Session target
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.sessionTarget,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: CoralDeskColors.of(context).textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'isolated',
                              label: Text(
                                AppLocalizations.of(context)!.isolated,
                              ),
                            ),
                            ButtonSegment(
                              value: 'main',
                              label: Text(
                                AppLocalizations.of(context)!.mainSession,
                              ),
                            ),
                          ],
                          selected: {_sessionTarget},
                          onSelectionChanged: (v) =>
                              setState(() => _sessionTarget = v.first),
                        ),
                      ],
                    ),
                  ],
                ),
                FieldColumn(
                  child: SwitchListTile(
                    title: Text(
                      AppLocalizations.of(context)!.deleteAfterRun,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.deleteAfterRunDesc,
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _deleteAfterRun,
                    activeTrackColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    onChanged: (v) => setState(() => _deleteAfterRun = v),
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: CoralDeskColors.of(context).inputBorder,
                      ),
                    ),
                    tileColor: CoralDeskColors.of(context).inputBg,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: _canSubmit() ? _submit : null,
          child: Text(AppLocalizations.of(context)!.create),
        ),
      ],
    );
  }

  bool _canSubmit() {
    if (_exprCtl.text.isEmpty) return false;
    if (_jobType == 'shell' && _commandCtl.text.isEmpty) return false;
    if (_jobType == 'agent' && _promptCtl.text.isEmpty) return false;
    return true;
  }

  void _submit() {
    Navigator.pop(
      context,
      _NewJobData(
        name: _nameCtl.text.trim(),
        jobType: _jobType,
        scheduleType: _scheduleType,
        expression: _exprCtl.text.trim(),
        command: _commandCtl.text.trim(),
        prompt: _promptCtl.text.trim(),
        sessionTarget: _sessionTarget,
        model: _modelCtl.text.trim(),
        deleteAfterRun: _deleteAfterRun,
      ),
    );
  }
}
