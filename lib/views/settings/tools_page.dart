import 'dart:convert';

import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/src/rust/api/workspace_api.dart' as ws_api;
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tools & MCP management page — enable/disable tools and features with one click.
class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  ws_api.FeatureToggles? _features;
  List<ws_api.ToolInfo> _tools = [];

  bool _loading = true;
  bool _savingWebSearch = false;
  bool _savingWebFetch = false;
  bool _savingHttpRequest = false;
  bool _messageIsError = false;
  bool _showWebSearchApiKey = false;
  bool _showWebFetchApiKey = false;

  String? _message;
  String _webSearchProvider = 'duckduckgo';
  String _webFetchProvider = 'default';

  late final TextEditingController _webSearchApiKeyCtrl;
  late final TextEditingController _webSearchApiUrlCtrl;
  late final TextEditingController _webFetchApiKeyCtrl;
  late final TextEditingController _webFetchApiUrlCtrl;
  late final TextEditingController _webFetchAllowedDomainsCtrl;
  late final TextEditingController _webFetchBlockedDomainsCtrl;
  late final TextEditingController _httpRequestAllowedDomainsCtrl;

  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _webSearchApiKeyCtrl = TextEditingController();
    _webSearchApiUrlCtrl = TextEditingController();
    _webFetchApiKeyCtrl = TextEditingController();
    _webFetchApiUrlCtrl = TextEditingController();
    _webFetchAllowedDomainsCtrl = TextEditingController();
    _webFetchBlockedDomainsCtrl = TextEditingController();
    _httpRequestAllowedDomainsCtrl = TextEditingController();
    _loadAll();
  }

  @override
  void dispose() {
    _webSearchApiKeyCtrl.dispose();
    _webSearchApiUrlCtrl.dispose();
    _webFetchApiKeyCtrl.dispose();
    _webFetchApiUrlCtrl.dispose();
    _webFetchAllowedDomainsCtrl.dispose();
    _webFetchBlockedDomainsCtrl.dispose();
    _httpRequestAllowedDomainsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    try {
      final features = await ws_api.getFeatureToggles();
      final tools = await ws_api.listToolsWithStatus();
      final webSearchConfig = _decodeToolConfig(
        await ws_api.getToolConfig(toolName: 'web_search'),
        fallback: const {
          'enabled': false,
          'provider': 'duckduckgo',
          'api_key': '',
          'api_url': '',
        },
      );
      final webFetchConfig = _decodeToolConfig(
        await ws_api.getToolConfig(toolName: 'web_fetch'),
        fallback: const {
          'enabled': false,
          'provider': 'default',
          'api_key': '',
          'api_url': '',
          'allowed_domains': <String>[],
          'blocked_domains': <String>[],
        },
      );
      final httpRequestConfig = _decodeToolConfig(
        await ws_api.getToolConfig(toolName: 'http_request'),
        fallback: const {'enabled': false, 'allowed_domains': <String>[]},
      );

      if (!mounted) return;
      setState(() {
        _features = features;
        _tools = tools;
        _webSearchProvider = _normalizeWebSearchProvider(
          webSearchConfig['provider'] as String?,
        );
        _webFetchProvider = _normalizeWebFetchProvider(
          webFetchConfig['provider'] as String?,
        );
        _webSearchApiKeyCtrl.text =
            (webSearchConfig['api_key'] as String?) ?? '';
        _webSearchApiUrlCtrl.text =
            (webSearchConfig['api_url'] as String?) ?? '';
        _webFetchApiKeyCtrl.text = (webFetchConfig['api_key'] as String?) ?? '';
        _webFetchApiUrlCtrl.text = (webFetchConfig['api_url'] as String?) ?? '';
        _webFetchAllowedDomainsCtrl.text = _joinDomains(
          webFetchConfig['allowed_domains'],
        );
        _webFetchBlockedDomainsCtrl.text = _joinDomains(
          webFetchConfig['blocked_domains'],
        );
        _httpRequestAllowedDomainsCtrl.text = _joinDomains(
          httpRequestConfig['allowed_domains'],
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Map<String, dynamic> _decodeToolConfig(
    String raw, {
    required Map<String, dynamic> fallback,
  }) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return {...fallback, ...decoded};
      }
      if (decoded is Map) {
        return {...fallback, ...decoded.cast<String, dynamic>()};
      }
    } catch (_) {
      // Ignore invalid payloads and fall back to defaults.
    }
    return {...fallback};
  }

  String _joinDomains(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    return '';
  }

  List<String> _parseDomainList(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _normalizeWebSearchProvider(String? provider) {
    return switch (provider) {
      'duckduckgo' || 'brave' || 'searxng' => provider!,
      _ => 'duckduckgo',
    };
  }

  String _normalizeWebFetchProvider(String? provider) {
    return switch (provider) {
      'default' || 'firecrawl' => provider!,
      'fast_html2md' || 'nanohtml2text' => 'default',
      _ => 'default',
    };
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
      _showMessage(
        AppLocalizations.of(context)!.operationFailed,
        isError: true,
      );
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
      _showMessage(
        AppLocalizations.of(context)!.operationFailed,
        isError: true,
      );
    }
  }

  Future<void> _saveWebToolConfig(String toolName) async {
    final l10n = AppLocalizations.of(context)!;
    final isWebSearch = toolName == 'web_search';

    setState(() {
      if (isWebSearch) {
        _savingWebSearch = true;
      } else {
        _savingWebFetch = true;
      }
    });

    final result = await ws_api.saveToolConfig(
      toolName: toolName,
      configJson: jsonEncode({
        'enabled': isWebSearch
            ? (_features?.webSearchEnabled ?? false)
            : (_features?.webFetchEnabled ?? false),
        'provider': isWebSearch ? _webSearchProvider : _webFetchProvider,
        'api_key': _trimOrNull(
          isWebSearch ? _webSearchApiKeyCtrl.text : _webFetchApiKeyCtrl.text,
        ),
        'api_url': _trimOrNull(
          isWebSearch ? _webSearchApiUrlCtrl.text : _webFetchApiUrlCtrl.text,
        ),
        if (!isWebSearch)
          'allowed_domains': _parseDomainList(_webFetchAllowedDomainsCtrl.text),
        if (!isWebSearch)
          'blocked_domains': _parseDomainList(_webFetchBlockedDomainsCtrl.text),
      }),
    );

    if (!mounted) return;
    setState(() {
      if (isWebSearch) {
        _savingWebSearch = false;
      } else {
        _savingWebFetch = false;
      }
    });

    if (result == 'ok') {
      _showMessage(l10n.configSaved);
      _loadAll();
    } else {
      _showMessage(l10n.saveFailedWithError(result), isError: true);
    }
  }

  Future<void> _saveHttpRequestConfig() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _savingHttpRequest = true);

    final result = await ws_api.saveToolConfig(
      toolName: 'http_request',
      configJson: jsonEncode({
        'enabled': _features?.httpRequestEnabled ?? false,
        'allowed_domains': _parseDomainList(
          _httpRequestAllowedDomainsCtrl.text,
        ),
      }),
    );

    if (!mounted) return;
    setState(() => _savingHttpRequest = false);
    if (result == 'ok') {
      _showMessage(l10n.configSaved);
      _loadAll();
    } else {
      _showMessage(l10n.saveFailedWithError(result), isError: true);
    }
  }

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showMessage(String msg, {bool isError = false}) {
    setState(() {
      _message = msg;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.pageTools,
      icon: Icons.extension,
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureTogglesSection(),
          const SizedBox(height: 24),
          _buildToolConfigsSection(),
          const SizedBox(height: 24),
          _buildDomainPoliciesSection(),
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
              const SizedBox(width: 8),
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

  Widget _buildToolConfigsSection() {
    final l10n = AppLocalizations.of(context)!;

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
              const Icon(Icons.tune, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.providerConfiguration,
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
            l10n.toolsProviderSectionDesc,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final cardWidth = wide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildWebToolCard(
                      toolName: 'web_search',
                      title: l10n.featureWebSearch,
                      description: l10n.featureWebSearchDesc,
                      icon: Icons.search,
                      provider: _webSearchProvider,
                      providers: const [
                        _ToolProviderOption('duckduckgo', 'DuckDuckGo'),
                        _ToolProviderOption('brave', 'Brave'),
                        _ToolProviderOption('searxng', 'SearXNG'),
                      ],
                      apiKeyController: _webSearchApiKeyCtrl,
                      apiUrlController: _webSearchApiUrlCtrl,
                      saving: _savingWebSearch,
                      obscureApiKey: !_showWebSearchApiKey,
                      onToggleObscure: () {
                        setState(
                          () => _showWebSearchApiKey = !_showWebSearchApiKey,
                        );
                      },
                      onProviderChanged: (value) {
                        if (value == null) return;
                        setState(() => _webSearchProvider = value);
                      },
                      onSave: () => _saveWebToolConfig('web_search'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildWebToolCard(
                      toolName: 'web_fetch',
                      title: l10n.featureWebFetch,
                      description: l10n.featureWebFetchDesc,
                      icon: Icons.download,
                      provider: _webFetchProvider,
                      providers: [
                        _ToolProviderOption(
                          'default',
                          l10n.toolsDefaultFetcherLabel,
                        ),
                        const _ToolProviderOption('firecrawl', 'Firecrawl'),
                      ],
                      apiKeyController: _webFetchApiKeyCtrl,
                      apiUrlController: _webFetchApiUrlCtrl,
                      saving: _savingWebFetch,
                      obscureApiKey: !_showWebFetchApiKey,
                      onToggleObscure: () {
                        setState(
                          () => _showWebFetchApiKey = !_showWebFetchApiKey,
                        );
                      },
                      onProviderChanged: (value) {
                        if (value == null) return;
                        setState(() => _webFetchProvider = value);
                      },
                      onSave: () => _saveWebToolConfig('web_fetch'),
                      extraFields: [
                        TextField(
                          controller: _webFetchAllowedDomainsCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.toolsAllowedDomainsLabel,
                            hintText: l10n.toolsWebFetchAllowedDomainsHint,
                          ),
                          minLines: 1,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _webFetchBlockedDomainsCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.toolsBlockedDomainsLabel,
                            hintText: l10n.toolsWebFetchBlockedDomainsHint,
                          ),
                          minLines: 1,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDomainPoliciesSection() {
    final l10n = AppLocalizations.of(context)!;
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
                Icons.shield_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.toolsDomainPoliciesTitle,
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
            l10n.toolsDomainPoliciesDesc,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 16),
          _buildDomainPolicyCard(
            title: AppLocalizations.of(context)!.featureHttpRequest,
            description: AppLocalizations.of(context)!.featureHttpRequestDesc,
            icon: Icons.http,
            controller: _httpRequestAllowedDomainsCtrl,
            hintText: l10n.toolsHttpAllowedDomainsHint,
            saving: _savingHttpRequest,
            onSave: _saveHttpRequestConfig,
          ),
        ],
      ),
    );
  }

  bool _requiresApiKey(String toolName, String provider) {
    return switch (toolName) {
      'web_search' => provider == 'brave',
      'web_fetch' => provider == 'firecrawl',
      _ => false,
    };
  }

  bool _requiresApiUrl(String toolName, String provider) {
    return switch (toolName) {
      'web_search' => provider == 'searxng',
      _ => false,
    };
  }

  bool _showsApiUrlField(String toolName, String provider) {
    return switch (toolName) {
      'web_search' => provider == 'searxng',
      'web_fetch' => provider == 'firecrawl',
      _ => false,
    };
  }

  Widget _buildWebToolCard({
    required String toolName,
    required String title,
    required String description,
    required IconData icon,
    required String provider,
    required List<_ToolProviderOption> providers,
    required TextEditingController apiKeyController,
    required TextEditingController apiUrlController,
    required bool saving,
    required bool obscureApiKey,
    required VoidCallback onToggleObscure,
    required ValueChanged<String?> onProviderChanged,
    required VoidCallback onSave,
    List<Widget> extraFields = const [],
  }) {
    final l10n = AppLocalizations.of(context)!;
    final requiresApiKey = _requiresApiKey(toolName, provider);
    final requiresApiUrl = _requiresApiUrl(toolName, provider);
    final showApiUrlField = _showsApiUrlField(toolName, provider);
    final hasApiKey = apiKeyController.text.trim().isNotEmpty;
    final hasApiUrl = apiUrlController.text.trim().isNotEmpty;
    final configured =
        (!requiresApiKey || hasApiKey) && (!requiresApiUrl || hasApiUrl);
    final needsCredentials =
        requiresApiKey || requiresApiUrl || showApiUrlField;
    final statusText = needsCredentials
        ? (configured ? l10n.configured : l10n.missing)
        : l10n.toolsNoExtraCredentials;
    final statusColor = needsCredentials
        ? (configured ? AppColors.success : AppColors.warning)
        : c.textHint;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('$toolName:$provider'),
            initialValue: provider,
            decoration: InputDecoration(labelText: l10n.providerLabel),
            items: providers
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.value,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: onProviderChanged,
          ),
          if (requiresApiKey) ...[
            const SizedBox(height: 12),
            TextField(
              controller: apiKeyController,
              obscureText: obscureApiKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.apiKeyLabel,
                hintText: l10n.apiKeyHint,
                suffixIcon: IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
          ],
          if (showApiUrlField) ...[
            const SizedBox(height: 12),
            TextField(
              controller: apiUrlController,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: requiresApiUrl
                    ? l10n.apiBaseUrlLabel
                    : '${l10n.apiBaseUrlLabel} (${l10n.agentOptional})',
                hintText: _apiUrlHint(provider),
              ),
            ),
          ],
          if (!requiresApiKey && !showApiUrlField) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.inputBorder),
              ),
              child: Text(
                l10n.toolsNoExtraCredentials,
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ),
          ],
          if (extraFields.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...extraFields,
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(saving ? l10n.saving : l10n.save),
            ),
          ),
        ],
      ),
    );
  }

  String _apiUrlHint(String provider) {
    return switch (provider) {
      'firecrawl' => 'https://api.firecrawl.dev',
      'searxng' => 'https://search.example.com',
      _ => '',
    };
  }

  Widget _buildToolsSection() {
    if (_tools.isEmpty) return const SizedBox.shrink();

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
                AppLocalizations.of(
                  context,
                )!.toolsBuiltInSummary(_tools.length),
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

  Widget _buildDomainPolicyCard({
    required String title,
    required String description,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    required bool saving,
    required VoidCallback onSave,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.toolsAllowedDomainsLabel,
              hintText: hintText,
            ),
            minLines: 1,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(saving ? l10n.saving : l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolProviderOption {
  final String value;
  final String label;

  const _ToolProviderOption(this.value, this.label);
}
