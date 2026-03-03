import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/workspace_api.dart' as ws_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

/// Configuration page showing autonomy settings and tool permissions
class ConfigurationPage extends ConsumerStatefulWidget {
  const ConfigurationPage({super.key});

  @override
  ConsumerState<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends ConsumerState<ConfigurationPage> {
  ws_api.AutonomyConfig? _autonomy;
  List<ws_api.ToolInfo>? _tools;
  bool _loading = true;
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final autonomy = await ws_api.getAutonomyConfig();
    final tools = await ws_api.listToolsWithStatus();
    if (mounted) {
      setState(() {
        _autonomy = autonomy;
        _tools = tools;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: AppLocalizations.of(context)!.pageConfiguration,
      icon: Icons.settings,
      isLoading: _loading,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAutonomySection(),
        const SizedBox(height: 24),
        _buildToolsSection(),
      ],
    );
  }

  Widget _buildAutonomySection() {
    final a = _autonomy;
    if (a == null) return const SizedBox.shrink();

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
              Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.autonomySecurity,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Autonomy level selector
          Text(
            AppLocalizations.of(context)!.autonomyLevel,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLevelChip(
                'read_only',
                AppLocalizations.of(context)!.readOnly,
                Icons.visibility,
                a.level,
              ),
              const SizedBox(width: 8),
              _buildLevelChip(
                'supervised',
                AppLocalizations.of(context)!.supervised,
                Icons.supervisor_account,
                a.level,
              ),
              const SizedBox(width: 8),
              _buildLevelChip(
                'full',
                AppLocalizations.of(context)!.fullAutonomy,
                Icons.bolt,
                a.level,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Trust Me mode toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.trustMeMode,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.trustMeDescription,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: a.trustMe,
                activeTrackColor: Colors.orange,
                onChanged: (value) async {
                  await ws_api.updateTrustMe(enabled: value);
                  _loadAll();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Settings
          _buildInfoRow(
            AppLocalizations.of(context)!.workspaceOnly,
            a.workspaceOnly
                ? AppLocalizations.of(context)!.yes
                : AppLocalizations.of(context)!.no,
          ),
          _buildInfoRow(
            AppLocalizations.of(context)!.requireApprovalMediumRisk,
            a.requireApprovalForMediumRisk
                ? AppLocalizations.of(context)!.yes
                : AppLocalizations.of(context)!.no,
          ),
          _buildInfoRow(
            AppLocalizations.of(context)!.blockHighRisk,
            a.blockHighRiskCommands
                ? AppLocalizations.of(context)!.yes
                : AppLocalizations.of(context)!.no,
          ),
          _buildInfoRow(
            AppLocalizations.of(context)!.maxActionsPerHour,
            '${a.maxActionsPerHour}',
          ),
          _buildInfoRow(
            AppLocalizations.of(context)!.maxCostPerDay,
            '${a.maxCostPerDayCents}¢',
          ),

          if (a.allowedCommands.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.allowedCommands,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: a.allowedCommands
                  .map(
                    (c) => Chip(
                      label: Text(c, style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],

          if (a.autoApprove.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.autoApprovedTools,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: a.autoApprove
                  .map(
                    (t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.green.shade50,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelChip(
    String value,
    String label,
    IconData icon,
    String current,
  ) {
    final isSelected = current == value;
    return InkWell(
      onTap: () async {
        await ws_api.updateAutonomyLevel(level: value);
        _loadAll();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : c.inputBg,
          border: Border.all(
            color: isSelected ? AppColors.primary : c.chatListBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : c.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsSection() {
    final tools = _tools;
    if (tools == null || tools.isEmpty) return const SizedBox.shrink();

    // Group by category
    final categories = <String, List<ws_api.ToolInfo>>{};
    for (final tool in tools) {
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
                AppLocalizations.of(context)!.toolsSection,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                AppLocalizations.of(context)!.toolCountLabel(tools.length),
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categories.entries.map(
            (entry) => _buildToolCategory(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCategory(String category, List<ws_api.ToolInfo> tools) {
    final categoryLabels = {
      'core': AppLocalizations.of(context)!.categoryCoreTools,
      'vcs': AppLocalizations.of(context)!.categoryVersionControl,
      'web': AppLocalizations.of(context)!.categoryWebNetwork,
      'memory': AppLocalizations.of(context)!.categoryMemory,
      'system': AppLocalizations.of(context)!.categorySystem,
      'file': AppLocalizations.of(context)!.categoryFileProcessing,
      'agent': AppLocalizations.of(context)!.categoryAgent,
      'cron': AppLocalizations.of(context)!.categoryScheduling,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryLabels[category] ?? category.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textHint,
              letterSpacing: 0.5,
            ),
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
          Icon(_toolIcon(tool.category), size: 16, color: c.textSecondary),
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
            ),
          ),
          if (tool.autoApproved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AppLocalizations.of(context)!.approvalAuto,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (tool.alwaysAsk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AppLocalizations.of(context)!.approvalAsk,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _toolIcon(String category) {
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: c.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
