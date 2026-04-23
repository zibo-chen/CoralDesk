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
  bool _savingAdvancedAgent = false;
  bool _messageIsError = false;
  String? _message;
  late final TextEditingController _dedupExemptCtrl;
  List<ws_api.AgentToolFilterGroupDto> _toolFilterGroups = [];
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _dedupExemptCtrl = TextEditingController();
    _loadAll();
  }

  @override
  void dispose() {
    _dedupExemptCtrl.dispose();
    super.dispose();
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
        _dedupExemptCtrl.text = _joinList(agent.toolCallDedupExempt);
        _toolFilterGroups = agent.toolFilterGroups
            .map(
              (group) => ws_api.AgentToolFilterGroupDto(
                mode: group.mode,
                tools: List<String>.from(group.tools),
                keywords: List<String>.from(group.keywords),
                filterBuiltins: group.filterBuiltins,
              ),
            )
            .toList();
        _loading = false;
      });
    }
  }

  String _joinList(List<String> values) => values.join(', ');

  List<String> _parseList(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _saveAdvancedAgentSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final hasEmptyGroup = _toolFilterGroups.any((group) => group.tools.isEmpty);
    if (hasEmptyGroup) {
      _showMessage(l10n.workspaceToolFilterGroupToolsRequired, isError: true);
      return;
    }

    setState(() => _savingAdvancedAgent = true);
    final result = await ws_api.updateAgentConfig(
      toolCallDedupExempt: _parseList(_dedupExemptCtrl.text),
      toolFilterGroups: _toolFilterGroups,
    );

    if (!mounted) return;
    setState(() => _savingAdvancedAgent = false);
    if (result == 'ok') {
      _showMessage(l10n.configSaved);
      _loadAll();
    } else {
      _showMessage(result, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _message = null;
        _messageIsError = false;
      });
    });
  }

  void _addToolFilterGroup() {
    setState(() {
      _toolFilterGroups = [
        ..._toolFilterGroups,
        const ws_api.AgentToolFilterGroupDto(
          mode: 'dynamic',
          tools: [],
          keywords: [],
          filterBuiltins: false,
        ),
      ];
    });
  }

  void _updateToolFilterGroup(int index, ws_api.AgentToolFilterGroupDto group) {
    setState(() {
      _toolFilterGroups = [
        for (var i = 0; i < _toolFilterGroups.length; i++)
          if (i == index) group else _toolFilterGroups[i],
      ];
    });
  }

  void _removeToolFilterGroup(int index) {
    setState(() {
      _toolFilterGroups = [
        for (var i = 0; i < _toolFilterGroups.length; i++)
          if (i != index) _toolFilterGroups[i],
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.pageWorkspace,
      icon: Icons.business,
      isLoading: _loading,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: l10n.refresh,
          onPressed: _loading ? null : _loadAll,
        ),
        if (_message != null)
          StatusLabel(text: _message!, isError: _messageIsError),
      ],
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
        _buildAgentRoutingSection(),
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

  Widget _buildAgentRoutingSection() {
    final l10n = AppLocalizations.of(context)!;
    return _buildCard(
      title: l10n.workspaceAgentRoutingTitle,
      icon: Icons.alt_route,
      children: [
        Text(
          l10n.workspaceAgentRoutingDesc,
          style: TextStyle(fontSize: 12, height: 1.5, color: c.textHint),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _dedupExemptCtrl,
          decoration: InputDecoration(
            labelText: l10n.workspaceDedupExemptLabel,
            hintText: l10n.workspaceDedupExemptHint,
          ),
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.workspaceDedupExemptDesc,
          style: TextStyle(fontSize: 12, color: c.textHint),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              l10n.workspaceToolFilterGroupsLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _addToolFilterGroup,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.workspaceAddFilterGroup),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_toolFilterGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.inputBorder),
            ),
            child: Text(
              l10n.workspaceNoFilterGroups,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          )
        else
          ...List.generate(
            _toolFilterGroups.length,
            (index) =>
                _buildToolFilterGroupCard(index, _toolFilterGroups[index]),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _savingAdvancedAgent ? null : _saveAdvancedAgentSettings,
            icon: _savingAdvancedAgent
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(
              _savingAdvancedAgent
                  ? AppLocalizations.of(context)!.saving
                  : AppLocalizations.of(context)!.save,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolFilterGroupCard(
    int index,
    ws_api.AgentToolFilterGroupDto group,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.workspaceFilterGroupTitle(index + 1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeToolFilterGroup(index),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: AppLocalizations.of(context)!.delete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: group.mode,
            decoration: InputDecoration(
              labelText: l10n.workspaceFilterGroupModeLabel,
            ),
            items: [
              DropdownMenuItem(
                value: 'dynamic',
                child: Text(l10n.workspaceFilterGroupModeDynamic),
              ),
              DropdownMenuItem(
                value: 'always',
                child: Text(l10n.workspaceFilterGroupModeAlways),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _updateToolFilterGroup(
                index,
                ws_api.AgentToolFilterGroupDto(
                  mode: value,
                  tools: group.tools,
                  keywords: group.keywords,
                  filterBuiltins: group.filterBuiltins,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _joinList(group.tools),
            decoration: InputDecoration(
              labelText: l10n.workspaceFilterGroupToolsLabel,
              hintText: l10n.workspaceFilterGroupToolsHint,
            ),
            onChanged: (value) {
              _toolFilterGroups[index] = ws_api.AgentToolFilterGroupDto(
                mode: group.mode,
                tools: _parseList(value),
                keywords: group.keywords,
                filterBuiltins: group.filterBuiltins,
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _joinList(group.keywords),
            decoration: InputDecoration(
              labelText: l10n.workspaceFilterGroupKeywordsLabel,
              hintText: l10n.workspaceFilterGroupKeywordsHint,
            ),
            onChanged: (value) {
              _toolFilterGroups[index] = ws_api.AgentToolFilterGroupDto(
                mode: group.mode,
                tools: group.tools,
                keywords: _parseList(value),
                filterBuiltins: group.filterBuiltins,
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSwitchField(
            l10n.workspaceFilterBuiltinsLabel,
            group.filterBuiltins,
            (value) {
              _updateToolFilterGroup(
                index,
                ws_api.AgentToolFilterGroupDto(
                  mode: group.mode,
                  tools: group.tools,
                  keywords: group.keywords,
                  filterBuiltins: value,
                ),
              );
            },
          ),
        ],
      ),
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
