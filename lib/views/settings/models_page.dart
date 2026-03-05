import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/routes_api.dart' as routes_api;
import 'package:coraldesk/src/rust/api/providers_api.dart' as providers_api;
import 'package:coraldesk/src/rust/api/config_api.dart' as config_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:coraldesk/views/settings/widgets/desktop_dialog.dart';

/// Models settings page — default provider, model routes, embedding config
class ModelsPage extends ConsumerStatefulWidget {
  const ModelsPage({super.key});

  @override
  ConsumerState<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<ModelsPage> {
  bool _isLoading = true;
  CoralDeskColors get c => CoralDeskColors.of(context);

  // Provider profiles
  List<providers_api.ModelProviderProfileDto> _providerProfiles = [];
  late final List<config_api.ProviderInfo> _availableProviders;
  String _defaultProfileId = '';

  // Embedding config
  String _embeddingProvider = 'none';
  final TextEditingController _embeddingModelCtrl = TextEditingController();
  final TextEditingController _embeddingDimsCtrl = TextEditingController();
  final TextEditingController _embeddingBaseUrlCtrl = TextEditingController();
  final TextEditingController _embeddingApiKeyCtrl = TextEditingController();
  double _vectorWeight = 0.7;
  double _keywordWeight = 0.3;
  double _minRelevanceScore = 0.4;
  bool _isSavingEmbedding = false;
  String? _embeddingSaveMessage;

  @override
  void initState() {
    super.initState();
    try {
      _availableProviders = config_api.listProviders();
    } catch (_) {
      _availableProviders = const [];
    }
    _loadAll();
  }

  @override
  void dispose() {
    _embeddingModelCtrl.dispose();
    _embeddingDimsCtrl.dispose();
    _embeddingBaseUrlCtrl.dispose();
    _embeddingApiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      routes_api.getEmbeddingConfig(),
      providers_api.listModelProviderProfiles(),
      providers_api.getDefaultProfileId(),
    ]);

    final embedding = results[0] as routes_api.EmbeddingConfigDto;
    final profiles = results[1] as List<providers_api.ModelProviderProfileDto>;
    final defaultId = results[2] as String;

