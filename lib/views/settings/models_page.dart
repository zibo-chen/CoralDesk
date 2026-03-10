import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/routes_api.dart' as routes_api;
import 'package:coraldesk/src/rust/api/providers_api.dart' as providers_api;
import 'package:coraldesk/src/rust/api/config_api.dart' as config_api;
import 'package:coraldesk/src/rust/api/copilot_api.dart' as copilot_api;
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
          // Description + action buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.providerProfilesDesc,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              // Import button
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.importConfig),
                onPressed: _importConfig,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Export button
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: Text(l10n.exportConfig),
                onPressed: _exportConfig,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
  //  Import / Export
  // ═══════════════════════════════════════════════════════════════

  /// Serialize provider profiles + embedding config to TOML, base64-encode,
  /// and copy to clipboard.
  Future<void> _exportConfig() async {
    final l10n = AppLocalizations.of(context)!;
    if (_providerProfiles.isEmpty && _embeddingProvider == 'none') {
      _showSnack(l10n.configExportEmpty, isError: true);
      return;
    }

    final buf = StringBuffer();
    buf.writeln('# DeskClaw Model Configuration');
    buf.writeln('# Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln();
    if (_defaultProfileId.isNotEmpty) {
      buf.writeln('default_profile = "${_escapeToml(_defaultProfileId)}"');
      buf.writeln();
    }

    // ── Provider profiles ──
    for (final p in _providerProfiles) {
      buf.writeln('[model_providers.${_escapeTomlKey(p.id)}]');
      if (p.name != null && p.name!.isNotEmpty) {
        buf.writeln('name = "${_escapeToml(p.name!)}"');
      }
      if (p.baseUrl != null && p.baseUrl!.isNotEmpty) {
        buf.writeln('base_url = "${_escapeToml(p.baseUrl!)}"');
      }
      if (p.wireApi != null && p.wireApi!.isNotEmpty) {
        buf.writeln('wire_api = "${_escapeToml(p.wireApi!)}"');
      }
      if (p.defaultModel != null && p.defaultModel!.isNotEmpty) {
        buf.writeln('default_model = "${_escapeToml(p.defaultModel!)}"');
      }
      if (p.apiKey != null && p.apiKey!.isNotEmpty) {
        buf.writeln('api_key = "${_escapeToml(p.apiKey!)}"');
      }
      buf.writeln();
    }

    // ── Embedding configuration ──
    buf.writeln('[embedding]');
    buf.writeln('provider = "${_escapeToml(_embeddingProvider)}"');
    buf.writeln('model = "${_escapeToml(_embeddingModelCtrl.text.trim())}"');
    buf.writeln(
      'dimensions = ${int.tryParse(_embeddingDimsCtrl.text.trim()) ?? 1536}',
    );
    buf.writeln('vector_weight = ${_vectorWeight.toStringAsFixed(2)}');
    buf.writeln('keyword_weight = ${_keywordWeight.toStringAsFixed(2)}');
    buf.writeln(
      'min_relevance_score = ${_minRelevanceScore.toStringAsFixed(2)}',
    );
    if (_embeddingBaseUrlCtrl.text.trim().isNotEmpty) {
      buf.writeln(
        'base_url = "${_escapeToml(_embeddingBaseUrlCtrl.text.trim())}"',
      );
    }
    if (_embeddingApiKeyCtrl.text.trim().isNotEmpty) {
      buf.writeln(
        'api_key = "${_escapeToml(_embeddingApiKeyCtrl.text.trim())}"',
      );
    }
    buf.writeln();

    final tomlStr = buf.toString();
    final b64 = base64Encode(utf8.encode(tomlStr));
    await Clipboard.setData(ClipboardData(text: b64));
    if (mounted) _showSnack(l10n.configExportedToClipboard);
  }

  /// Read base64-encoded TOML from clipboard, parse, and import profiles.
  Future<void> _importConfig() async {
    final l10n = AppLocalizations.of(context)!;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      _showSnack(l10n.clipboardEmpty, isError: true);
      return;
    }

    // Decode base64
    String tomlStr;
    try {
      tomlStr = utf8.decode(base64Decode(data.text!.trim()));
    } catch (_) {
      _showSnack(l10n.configImportFailed, isError: true);
      return;
    }

    // Parse the TOML into profiles + embedding config
    final parsed = _parseTomlProfiles(tomlStr);
    if (parsed.profiles.isEmpty && parsed.embedding == null) {
      _showSnack(l10n.configImportFailed, isError: true);
      return;
    }

    // Build confirmation message showing what will be imported
    final itemCount =
        parsed.profiles.length + (parsed.embedding != null ? 1 : 0);

    // Confirm with user
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.configImportConfirmTitle),
        content: Text(l10n.configImportConfirmMessage(itemCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.importConfig),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Upsert all profiles
    for (final profile in parsed.profiles) {
      await providers_api.upsertModelProviderProfile(profile: profile);
    }

    // Set default profile if specified
    if (parsed.defaultProfileId != null &&
        parsed.defaultProfileId!.isNotEmpty) {
      await providers_api.setDefaultProfile(id: parsed.defaultProfileId!);
      if (mounted) {
        setState(() => _defaultProfileId = parsed.defaultProfileId!);
      }
    }

    // Restore embedding configuration
    if (parsed.embedding != null) {
      await routes_api.updateEmbeddingConfig(config: parsed.embedding!);
      if (mounted) {
        final e = parsed.embedding!;
        setState(() {
          _embeddingProvider = e.embeddingProvider;
          _embeddingModelCtrl.text = e.embeddingModel;
          _embeddingDimsCtrl.text = e.embeddingDimensions.toString();
          _embeddingBaseUrlCtrl.text = e.embeddingBaseUrl ?? '';
          _embeddingApiKeyCtrl.text = e.embeddingApiKey ?? '';
          _vectorWeight = e.vectorWeight;
          _keywordWeight = e.keywordWeight;
          _minRelevanceScore = e.minRelevanceScore;
        });
      }
    }

    if (!mounted) return;
    await _refreshProfiles();
    _showSnack(l10n.configImportSuccess);
  }

  /// Escape a string value for TOML (handle backslash, quotes, newlines).
  String _escapeToml(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Escape a TOML key (bare keys allow [A-Za-z0-9_-]).
  String _escapeTomlKey(String s) {
    if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(s)) return s;
    return '"${_escapeToml(s)}"';
  }

  /// Simple TOML parser for the export format we produce.
  _ParsedConfig _parseTomlProfiles(String toml) {
    final profiles = <providers_api.ModelProviderProfileDto>[];
    String? defaultProfileId;

    // Current provider profile fields
    String? currentId;
    String? name;
    String? baseUrl;
    String? wireApi;
    String? defaultModel;
    String? apiKey;

    // Embedding fields
    bool inEmbeddingSection = false;
    String? embProvider;
    String? embModel;
    int? embDimensions;
    double? embVectorWeight;
    double? embKeywordWeight;
    double? embMinRelevance;
    String? embBaseUrl;
    String? embApiKey;

    void flushCurrent() {
      if (currentId != null) {
        profiles.add(
          providers_api.ModelProviderProfileDto(
            id: currentId!,
            name: name,
            baseUrl: baseUrl,
            wireApi: wireApi,
            defaultModel: defaultModel,
            apiKey: apiKey,
          ),
        );
      }
      currentId = null;
      name = null;
      baseUrl = null;
      wireApi = null;
      defaultModel = null;
      apiKey = null;
      inEmbeddingSection = false;
    }

    for (var line in toml.split('\n')) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      // Section header: [embedding]
      if (line == '[embedding]') {
        flushCurrent();
        inEmbeddingSection = true;
        continue;
      }

      // Section header: [model_providers.xxx]
      final sectionMatch = RegExp(
        r'^\[model_providers\.("(?:[^"\\]|\\.)*"|[A-Za-z0-9_-]+)\]$',
      ).firstMatch(line);
      if (sectionMatch != null) {
        flushCurrent();
        var id = sectionMatch.group(1)!;
        if (id.startsWith('"') && id.endsWith('"')) {
          id = _unescapeToml(id.substring(1, id.length - 1));
        }
        currentId = id;
        continue;
      }

      // Key = "string_value" pairs
      final kvStrMatch = RegExp(
        r'^(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"$',
      ).firstMatch(line);
      // Key = number pairs (int or float)
      final kvNumMatch = RegExp(
        r'^(\w+)\s*=\s*([0-9]+(?:\.[0-9]+)?)$',
      ).firstMatch(line);

      if (inEmbeddingSection) {
        // Parse embedding section keys
        if (kvStrMatch != null) {
          final key = kvStrMatch.group(1)!;
          final value = _unescapeToml(kvStrMatch.group(2)!);
          switch (key) {
            case 'provider':
              embProvider = value;
            case 'model':
              embModel = value;
            case 'base_url':
              embBaseUrl = value;
            case 'api_key':
              embApiKey = value;
          }
        } else if (kvNumMatch != null) {
          final key = kvNumMatch.group(1)!;
          final numStr = kvNumMatch.group(2)!;
          switch (key) {
            case 'dimensions':
              embDimensions = int.tryParse(numStr);
            case 'vector_weight':
              embVectorWeight = double.tryParse(numStr);
            case 'keyword_weight':
              embKeywordWeight = double.tryParse(numStr);
            case 'min_relevance_score':
              embMinRelevance = double.tryParse(numStr);
          }
        }
        continue;
      }

      if (kvStrMatch != null) {
        final key = kvStrMatch.group(1)!;
        final value = _unescapeToml(kvStrMatch.group(2)!);

        // Top-level key (before any section)
        if (currentId == null) {
          if (key == 'default_profile') defaultProfileId = value;
          continue;
        }

        switch (key) {
          case 'name':
            name = value;
          case 'base_url':
            baseUrl = value;
          case 'wire_api':
            wireApi = value;
          case 'default_model':
            defaultModel = value;
          case 'api_key':
            apiKey = value;
        }
      }
    }
    flushCurrent();

    // Build embedding config if we found an [embedding] section
    routes_api.EmbeddingConfigDto? embedding;
    if (embProvider != null) {
      embedding = routes_api.EmbeddingConfigDto(
        embeddingProvider: embProvider,
        embeddingModel: embModel ?? '',
        embeddingDimensions: embDimensions ?? 1536,
        vectorWeight: embVectorWeight ?? 0.7,
        keywordWeight: embKeywordWeight ?? 0.3,
        minRelevanceScore: embMinRelevance ?? 0.4,
        embeddingBaseUrl: embBaseUrl,
        embeddingApiKey: embApiKey,
      );
    }

    return _ParsedConfig(
      profiles: profiles,
      defaultProfileId: defaultProfileId,
      embedding: embedding,
    );
  }

  /// Unescape a TOML string value.
  String _unescapeToml(String s) {
    return s
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\r')
        .replaceAll('\\t', '\t')
        .replaceAll('\\"', '"')
        .replaceAll('\\\\', '\\');
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

  // Copilot OAuth state
  bool _copilotAuthChecking = false;
  bool _copilotAuthenticated = false;
  String? _copilotUsername;

  List<String> get _providerOptions {
    final ids = widget.availableProviders.map((p) => p.id).toSet().toList()
      ..sort();
    return ids;
  }

  bool get _isCustomProvider => _selectedProvider == _customProviderOption;
  bool get _isCopilotProvider => _selectedProvider == 'copilot';

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

    // Check Copilot auth status if editing a copilot profile
    if (_isCopilotProvider) {
      _checkCopilotStatus();
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

  Future<void> _checkCopilotStatus() async {
    setState(() => _copilotAuthChecking = true);
    try {
      final status = await copilot_api.copilotCheckStatus();
      if (!mounted) return;
      setState(() {
        _copilotAuthenticated = status.authenticated;
        _copilotUsername = status.username;
        _copilotAuthChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _copilotAuthChecking = false);
    }
  }

  Future<void> _startCopilotOAuth() async {
    final l10n = AppLocalizations.of(context)!;

    // Start device flow
    final flowInfo = await copilot_api.copilotStartDeviceFlow();
    if (flowInfo.deviceCode.startsWith('error:')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.copilotAuthFailed(flowInfo.deviceCode.substring(6)),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;

    // Show device code dialog
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CopilotDeviceCodeDialog(
        userCode: flowInfo.userCode,
        verificationUri: flowInfo.verificationUri,
        deviceCode: flowInfo.deviceCode,
        interval: flowInfo.interval.toInt(),
        expiresIn: flowInfo.expiresIn.toInt(),
      ),
    );

    if (success == true && mounted) {
      _checkCopilotStatus();
    }
  }

  Future<void> _copilotSignOut() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.copilotSignOut),
        content: Text(l10n.copilotSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.copilotSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await copilot_api.copilotLogout();
    if (!mounted) return;
    setState(() {
      _copilotAuthenticated = false;
      _copilotUsername = null;
    });
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
      // Auto-set defaults for Copilot
      if (_isCopilotProvider) {
        _nameCtrl.text = 'copilot';
        if (_idCtrl.text.trim().isEmpty) {
          _idCtrl.text = 'copilot';
        }
        if (_modelCtrl.text.trim().isEmpty) {
          _modelCtrl.text = 'gpt-4o';
        }
        _checkCopilotStatus();
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

          // ── Connection (hidden for Copilot) ──
          if (!_isCopilotProvider)
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
                            (o) => DropdownMenuItem(
                              value: o.$1,
                              child: Text(o.$2),
                            ),
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

          // ── Copilot Authentication ──
          if (_isCopilotProvider) _buildCopilotAuthSection(l10n),

          // ── Model & Auth ──
          DialogSection(
            title: _isCopilotProvider ? 'MODEL' : 'MODEL & AUTH',
            icon: Icons.vpn_key_outlined,
            children: [
              if (_isCopilotProvider)
                // For Copilot: model selector only (no API key)
                FieldColumn(
                  child: TextField(
                    controller: _modelCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.providerProfileModel,
                      hintText: 'gpt-4o',
                    ),
                  ),
                )
              else
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
                        labelText:
                            '${l10n.apiKeyLabel} (${l10n.agentOptional})',
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

  Widget _buildCopilotAuthSection(AppLocalizations l10n) {
    final c = CoralDeskColors.of(context);
    return DialogSection(
      title: 'GITHUB COPILOT',
      icon: Icons.security_outlined,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surfaceBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.chatListBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              Text(
                l10n.copilotOAuthDesc,
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.copilotRequiresSubscription,
                style: TextStyle(
                  fontSize: 12,
                  color: c.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Auth status
              if (_copilotAuthChecking)
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.copilotCheckingStatus,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                )
              else ...[
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _copilotAuthenticated
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _copilotAuthenticated
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _copilotAuthenticated
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        size: 18,
                        color: _copilotAuthenticated
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _copilotAuthenticated
                              ? (_copilotUsername != null
                                    ? l10n.copilotAuthenticatedAs(
                                        _copilotUsername!,
                                      )
                                    : l10n.copilotAuthenticated)
                              : l10n.copilotNotAuthenticated,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _copilotAuthenticated
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    if (!_copilotAuthenticated)
                      FilledButton.icon(
                        icon: const Icon(Icons.login, size: 18),
                        label: Text(l10n.copilotSignIn),
                        onPressed: _startCopilotOAuth,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                      )
                    else ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(
                          l10n.copilotCheckingStatus.replaceAll('...', ''),
                        ),
                        onPressed: _checkCopilotStatus,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(l10n.copilotSignOut),
                        onPressed: _copilotSignOut,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Copilot Device Code Dialog
// ═══════════════════════════════════════════════════════════════

class _CopilotDeviceCodeDialog extends StatefulWidget {
  final String userCode;
  final String verificationUri;
  final String deviceCode;
  final int interval;
  final int expiresIn;

  const _CopilotDeviceCodeDialog({
    required this.userCode,
    required this.verificationUri,
    required this.deviceCode,
    required this.interval,
    required this.expiresIn,
  });

  @override
  State<_CopilotDeviceCodeDialog> createState() =>
      _CopilotDeviceCodeDialogState();
}

class _CopilotDeviceCodeDialogState extends State<_CopilotDeviceCodeDialog> {
  bool _polling = true;
  String? _error;
  String? _username;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _startPolling() async {
    final deadline = DateTime.now().add(Duration(seconds: widget.expiresIn));
    var intervalSeconds = widget.interval;

    while (mounted && _polling && DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: intervalSeconds));
      if (!mounted || !_polling) break;

      try {
        final result = await copilot_api.copilotPollAuthorization(
          deviceCode: widget.deviceCode,
        );

        if (!mounted) break;

        switch (result.status) {
          case 'success':
            setState(() {
              _success = true;
              _polling = false;
              _username = result.username;
            });
            // Auto-close after a brief delay
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) Navigator.pop(context, true);
            return;
          case 'pending':
            // Continue polling
            break;
          case 'slow_down':
            intervalSeconds += 5;
            break;
          case 'expired':
            setState(() {
              _polling = false;
              _error = AppLocalizations.of(context)!.copilotAuthExpired;
            });
            return;
          default:
            if (result.status.startsWith('error:')) {
              setState(() {
                _polling = false;
                _error = result.status.substring(6);
              });
              return;
            }
        }
      } catch (e) {
        if (!mounted) break;
        setState(() {
          _polling = false;
          _error = e.toString();
        });
        return;
      }
    }

    // Timed out
    if (mounted && _polling) {
      setState(() {
        _polling = false;
        _error = AppLocalizations.of(context)!.copilotAuthExpired;
      });
    }
  }

  @override
  void dispose() {
    _polling = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = CoralDeskColors.of(context);

    return Dialog(
      backgroundColor: c.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GitHub icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.surfaceBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.chatListBorder),
                ),
                child: Icon(
                  Icons.code,
                  size: 28,
                  color: _success ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),

              if (_success) ...[
                // Success state
                Icon(Icons.check_circle, size: 48, color: AppColors.success),
                const SizedBox(height: 12),
                Text(
                  l10n.copilotAuthSuccess,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_username != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.copilotAuthenticatedAs(_username!),
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                  ),
                ],
              ] else if (_error != null) ...[
                // Error state
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  l10n.copilotAuthFailed(_error!),
                  style: TextStyle(fontSize: 14, color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
              ] else ...[
                // Waiting state — show device code
                Text(
                  l10n.copilotDeviceCodeTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.copilotDeviceCodeDesc,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // User code display
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.userCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.copilotDeviceCodeCopied),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.userCode,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 4,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.copy,
                          size: 20,
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.copilotCopyCode,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
                const SizedBox(height: 20),

                // Open browser button
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: Text(l10n.copilotOpenBrowser),
                  onPressed: () {
                    // Copy code to clipboard automatically
                    Clipboard.setData(ClipboardData(text: widget.userCode));
                    launchUrl(Uri.parse(widget.verificationUri));
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // URL display
                Text(
                  widget.verificationUri,
                  style: TextStyle(fontSize: 12, color: c.textHint),
                ),
                const SizedBox(height: 20),

                // Polling indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.copilotWaitingAuth,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _polling = false;
                    Navigator.pop(context, false);
                  },
                  child: Text(l10n.cancel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper class for parsed import data.
class _ParsedConfig {
  final List<providers_api.ModelProviderProfileDto> profiles;
  final String? defaultProfileId;
  final routes_api.EmbeddingConfigDto? embedding;
  const _ParsedConfig({
    required this.profiles,
    this.defaultProfileId,
    this.embedding,
  });
}
