import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/workspace_api.dart' as ws_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

/// Tools & MCP management page — enable/disable tools and features with one click
class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  ws_api.FeatureToggles? _features;
  List<ws_api.ToolInfo> _tools = [];
  bool _loading = true;
  String? _message;
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final features = await ws_api.getFeatureToggles();
    final tools = await ws_api.listToolsWithStatus();
    if (mounted) {
      setState(() {
        _features = features;
        _tools = tools;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFeature(String feature, bool enabled) async {
    final result = await ws_api.updateFeatureToggle(
      feature: feature,
      enabled: enabled,
    );
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(
        enabled
            ? AppLocalizations.of(context)!.featureEnabled
            : AppLocalizations.of(context)!.featureDisabled,
      );
      _loadAll();
    } else {
      _showMessage(AppLocalizations.of(context)!.operationFailed);
    }
  }

  Future<void> _setToolApproval(String toolName, String approval) async {
    final result = await ws_api.setToolApproval(
      toolName: toolName,
      approval: approval,
    );
    if (!mounted) return;
    if (result == 'ok') {
      _loadAll();
    } else {
      _showMessage(AppLocalizations.of(context)!.operationFailed);
    }
  }

  void _showMessage(String msg) {
    setState(() => _message = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _message = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: AppLocalizations.of(context)!.pageTools,
      icon: Icons.extension,
      isLoading: _loading,
      actions: [if (_message != null) StatusLabel(text: _message!)],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureTogglesSection(),
          const SizedBox(height: 24),
          _buildToolsSection(),
        ],
      ),
    );
  }

  Widget _buildFeatureTogglesSection() {
    final f = _features;
    if (f == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.toggle_on_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.featureToggles,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.featureTogglesDesc,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 16),

          // Feature grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeatureCard(
                'web_search',
                AppLocalizations.of(context)!.featureWebSearch,
                AppLocalizations.of(context)!.featureWebSearchDesc,
                Icons.search,
                f.webSearchEnabled,
              ),
              _buildFeatureCard(
                'web_fetch',
                AppLocalizations.of(context)!.featureWebFetch,
                AppLocalizations.of(context)!.featureWebFetchDesc,
                Icons.download,
                f.webFetchEnabled,
              ),
              _buildFeatureCard(
                'browser',
                AppLocalizations.of(context)!.featureBrowser,
                AppLocalizations.of(context)!.featureBrowserDesc,
                Icons.open_in_browser,
                f.browserEnabled,
              ),
              _buildFeatureCard(
                'http_request',
                AppLocalizations.of(context)!.featureHttpRequest,
                AppLocalizations.of(context)!.featureHttpRequestDesc,
                Icons.http,
                f.httpRequestEnabled,
              ),
              _buildFeatureCard(
                'memory_auto_save',
                AppLocalizations.of(context)!.featureMemory,
                AppLocalizations.of(context)!.featureMemoryDesc,
                Icons.memory,
                f.memoryAutoSave,
              ),
              _buildFeatureCard(
                'cost_tracking',
                AppLocalizations.of(context)!.featureCostTracking,
                AppLocalizations.of(context)!.featureCostTrackingDesc,
                Icons.attach_money,
                f.costTrackingEnabled,
              ),
              _buildFeatureCard(
                'skills_open',
                AppLocalizations.of(context)!.featureSkillsOpen,
                AppLocalizations.of(context)!.featureSkillsOpenDesc,
                Icons.public,
                f.skillsOpenEnabled,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    String feature,
    String title,
    String description,
    IconData icon,
    bool enabled,
  ) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: () => _toggleFeature(feature, !enabled),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.06)
                : c.inputBg,
            border: Border.all(
              color: enabled ? AppColors.primary : c.inputBorder,
              width: enabled ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : c.inputBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled ? AppColors.primary : c.textHint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: enabled ? AppColors.primary : c.textPrimary,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(fontSize: 10, color: c.textHint),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                enabled ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: enabled ? AppColors.success : c.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsSection() {
    if (_tools.isEmpty) return const SizedBox.shrink();

    // Group by category
    final categories = <String, List<ws_api.ToolInfo>>{};
    for (final tool in _tools) {
      categories.putIfAbsent(tool.category, () => []).add(tool);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.builtInTools,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_tools.length} ${AppLocalizations.of(context)!.builtInTools}',
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.toolApprovalHint,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 16),
          // Legend
          _buildApprovalLegend(),
          const SizedBox(height: 16),
          ...categories.entries.map(
            (entry) => _buildToolCategory(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalLegend() {
    return Row(
      children: [
        _buildLegendItem(
          AppLocalizations.of(context)!.autoApproval,
          AppColors.success.withValues(alpha: 0.1),
          Colors.green,
        ),
        const SizedBox(width: 12),
        _buildLegendItem(
          AppLocalizations.of(context)!.requireConfirmation,
          AppColors.warning.withValues(alpha: 0.1),
          Colors.orange,
        ),
        const SizedBox(width: 12),
        _buildLegendItem(
          AppLocalizations.of(context)!.defaultApproval,
          c.inputBg,
          c.textHint,
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color bg, Color fg) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: fg, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: fg)),
      ],
    );
  }

  Widget _buildToolCategory(String category, List<ws_api.ToolInfo> tools) {
    final l10n = AppLocalizations.of(context)!;
    final categoryLabels = {
      'core': l10n.categoryCore,
      'vcs': l10n.categoryVcs,
      'web': l10n.categoryWeb,
      'memory': l10n.categoryMemoryTools,
      'system': l10n.categorySystem,
      'file': l10n.categoryFile,
      'agent': l10n.categoryAgentTools,
      'cron': l10n.categoryCron,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(category), size: 14, color: c.textHint),
              const SizedBox(width: 6),
              Text(
                categoryLabels[category] ?? category.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textHint,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${tools.length})',
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tools.map(_buildToolRow),
        ],
      ),
    );
  }

  Widget _buildToolRow(ws_api.ToolInfo tool) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(_categoryIcon(tool.category), size: 16, color: c.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(
              tool.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: c.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              tool.description,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Approval toggle chips
          _buildApprovalChip(
            tool,
            'auto',
            AppLocalizations.of(context)!.approvalAuto,
            Colors.green,
          ),
          const SizedBox(width: 4),
          _buildApprovalChip(
            tool,
            'ask',
            AppLocalizations.of(context)!.approvalAsk,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalChip(
    ws_api.ToolInfo tool,
    String approval,
    String label,
    Color color,
  ) {
    final isActive =
        (approval == 'auto' && tool.autoApproved) ||
        (approval == 'ask' && tool.alwaysAsk);

    return InkWell(
      onTap: () {
        // Toggle: if already active, set to default; otherwise set to this approval
        final newApproval = isActive ? 'default' : approval;
        _setToolApproval(tool.name, newApproval);
      },
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? color : c.chatListBorder,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? color : c.textHint,
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'core' => Icons.terminal,
      'vcs' => Icons.merge_type,
      'web' => Icons.language,
      'memory' => Icons.memory,
      'system' => Icons.computer,
      'file' => Icons.description,
      'agent' => Icons.smart_toy,
      'cron' => Icons.schedule,
      _ => Icons.extension,
    };
  }
}