    if (!mounted) return;
    setState(() {
      // Provider profiles
      _providerProfiles = profiles;
      _defaultProfileId = defaultId;

      // Embedding
      _embeddingProvider = embedding.embeddingProvider;
      _embeddingModelCtrl.text = embedding.embeddingModel;
      _embeddingDimsCtrl.text = embedding.embeddingDimensions.toString();
      _embeddingBaseUrlCtrl.text = embedding.embeddingBaseUrl ?? '';
      _embeddingApiKeyCtrl.text = embedding.embeddingApiKey ?? '';
      _vectorWeight = embedding.vectorWeight;
      _keywordWeight = embedding.keywordWeight;
      _minRelevanceScore = embedding.minRelevanceScore;

      _isLoading = false;
    });
  }

  Future<void> _saveEmbeddingConfig() async {
    setState(() {
      _isSavingEmbedding = true;
      _embeddingSaveMessage = null;
    });

    final result = await routes_api.updateEmbeddingConfig(
      config: routes_api.EmbeddingConfigDto(
        embeddingProvider: _embeddingProvider,
        embeddingModel: _embeddingModelCtrl.text.trim(),
        embeddingDimensions:
            int.tryParse(_embeddingDimsCtrl.text.trim()) ?? 1536,
        vectorWeight: _vectorWeight,
        keywordWeight: _keywordWeight,
        minRelevanceScore: _minRelevanceScore,
        embeddingBaseUrl: _embeddingBaseUrlCtrl.text.trim().isEmpty
            ? null
            : _embeddingBaseUrlCtrl.text.trim(),
        embeddingApiKey: _embeddingApiKeyCtrl.text.trim().isEmpty
            ? null
            : _embeddingApiKeyCtrl.text.trim(),
      ),
    );

    if (!mounted) return;
    setState(() {
      _isSavingEmbedding = false;
      _embeddingSaveMessage = result == 'ok'
          ? AppLocalizations.of(context)!.embeddingSaved
          : AppLocalizations.of(context)!.configSaveFailed;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _embeddingSaveMessage = null);
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsScaffold(
      title: l10n.pageModels,
      isLoading: _isLoading,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Section 1: Provider Profiles ───
          _buildSection(
            title: l10n.providerProfiles,
            child: _buildProviderProfilesSection(),
          ),

          const SizedBox(height: 24),

          // ─── Section 2: Embedding Config ───
          _buildSection(
            title: l10n.embeddingConfiguration,
            child: _buildEmbeddingSection(),
          ),

          const SizedBox(height: 24),

          // ─── Runtime Status ───
          FutureBuilder<agent_api.RuntimeStatus>(
            future: agent_api.getRuntimeStatus(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final status = snapshot.data!;
              return _buildSection(
                title: l10n.runtimeStatus,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.chatListBorder),
                  ),
                  child: Column(
                    children: [
                      _buildStatusRow(
                        l10n.initialized,
                        status.initialized ? l10n.yes : l10n.no,
                        status.initialized
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      _buildStatusRow(
                        l10n.apiKeyLabel,
                        status.hasApiKey ? l10n.configured : l10n.missing,
                        status.hasApiKey
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      _buildStatusRow(
                        l10n.activeProvider,
                        status.provider,
                        null,
                      ),
                      _buildStatusRow(l10n.activeModel, status.model, null),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Section 1: Provider Profiles
  // ═══════════════════════════════════════════════════════════════

  Widget _buildProviderProfilesSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description + Add button
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.providerProfilesDesc,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.providerProfileNew),
                onPressed: () => _openProfileEditor(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_providerProfiles.isEmpty)
            _buildEmptyProfilesState(l10n)
          else
            ..._providerProfiles.map((p) => _buildProfileCard(p, l10n)),
        ],
      ),
    );
  }

  Widget _buildEmptyProfilesState(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.layers_outlined, size: 36, color: c.textHint),
          const SizedBox(height: 12),
          Text(
            l10n.noProviderProfiles,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.noProviderProfilesHint,
            style: TextStyle(fontSize: 12, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    providers_api.ModelProviderProfileDto profile,
    AppLocalizations l10n,
  ) {
    final isDefault = profile.id == _defaultProfileId;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDefault ? AppColors.primary : c.chatListBorder,
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // ID badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              profile.id,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          // Default badge
          if (isDefault) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    l10n.defaultLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (profile.name != null) profile.name!,
                    if (profile.defaultModel != null) profile.defaultModel!,
                  ].join(' / '),
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.baseUrl != null && profile.baseUrl!.isNotEmpty)
                  Text(
                    profile.baseUrl!,
                    style: TextStyle(fontSize: 11, color: c.textHint),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Set as default (only if not already default)
          if (!isDefault)
            IconButton(
              icon: Icon(Icons.star_outline, size: 18, color: c.textHint),
              tooltip: l10n.setAsDefault,
              onPressed: () => _setDefaultProfile(profile.id),
              visualDensity: VisualDensity.compact,
            ),
          // Edit
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: c.textHint),
            tooltip: l10n.providerProfileEdit,
            onPressed: () => _openProfileEditor(existing: profile),
            visualDensity: VisualDensity.compact,
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: l10n.delete,
            onPressed: () => _deleteProfile(profile.id),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _setDefaultProfile(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await providers_api.setDefaultProfile(id: id);
    if (!mounted) return;
    if (result == 'ok') {
      _showSnack(l10n.providerProfileSetDefault(id));
      setState(() => _defaultProfileId = id);
    } else {
      final error = result.startsWith('error: ') ? result.substring(7) : result;
      _showSnack('${l10n.operationFailed}: $error', isError: true);
    }
  }

  Future<void> _deleteProfile(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerProfileDeleteTitle),
        content: Text(l10n.providerProfileDeleteConfirm(id)),
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

    final result = await providers_api.removeModelProviderProfile(id: id);
    if (!mounted) return;
    if (result == 'ok') {
      _showSnack(l10n.providerProfileDeleted(id));
      _refreshProfiles();
    } else {
      _showSnack('${l10n.operationFailed}: $result', isError: true);
    }
  }

  Future<void> _openProfileEditor({
    providers_api.ModelProviderProfileDto? existing,
  }) async {
    final result = await showDialog<providers_api.ModelProviderProfileDto>(
      context: context,
      builder: (ctx) => _ProfileEditorDialog(
        existing: existing,
        availableProviders: _availableProviders,
      ),
    );
    if (result == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final saveResult = await providers_api.upsertModelProviderProfile(
      profile: result,
    );
    if (!mounted) return;
    if (saveResult == 'ok') {
      _showSnack(l10n.providerProfileSaved);
      _refreshProfiles();
    } else {
      final error = saveResult.startsWith('error: ')
          ? saveResult.substring(7)
          : saveResult;
      _showSnack('${l10n.operationFailed}: $error', isError: true);
    }
  }

  Future<void> _refreshProfiles() async {
    final profiles = await providers_api.listModelProviderProfiles();
    if (mounted) setState(() => _providerProfiles = profiles);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Section 2: Embedding Configuration
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmbeddingSection() {
    final l10n = AppLocalizations.of(context)!;

    final providerOptions = [
      ('none', l10n.embeddingProviderNone),
      ('openai', l10n.embeddingProviderOpenai),
      ('custom', l10n.embeddingProviderCustom),
    ];

    // Map "custom:xxx" to "custom" for dropdown display
    String dropdownValue = _embeddingProvider;
    if (_embeddingProvider.startsWith('custom:')) {
      dropdownValue = 'custom';
    }
    if (!providerOptions.any((o) => o.$1 == dropdownValue)) {
      dropdownValue = 'none';
    }

    final showModelFields = _embeddingProvider != 'none';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.embeddingConfigDesc,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 16),

          // Embedding Provider dropdown
          _buildDropdownRow(
            l10n.embeddingProvider,
            dropdownValue,
            providerOptions.map((o) => o.$1).toList(),
            providerOptions.map((o) => o.$2).toList(),
            (value) {
              setState(() {
                if (value == 'custom') {
                  _embeddingProvider = 'custom:';
                } else {
                  _embeddingProvider = value!;
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Embedding Model + Dimensions (visible when not "none")
          if (showModelFields) ...[
            _buildTextFieldRow(
              l10n.embeddingModel,
              'text-embedding-3-small',
              _embeddingModelCtrl,
            ),
            const SizedBox(height: 16),

            _buildTextFieldRow(
              l10n.embeddingDimensions,
              '1536',
              _embeddingDimsCtrl,
            ),
            const SizedBox(height: 16),

            // Base URL (useful for custom provider or OpenAI-compatible endpoints)
            _buildTextFieldRow(
              l10n.embeddingBaseUrl,
              l10n.embeddingBaseUrlHint,
              _embeddingBaseUrlCtrl,
            ),
            const SizedBox(height: 16),

            // API Key for embedding provider
            _buildTextFieldRow(
              l10n.embeddingApiKey,
              l10n.embeddingApiKeyHint,
              _embeddingApiKeyCtrl,
              obscure: true,
            ),
            const SizedBox(height: 16),
          ],

          // Vector Weight slider
          _buildSliderRow(
            l10n.vectorWeight,
            _vectorWeight,
            (v) => setState(() => _vectorWeight = v),
            max: 1.0,
            divisions: 10,
          ),
          const SizedBox(height: 8),

          // Keyword Weight slider
          _buildSliderRow(
            l10n.keywordWeight,
            _keywordWeight,
            (v) => setState(() => _keywordWeight = v),
            max: 1.0,
            divisions: 10,
          ),
          const SizedBox(height: 8),

          // Min Relevance Score slider
          _buildSliderRow(
            l10n.minRelevanceScore,
            _minRelevanceScore,
            (v) => setState(() => _minRelevanceScore = v),
            max: 1.0,
            divisions: 20,
          ),

          const SizedBox(height: 24),

          // Save button
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isSavingEmbedding ? null : _saveEmbeddingConfig,
                icon: _isSavingEmbedding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSavingEmbedding ? l10n.saving : l10n.save),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (_embeddingSaveMessage != null) ...[
                const SizedBox(width: 16),
                Text(
                  _embeddingSaveMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        _embeddingSaveMessage!.contains('Failed') ||
                            _embeddingSaveMessage!.contains('失败')
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Shared UI builders
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildDropdownRow(
    String label,
    String value,
    List<String> values,
    List<String> displayNames,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.inputBorder),
              color: c.inputBg,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: values.contains(value) ? value : values.first,
                isExpanded: true,
                isDense: true,
                style: TextStyle(fontSize: 14, color: c.textPrimary),
                items: List.generate(values.length, (i) {
                  return DropdownMenuItem(
                    value: values[i],
                    child: Text(displayNames[i]),
                  );
                }),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldRow(
    String label,
    String hint,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    double max = 2.0,
    int divisions = 20,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: 0.0,
                  max: max,
                  divisions: divisions,
                  activeColor: AppColors.primary,
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  value.toStringAsFixed(max <= 1.0 ? 2 : 1),
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? c.textPrimary,
              fontWeight: valueColor != null
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Provider Profile Editor Dialog
// ═══════════════════════════════════════════════════════════════

class _ProfileEditorDialog extends StatefulWidget {
  final providers_api.ModelProviderProfileDto? existing;
  final List<config_api.ProviderInfo> availableProviders;
  const _ProfileEditorDialog({this.existing, required this.availableProviders});

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  static const String _customProviderOption = '__custom__';

  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _apiKeyCtrl;
  late String _wireApi;
  late String _selectedProvider;
  bool get _isEdit => widget.existing != null;

  List<String> get _providerOptions {
    final ids = widget.availableProviders.map((p) => p.id).toSet().toList()
      ..sort();
    return ids;
  }

  bool get _isCustomProvider => _selectedProvider == _customProviderOption;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idCtrl = TextEditingController(text: e?.id ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _baseUrlCtrl = TextEditingController(text: e?.baseUrl ?? '');
    _modelCtrl = TextEditingController(text: e?.defaultModel ?? '');
    _apiKeyCtrl = TextEditingController(text: e?.apiKey ?? '');
    _wireApi = e?.wireApi ?? '';

    final existingName = (e?.name ?? '').trim();
    final options = _providerOptions;
    if (existingName.isNotEmpty && options.contains(existingName)) {
      _selectedProvider = existingName;
    } else if (existingName.isNotEmpty) {
      _selectedProvider = _customProviderOption;
    } else if (options.contains('openai')) {
      _selectedProvider = 'openai';
      _nameCtrl.text = 'openai';
    } else if (options.isNotEmpty) {
      _selectedProvider = options.first;
      _nameCtrl.text = options.first;
    } else {
      _selectedProvider = _customProviderOption;
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;

    // Validation: at least one of name or base_url must be provided
    final name = _nameCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    if (name.isEmpty && baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile must have at least one of "Provider Name" or "Base URL"',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final dto = providers_api.ModelProviderProfileDto(
      id: id,
      name: name.isEmpty ? null : name,
      baseUrl: baseUrl.isEmpty ? null : baseUrl,
      wireApi: _wireApi.isEmpty ? null : _wireApi,
      defaultModel: _modelCtrl.text.trim().isEmpty
          ? null
          : _modelCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim().isEmpty ? null : _apiKeyCtrl.text.trim(),
    );
    Navigator.pop(context, dto);
  }

  void _onProviderChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedProvider = value;
      if (!_isCustomProvider) {
        _nameCtrl.text = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final wireApiOptions = [
      ('', l10n.wireApiAuto),
      ('chat_completions', l10n.wireApiChatCompletions),
      ('responses', l10n.wireApiResponses),
    ];

    return DesktopDialog(
      title: _isEdit ? l10n.providerProfileEdit : l10n.providerProfileNew,
      icon: Icons.dns_outlined,
      width: 680,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity ──
          DialogSection(
            title: l10n.providerProfileId.toUpperCase(),
            icon: Icons.badge_outlined,
            children: [
              FieldRow(
                children: [
                  TextField(
                    controller: _idCtrl,
                    enabled: !_isEdit,
                    decoration: InputDecoration(
                      labelText: l10n.providerProfileId,
                      hintText: l10n.providerProfileIdHint,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvider,
                    decoration: InputDecoration(
                      labelText: l10n.providerProfileName,
                    ),
                    items: [
                      ..._providerOptions.map(
                        (provider) => DropdownMenuItem(
                          value: provider,
                          child: Text(provider),
                        ),
                      ),
                      DropdownMenuItem(
                        value: _customProviderOption,
                        child: Text(l10n.providerProfileManual),
                      ),
                    ],
                    onChanged: _onProviderChanged,
                  ),
                ],
              ),
              if (_isCustomProvider)
                FieldColumn(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.providerProfileName,
                      hintText: l10n.providerProfileNameHint,
                    ),
                  ),
                ),
            ],
          ),

          // ── Connection ──
          DialogSection(
            title: 'CONNECTION',
            icon: Icons.link,
            children: [
              FieldRow(
                children: [
                  TextField(
                    controller: _baseUrlCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.providerProfileBaseUrl,
                      hintText: l10n.providerProfileBaseUrlHint,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _wireApi,
                    decoration: InputDecoration(
                      labelText: l10n.providerProfileWireApi,
                    ),
                    items: wireApiOptions
                        .map(
                          (o) =>
                              DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _wireApi = v);
                    },
                  ),
                ],
              ),
            ],
          ),

          // ── Model & Auth ──
          DialogSection(
            title: 'MODEL & AUTH',
            icon: Icons.vpn_key_outlined,
            children: [
              FieldRow(
                children: [
                  TextField(
                    controller: _modelCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.providerProfileModel,
                      hintText: l10n.providerProfileModelHint,
                    ),
                  ),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '${l10n.apiKeyLabel} (${l10n.agentOptional})',
                      hintText: l10n.apiKeyHint,
                    ),
                  ),
                ],
              ),
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
