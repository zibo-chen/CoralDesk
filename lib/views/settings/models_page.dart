import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/config_api.dart' as config_api;
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/routes_api.dart' as routes_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

/// Models settings page — default provider, model routes, embedding config
class ModelsPage extends ConsumerStatefulWidget {
  const ModelsPage({super.key});

  @override
  ConsumerState<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<ModelsPage> {
  late List<config_api.ProviderInfo> _providers;
  String _selectedProviderId = 'openrouter';
  String _selectedModel = 'anthropic/claude-sonnet-4-20250514';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiBaseController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  double _temperature = 0.7;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _saveMessage;
  CoralDeskColors get c => CoralDeskColors.of(context);

  // Model routes
  List<routes_api.ModelRouteDto> _modelRoutes = [];

  // Embedding config
  String _embeddingProvider = 'none';
  final TextEditingController _embeddingModelCtrl = TextEditingController();
  final TextEditingController _embeddingDimsCtrl = TextEditingController();
  double _vectorWeight = 0.7;
  double _keywordWeight = 0.3;
  double _minRelevanceScore = 0.4;
  bool _isSavingEmbedding = false;
  String? _embeddingSaveMessage;

  /// Providers that allow custom model name input
  static const _customModelProviders = {'compatible', 'ollama', 'openrouter'};

  @override
  void initState() {
    super.initState();
    _providers = config_api.listProviders();
    _loadAll();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiBaseController.dispose();
    _modelController.dispose();
    _embeddingModelCtrl.dispose();
    _embeddingDimsCtrl.dispose();
    super.dispose();
  }

  bool get _supportsCustomModel =>
      _customModelProviders.contains(_selectedProviderId);

  Future<void> _loadAll() async {
    final results = await Future.wait([
      config_api.loadConfig(),
      routes_api.listModelRoutes(),
      routes_api.getEmbeddingConfig(),
    ]);

    final config = results[0] as config_api.AppConfig;
    final routes = results[1] as List<routes_api.ModelRouteDto>;
    final embedding = results[2] as routes_api.EmbeddingConfigDto;

    if (!mounted) return;
    setState(() {
      // Default provider
      _selectedProviderId = config.provider;
      _selectedModel = config.model;
      _modelController.text = config.model;
      _apiKeyController.text = config.apiKey;
      _apiBaseController.text = config.apiBase ?? '';
      _temperature = config.temperature;

      // Routes
      _modelRoutes = routes;

      // Embedding
      _embeddingProvider = embedding.embeddingProvider;
      _embeddingModelCtrl.text = embedding.embeddingModel;
      _embeddingDimsCtrl.text = embedding.embeddingDimensions.toString();
      _vectorWeight = embedding.vectorWeight;
      _keywordWeight = embedding.keywordWeight;
      _minRelevanceScore = embedding.minRelevanceScore;

      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    final modelToSave = _supportsCustomModel
        ? _modelController.text.trim()
        : _selectedModel;

    final success = await config_api.saveConfig(
      config: config_api.AppConfig(
        provider: _selectedProviderId,
        model: modelToSave,
        apiKey: _apiKeyController.text.trim(),
        apiBase: _apiBaseController.text.trim().isEmpty
            ? null
            : _apiBaseController.text.trim(),
        temperature: _temperature,
        maxToolIterations: 10,
        language: 'en',
      ),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saveMessage = success
          ? AppLocalizations.of(context)!.configSaved
          : AppLocalizations.of(context)!.configSaveFailed;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _saveMessage = null);
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

  Future<void> _deleteRoute(String hint) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRouteTitle),
        content: Text(l10n.deleteRouteConfirm),
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

    final result = await routes_api.removeModelRoute(hint: hint);
    if (!mounted) return;
    if (result == 'ok') {
      _showSnack(l10n.routeDeleted);
      _refreshRoutes();
    } else {
      _showSnack('${l10n.operationFailed}: $result', isError: true);
    }
  }

  Future<void> _openRouteEditor({routes_api.ModelRouteDto? existing}) async {
    final result = await showDialog<routes_api.ModelRouteDto>(
      context: context,
      builder: (ctx) =>
          _RouteEditorDialog(providers: _providers, existing: existing),
    );
    if (result == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final saveResult = await routes_api.upsertModelRoute(route: result);
    if (!mounted) return;
    if (saveResult == 'ok') {
      _showSnack(l10n.routeSaved);
      _refreshRoutes();
    } else {
      final error = saveResult.startsWith('error: ')
          ? saveResult.substring(7)
          : saveResult;
      _showSnack('${l10n.operationFailed}: $error', isError: true);
    }
  }

  Future<void> _refreshRoutes() async {
    final routes = await routes_api.listModelRoutes();
    if (mounted) setState(() => _modelRoutes = routes);
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

  config_api.ProviderInfo get _currentProvider {
    return _providers.firstWhere(
      (p) => p.id == _selectedProviderId,
      orElse: () => _providers.first,
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
          // ─── Section 1: Default Provider ───
          _buildSection(
            title: l10n.providerConfiguration,
            child: _buildDefaultProviderSection(),
          ),

          const SizedBox(height: 24),

          // ─── Section 2: Model Routes ───
          _buildSection(
            title: l10n.modelRoutes,
            child: _buildModelRoutesSection(),
          ),

          const SizedBox(height: 24),

          // ─── Section 3: Embedding Config ───
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
  //  Section 1: Default Provider
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDefaultProviderSection() {
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
          // Provider dropdown
          _buildDropdownRow(
            l10n.providerLabel,
            _selectedProviderId,
            _providers.map((p) => p.id).toList(),
            _providers.map((p) => p.name).toList(),
            (value) {
              setState(() {
                _selectedProviderId = value!;
                final provider = _currentProvider;
                if (provider.models.isNotEmpty) {
                  _selectedModel = provider.models.first;
                  _modelController.text = _selectedModel;
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Model selector
          if (_supportsCustomModel)
            _buildEditableModelRow()
          else
            _buildDropdownRow(
              l10n.modelLabel,
              _currentProvider.models.contains(_selectedModel)
                  ? _selectedModel
                  : _currentProvider.models.first,
              _currentProvider.models,
              _currentProvider.models,
              (value) {
                setState(() {
                  _selectedModel = value!;
                  _modelController.text = value;
                });
              },
            ),
          const SizedBox(height: 16),

          // API Key
          if (_currentProvider.requiresApiKey) ...[
            _buildTextFieldRow(
              l10n.apiKeyLabel,
              l10n.apiKeyHint,
              _apiKeyController,
              obscure: true,
            ),
            const SizedBox(height: 16),
          ],

          // API Base URL
          if (_currentProvider.requiresApiBase) ...[
            _buildTextFieldRow(
              l10n.apiBaseUrlLabel,
              _selectedProviderId == 'ollama'
                  ? 'http://localhost:11434'
                  : 'https://api.example.com/v1',
              _apiBaseController,
            ),
            const SizedBox(height: 16),
          ],

          // Temperature
          _buildSliderRow(
            l10n.temperatureLabel,
            _temperature,
            (value) => setState(() => _temperature = value),
          ),

          const SizedBox(height: 24),

          // Save button
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConfig,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSaving ? l10n.saving : l10n.save),
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
              if (_saveMessage != null) ...[
                const SizedBox(width: 16),
                Text(
                  _saveMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        _saveMessage!.contains('Failed') ||
                            _saveMessage!.contains('失败')
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
  //  Section 2: Model Routes
  // ═══════════════════════════════════════════════════════════════

  Widget _buildModelRoutesSection() {
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
                  l10n.modelRoutesDesc,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addRoute),
                onPressed: () => _openRouteEditor(),
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

          if (_modelRoutes.isEmpty)
            _buildEmptyRoutesState(l10n)
          else
            ..._modelRoutes.map((route) => _buildRouteCard(route, l10n)),
        ],
      ),
    );
  }

  Widget _buildEmptyRoutesState(AppLocalizations l10n) {
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
          Icon(Icons.alt_route, size: 36, color: c.textHint),
          const SizedBox(height: 12),
          Text(
            l10n.noModelRoutes,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.noModelRoutesHint,
            style: TextStyle(fontSize: 12, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(
    routes_api.ModelRouteDto route,
    AppLocalizations l10n,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Row(
        children: [
          // Hint badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              route.hint,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Provider + Model
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${route.provider} / ${route.model}',
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (route.apiKey != null && route.apiKey!.isNotEmpty)
                  Text(
                    '${l10n.apiKeyLabel}: ••••',
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
              ],
            ),
          ),
          // Edit
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: c.textHint),
            tooltip: l10n.editRoute,
            onPressed: () => _openRouteEditor(existing: route),
            visualDensity: VisualDensity.compact,
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: l10n.delete,
            onPressed: () => _deleteRoute(route.hint),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Section 3: Embedding Configuration
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

  Widget _buildEditableModelRow() {
    final suggestions = _currentProvider.models;
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            AppLocalizations.of(context)!.modelLabel,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
        ),
        Expanded(
          child: Autocomplete<String>(
            initialValue: TextEditingValue(text: _modelController.text),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) return suggestions;
              return suggestions.where(
                (s) => s.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ),
              );
            },
            onSelected: (String selection) {
              _modelController.text = selection;
              setState(() => _selectedModel = selection);
            },
            fieldViewBuilder:
                (
                  BuildContext context,
                  TextEditingController fieldController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  if (fieldController.text != _modelController.text &&
                      !focusNode.hasFocus) {
                    fieldController.text = _modelController.text;
                  }
                  return TextField(
                    controller: fieldController,
                    focusNode: focusNode,
                    onChanged: (value) {
                      _modelController.text = value;
                      _selectedModel = value;
                    },
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.modelNameHint,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        padding: EdgeInsets.zero,
                        tooltip: AppLocalizations.of(context)!.showSuggestions,
                        onSelected: (value) {
                          fieldController.text = value;
                          _modelController.text = value;
                          setState(() => _selectedModel = value);
                        },
                        itemBuilder: (context) => suggestions
                            .map(
                              (s) => PopupMenuItem(
                                value: s,
                                child: Text(
                                  s,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: 400,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          title: Text(
                            option,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
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
//  Route Editor Dialog
// ═══════════════════════════════════════════════════════════════

class _RouteEditorDialog extends StatefulWidget {
  final List<config_api.ProviderInfo> providers;
  final routes_api.ModelRouteDto? existing;
  const _RouteEditorDialog({required this.providers, this.existing});

  @override
  State<_RouteEditorDialog> createState() => _RouteEditorDialogState();
}

class _RouteEditorDialogState extends State<_RouteEditorDialog> {
  late final TextEditingController _hintCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _apiKeyCtrl;
  late String _selectedProvider;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _hintCtrl = TextEditingController(text: e?.hint ?? '');
    _modelCtrl = TextEditingController(text: e?.model ?? '');
    _apiKeyCtrl = TextEditingController(text: e?.apiKey ?? '');
    _selectedProvider = e?.provider ?? 'openrouter';
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    _modelCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final hint = _hintCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    if (hint.isEmpty || model.isEmpty) return;

    final dto = routes_api.ModelRouteDto(
      hint: hint,
      provider: _selectedProvider,
      model: model,
      apiKey: _apiKeyCtrl.text.trim().isEmpty ? null : _apiKeyCtrl.text.trim(),
    );
    Navigator.pop(context, dto);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(_isEdit ? l10n.editRoute : l10n.addRoute),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hint
            TextField(
              controller: _hintCtrl,
              enabled: !_isEdit,
              decoration: InputDecoration(
                labelText: l10n.routeHint,
                hintText: l10n.routeHintHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Provider dropdown
            DropdownButtonFormField<String>(
              initialValue:
                  widget.providers.any((p) => p.id == _selectedProvider)
                  ? _selectedProvider
                  : widget.providers.first.id,
              decoration: InputDecoration(
                labelText: l10n.providerLabel,
                border: const OutlineInputBorder(),
              ),
              items: widget.providers
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedProvider = v);
              },
            ),
            const SizedBox(height: 12),

            // Model
            TextField(
              controller: _modelCtrl,
              decoration: InputDecoration(
                labelText: l10n.modelLabel,
                hintText: l10n.modelNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // API Key (optional)
            TextField(
              controller: _apiKeyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '${l10n.apiKeyLabel} (${l10n.agentOptional})',
                hintText: l10n.apiKeyHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
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
