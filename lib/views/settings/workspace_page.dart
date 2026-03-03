import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/workspace_api.dart' as ws_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

/// Workspace & Agent Configuration page
class WorkspacePage extends ConsumerStatefulWidget {
  const WorkspacePage({super.key});

  @override
  ConsumerState<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<WorkspacePage> {
  WorkspaceConfig? _workspace;
  AgentConfigDto? _agentConfig;
  MemoryConfigDto? _memoryConfig;
  CostConfigDto? _costConfig;
  bool _loading = true;
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final workspace = await ws_api.getWorkspaceConfig();
    final agent = await ws_api.getAgentConfig();
    final memory = await ws_api.getMemoryConfig();
    final cost = await ws_api.getCostConfig();
    if (mounted) {
      setState(() {
        _workspace = workspace;
        _agentConfig = agent;
        _memoryConfig = memory;
        _costConfig = cost;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: AppLocalizations.of(context)!.pageWorkspace,
      icon: Icons.business,
      isLoading: _loading,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkspaceSection(),
        const SizedBox(height: 24),
        _buildAgentSection(),
        const SizedBox(height: 24),
        _buildMemorySection(),
        const SizedBox(height: 24),
        _buildCostSection(),
      ],
    );
  }

  Widget _buildWorkspaceSection() {
    return _buildCard(
      title: AppLocalizations.of(context)!.workspaceInfo,
      icon: Icons.folder_outlined,
      children: [
        _buildReadOnlyField(
          AppLocalizations.of(context)!.workspaceDirectory,
          _workspace?.workspaceDir ?? '',
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.configFile,
          _workspace?.configPath ?? '',
        ),
      ],
    );
  }

  Widget _buildAgentSection() {
    final agent = _agentConfig;
    if (agent == null) return const SizedBox.shrink();

    return _buildCard(
      title: AppLocalizations.of(context)!.agentSettings,
      icon: Icons.auto_awesome,
      children: [
        _buildNumberField(
          AppLocalizations.of(context)!.maxToolIterations,
          agent.maxToolIterations,
          (v) async {
            await ws_api.updateAgentConfig(maxToolIterations: v);
            _loadAll();
          },
        ),
        _buildNumberField(
          AppLocalizations.of(context)!.maxHistoryMessages,
          agent.maxHistoryMessages,
          (v) async {
            await ws_api.updateAgentConfig(maxHistoryMessages: v);
            _loadAll();
          },
        ),
        _buildSwitchField(
          AppLocalizations.of(context)!.parallelToolExecution,
          agent.parallelTools,
          (v) async {
            await ws_api.updateAgentConfig(parallelTools: v);
            _loadAll();
          },
        ),
        _buildSwitchField(
          AppLocalizations.of(context)!.compactContext,
          agent.compactContext,
          (v) async {
            await ws_api.updateAgentConfig(compactContext: v);
            _loadAll();
          },
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.toolDispatcher,
          agent.toolDispatcher,
        ),
      ],
    );
  }

  Widget _buildMemorySection() {
    final mem = _memoryConfig;
    if (mem == null) return const SizedBox.shrink();

    return _buildCard(
      title: AppLocalizations.of(context)!.memorySection,
      icon: Icons.memory,
      children: [
        _buildReadOnlyField(AppLocalizations.of(context)!.backend, mem.backend),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.autoSave,
          mem.autoSave
              ? AppLocalizations.of(context)!.yes
              : AppLocalizations.of(context)!.no,
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.hygiene,
          mem.hygieneEnabled
              ? AppLocalizations.of(context)!.enabled
              : AppLocalizations.of(context)!.disabled,
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.archiveAfter,
          '${mem.archiveAfterDays} ${AppLocalizations.of(context)!.days}',
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.purgeAfter,
          '${mem.purgeAfterDays} ${AppLocalizations.of(context)!.days}',
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.embeddingProvider,
          mem.embeddingProvider,
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.embeddingModel,
          mem.embeddingModel,
        ),
      ],
    );
  }

  Widget _buildCostSection() {
    final cost = _costConfig;
    if (cost == null) return const SizedBox.shrink();

    return _buildCard(
      title: AppLocalizations.of(context)!.costTracking,
      icon: Icons.attach_money,
      children: [
        _buildReadOnlyField(
          AppLocalizations.of(context)!.enabled,
          cost.enabled
              ? AppLocalizations.of(context)!.yes
              : AppLocalizations.of(context)!.no,
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.dailyLimit,
          '\$${cost.dailyLimitUsd.toStringAsFixed(2)}',
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.monthlyLimit,
          '\$${cost.monthlyLimitUsd.toStringAsFixed(2)}',
        ),
        _buildReadOnlyField(
          AppLocalizations.of(context)!.warnAt,
          '${cost.warnAtPercent}%',
        ),
      ],
    );
  }

  // ── Reusable widgets ──

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: value.toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onFieldSubmitted: (text) {
                final v = int.tryParse(text);
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Re-export the generated types used
typedef WorkspaceConfig = ws_api.WorkspaceConfig;
typedef AgentConfigDto = ws_api.AgentConfigDto;
typedef MemoryConfigDto = ws_api.MemoryConfigDto;
typedef CostConfigDto = ws_api.CostConfigDto;
