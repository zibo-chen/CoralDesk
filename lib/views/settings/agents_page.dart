import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/agents_api.dart' as agents_api;
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/config_api.dart' as config_api;
import 'package:coraldesk/src/rust/api/providers_api.dart' as providers_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:coraldesk/views/settings/widgets/desktop_dialog.dart';

/// Sub-agent management page: list, create, edit, delete delegate agents
class AgentsPage extends ConsumerStatefulWidget {
  const AgentsPage({super.key});

  @override
  ConsumerState<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends ConsumerState<AgentsPage> {
  List<agents_api.DelegateAgentDto> _agents = [];
  bool _loading = true;
  String? _message;
  bool _isError = false;
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _loading = true);
    // Reload config from disk to pick up changes made by AI tools
    await agent_api.reloadConfigFromDisk();
    final agents = await agents_api.listDelegateAgents();
    if (mounted) {
      setState(() {
        _agents = agents;
        _loading = false;
      });
    }
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

  Future<void> _deleteAgent(String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.agentDeleteTitle),
        content: Text(l10n.agentDeleteConfirm(name)),
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
    if (confirmed != true) return;

    final result = await agents_api.removeDelegateAgent(name: name);
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(l10n.agentDeleted(name));
      _loadAgents();
    } else {
      _showMessage('${l10n.operationFailed}: $result', isError: true);
    }
  }

  Future<void> _openEditor({agents_api.DelegateAgentDto? existing}) async {
    final result = await showDialog<agents_api.DelegateAgentDto>(
      context: context,
      builder: (ctx) => _AgentEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final saveResult = await agents_api.upsertDelegateAgent(agent: result);
    if (!mounted) return;
    if (saveResult == 'ok') {
      _showMessage(
        existing == null
            ? l10n.agentCreated(result.name)
            : l10n.agentUpdated(result.name),
      );
      _loadAgents();
    } else {
      final error = saveResult.startsWith('error: ')
          ? saveResult.substring(7)
          : saveResult;
      _showMessage('${l10n.operationFailed}: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: c.surfaceBg,
      child: SettingsScaffold(
        title: l10n.pageAgents,
        isLoading: _loading,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: l10n.refresh,
            onPressed: _loadAgents,
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.agentNew),
            onPressed: () => _openEditor(),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status message
            if (_message != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isError
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _isError ? Colors.red : Colors.green[700],
                  ),
                ),
              ),

            // Overview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.chatListBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.agentOverview,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.agentOverviewDesc,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatChip(
                        label: l10n.totalCount,
                        value: '${_agents.length}',
                        color: AppColors.primary,
                        c: c,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        label: l10n.agentAgenticCount,
                        value: '${_agents.where((a) => a.agentic).length}',
                        color: Colors.orange,
                        c: c,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Agent list or empty state
            if (_agents.isEmpty)
              _buildEmptyState(l10n)
            else
              ..._agents.map((agent) => _buildAgentCard(agent, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.hub_outlined, size: 48, color: c.textHint),
          const SizedBox(height: 16),
          Text(
            l10n.agentNoAgents,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.agentNoAgentsHint,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.agentNew),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
    );
  }

  static Color _parseRoleColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF6C757D);
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) return Color(int.parse('FF$cleaned', radix: 16));
    if (cleaned.length == 8) return Color(int.parse(cleaned, radix: 16));
    return const Color(0xFF6C757D);
  }

  Widget _buildAgentCard(
    agents_api.DelegateAgentDto agent,
    AppLocalizations l10n,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: name + badges + actions
          Row(
            children: [
              // Role icon/emoji or default icon
              if (agent.roleIcon != null && agent.roleIcon!.isNotEmpty)
                Text(agent.roleIcon!, style: const TextStyle(fontSize: 18))
              else
                Icon(
                  agent.agentic ? Icons.smart_toy : Icons.assistant,
                  size: 20,
                  color: agent.enabled
                      ? (agent.agentic ? Colors.orange : AppColors.primary)
                      : c.textHint,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  agent.roleLabel ?? agent.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: agent.enabled ? c.textPrimary : c.textHint,
                  ),
                ),
              ),
              if (agent.isPreset)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: _parseRoleColor(
                      agent.roleColor,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Preset',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _parseRoleColor(agent.roleColor),
                    ),
                  ),
                ),
              if (!agent.enabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Disabled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.textHint,
                    ),
                  ),
                ),
              if (agent.agentic)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.agentAgentic,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: c.textHint),
                tooltip: l10n.editMessage,
                onPressed: () => _openEditor(existing: agent),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                tooltip: l10n.delete,
                onPressed: () => _deleteAgent(agent.name),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Info grid
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _InfoTag(label: l10n.providerLabel, value: agent.provider, c: c),
              _InfoTag(label: l10n.modelLabel, value: agent.model, c: c),
              if (agent.temperature != null)
                _InfoTag(
                  label: l10n.temperatureLabel,
                  value: agent.temperature!.toStringAsFixed(1),
                  c: c,
                ),
              _InfoTag(
                label: l10n.agentMaxDepth,
                value: '${agent.maxDepth}',
                c: c,
              ),
              if (agent.agentic)
                _InfoTag(
                  label: l10n.agentMaxIterations,
                  value: '${agent.maxIterations}',
                  c: c,
                ),
            ],
          ),

          // System prompt (truncated)
          if (agent.systemPrompt != null && agent.systemPrompt!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              agent.systemPrompt!.length > 120
                  ? '${agent.systemPrompt!.substring(0, 120)}…'
                  : agent.systemPrompt!,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Allowed tools
          if (agent.agentic && agent.allowedTools.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: agent.allowedTools
                  .map(
                    (tool) => Chip(
                      label: Text(tool, style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ],

          // Capabilities
          if (agent.capabilities.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: agent.capabilities
                  .map(
                    (cap) => Chip(
                      avatar: Icon(
                        Icons.star_outline,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      label: Text(cap, style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Editor Dialog
// ═══════════════════════════════════════════════════════════════

class _AgentEditorDialog extends StatefulWidget {
  final agents_api.DelegateAgentDto? existing;
  const _AgentEditorDialog({this.existing});

  @override
  State<_AgentEditorDialog> createState() => _AgentEditorDialogState();
}

class _AgentEditorDialogState extends State<_AgentEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _systemPromptCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _maxDepthCtrl;
  late final TextEditingController _maxIterCtrl;
  late final TextEditingController _allowedToolsCtrl;
  late final TextEditingController _capabilitiesCtrl;
  late final TextEditingController _priorityCtrl;

  late String _selectedProvider;
  late bool _agentic;
  late bool _useDefault;
  late bool _enabled;
  bool get _isEdit => widget.existing != null;

  late List<config_api.ProviderInfo> _providers;
  List<providers_api.ModelProviderProfileDto> _providerProfiles = [];
  String? _selectedProfileId; // Selected provider profile ID
  config_api.AppConfig? _defaultConfig;

  @override
  void initState() {
    super.initState();
    _providers = config_api.listProviders();
    final e = widget.existing;
    _selectedProvider = e?.provider ?? 'openrouter';
    _agentic = e?.agentic ?? false;
    _enabled = e?.enabled ?? true;
    // Detect if the existing agent uses the default provider
    _useDefault = false;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _modelCtrl = TextEditingController(text: e?.model ?? '');
    _apiKeyCtrl = TextEditingController(text: e?.apiKey ?? '');
    _systemPromptCtrl = TextEditingController(text: e?.systemPrompt ?? '');
    _tempCtrl = TextEditingController(
      text: e?.temperature != null ? e!.temperature!.toStringAsFixed(1) : '',
    );
    _maxDepthCtrl = TextEditingController(text: '${e?.maxDepth ?? 3}');
    _maxIterCtrl = TextEditingController(text: '${e?.maxIterations ?? 10}');
    _allowedToolsCtrl = TextEditingController(
      text: e?.allowedTools.join(', ') ?? '',
    );
    _capabilitiesCtrl = TextEditingController(
      text: e?.capabilities.join(', ') ?? '',
    );
    _priorityCtrl = TextEditingController(text: '${e?.priority ?? 0}');
    // Load default config for the toggle
    _loadDefaultConfig();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _apiKeyCtrl.dispose();
    _systemPromptCtrl.dispose();
    _tempCtrl.dispose();
    _maxDepthCtrl.dispose();
    _maxIterCtrl.dispose();
    _allowedToolsCtrl.dispose();
    _capabilitiesCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultConfig() async {
    final results = await Future.wait([
      config_api.loadConfig(),
      providers_api.listModelProviderProfiles(),
    ]);
    if (mounted) {
      setState(() {
        _defaultConfig = results[0] as config_api.AppConfig;
        _providerProfiles =
            results[1] as List<providers_api.ModelProviderProfileDto>;
      });
    }
  }

  void _applyProfile(providers_api.ModelProviderProfileDto profile) {
    setState(() {
      // Use name (provider type) if available, otherwise use the profile id
      _selectedProvider = profile.name ?? profile.id;
      _modelCtrl.text = profile.defaultModel ?? '';
      _apiKeyCtrl.text = profile.apiKey ?? '';
      _selectedProfileId = profile.id;
    });
  }

  void _applyDefaultConfig() {
    if (_defaultConfig == null) return;
    setState(() {
      _selectedProvider = _defaultConfig!.provider;
      _modelCtrl.text = _defaultConfig!.model;
      _apiKeyCtrl.text = _defaultConfig!.apiKey;
    });
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    if (name.isEmpty || model.isEmpty) return;

    final temp = _tempCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_tempCtrl.text.trim());

    final allowedTools = _allowedToolsCtrl.text
        .split(RegExp(r'[,\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final capabilities = _capabilitiesCtrl.text
        .split(RegExp(r'[,\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final dto = agents_api.DelegateAgentDto(
      name: name,
      provider: _selectedProvider,
      model: model,
      systemPrompt: _systemPromptCtrl.text.trim().isEmpty
          ? null
          : _systemPromptCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim().isEmpty ? null : _apiKeyCtrl.text.trim(),
      temperature: temp,
      maxDepth: int.tryParse(_maxDepthCtrl.text.trim()) ?? 3,
      agentic: _agentic,
      allowedTools: allowedTools,
      maxIterations: int.tryParse(_maxIterCtrl.text.trim()) ?? 10,
      capabilities: capabilities,
      priority: int.tryParse(_priorityCtrl.text.trim()) ?? 0,
      enabled: _enabled,
      isPreset: widget.existing?.isPreset ?? false,
      roleLabel: widget.existing?.roleLabel,
      roleColor: widget.existing?.roleColor,
      roleIcon: widget.existing?.roleIcon,
      allowNestedDelegate: widget.existing?.allowNestedDelegate ?? false,
    );

    Navigator.pop(context, dto);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = CoralDeskColors.of(context);

    return DesktopDialog(
      title: _isEdit ? l10n.agentEdit : l10n.agentNew,
      icon: _isEdit ? Icons.edit_outlined : Icons.hub_outlined,
      width: 760,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ Provider Source ═══
          DialogSection(
            title: 'PROVIDER SOURCE',
            icon: Icons.dns_outlined,
            children: [
              // Provider Profile dropdown (if profiles exist)
              if (_providerProfiles.isNotEmpty)
                FieldColumn(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedProfileId,
                    decoration: InputDecoration(
                      labelText: l10n.providerProfile,
                      hintText: l10n.providerProfileSelectHint,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          l10n.providerProfileManual,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      ..._providerProfiles.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(
                            '${p.id}${p.name != null ? ' (${p.name})' : ''}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (profileId) {
                      if (profileId == null) {
                        setState(() {
                          _selectedProfileId = null;
                          _useDefault = false;
                        });
                      } else {
                        final profile = _providerProfiles.firstWhere(
                          (p) => p.id == profileId,
                        );
                        _applyProfile(profile);
                        setState(() => _useDefault = true);
                      }
                    },
                  ),
                ),

              // Fallback: use default provider toggle
              if (_providerProfiles.isEmpty)
                FieldColumn(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.agentUseDefault,
                      style: TextStyle(fontSize: 14, color: c.textPrimary),
                    ),
                    subtitle: Text(
                      l10n.agentUseDefaultDesc,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    value: _useDefault,
                    onChanged: (v) {
                      setState(() {
                        _useDefault = v;
                        if (v) _applyDefaultConfig();
                      });
                    },
                  ),
                ),

              // Provider + Model side by side
              FieldRow(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue:
                        _providers.any((p) => p.id == _selectedProvider)
                        ? _selectedProvider
                        : _providers.first.id,
                    decoration: InputDecoration(labelText: l10n.providerLabel),
                    items: _providers
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: _selectedProfileId != null
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(() => _selectedProvider = v);
                            }
                          },
                  ),
                  TextField(
                    controller: _modelCtrl,
                    enabled: _selectedProfileId == null,
                    decoration: InputDecoration(
                      labelText: l10n.modelLabel,
                      hintText: l10n.modelNameHint,
                    ),
                  ),
                ],
              ),

              // API Key (full width)
              FieldColumn(
                child: TextField(
                  controller: _apiKeyCtrl,
                  obscureText: true,
                  enabled: _selectedProfileId == null,
                  decoration: InputDecoration(
                    labelText: '${l10n.apiKeyLabel} (${l10n.agentOptional})',
                    hintText: l10n.apiKeyHint,
                  ),
                ),
              ),
            ],
          ),

          // ═══ Basic Info ═══
          DialogSection(
            title: 'BASIC INFO',
            icon: Icons.badge_outlined,
            children: [
              FieldRow(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    enabled: !_isEdit,
                    decoration: InputDecoration(
                      labelText: l10n.agentNameLabel,
                      hintText: 'researcher, coder, summarizer...',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(
                      l10n.agentEnabled,
                      style: TextStyle(fontSize: 14, color: c.textPrimary),
                    ),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: c.inputBorder),
                    ),
                    tileColor: c.inputBg,
                  ),
                ],
              ),
            ],
          ),

          // ═══ Behavior ═══
          DialogSection(
            title: 'BEHAVIOR',
            icon: Icons.tune,
            children: [
              FieldRow(
                children: [
                  TextField(
                    controller: _tempCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          '${l10n.temperatureLabel} (${l10n.agentOptional})',
                      hintText: '0.7',
                    ),
                  ),
                  TextField(
                    controller: _maxDepthCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.agentMaxDepth),
                  ),
                  TextField(
                    controller: _priorityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.agentPriority,
                      hintText: '0',
                    ),
                  ),
                ],
              ),

              // System prompt (full width, taller)
              FieldColumn(
                child: TextField(
                  controller: _systemPromptCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.agentSystemPrompt,
                    hintText: l10n.agentSystemPromptHint,
                    alignLabelWithHint: true,
                  ),
                ),
              ),

              // Capabilities
              FieldColumn(
                child: TextField(
                  controller: _capabilitiesCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.agentCapabilities,
                    hintText: l10n.agentCapabilitiesHint,
                  ),
                ),
              ),
            ],
          ),

          // ═══ Agentic Mode ═══
          DialogSection(
            title: 'AGENTIC MODE',
            icon: Icons.smart_toy_outlined,
            children: [
              FieldColumn(
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    l10n.agentAgenticMode,
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                  ),
                  subtitle: Text(
                    l10n.agentAgenticModeDesc,
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  value: _agentic,
                  onChanged: (v) => setState(() => _agentic = v),
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: c.inputBorder),
                  ),
                  tileColor: c.inputBg,
                ),
              ),

              if (_agentic) ...[
                FieldRow(
                  children: [
                    TextField(
                      controller: _allowedToolsCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.agentAllowedTools,
                        hintText: 'web_search, file_read, shell',
                      ),
                    ),
                    TextField(
                      controller: _maxIterCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.agentMaxIterations,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? l10n.save : l10n.create),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Shared widgets (same pattern as other settings pages)
// ═══════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final CoralDeskColors c;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String label;
  final String value;
  final CoralDeskColors c;

  const _InfoTag({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: c.textHint)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}
