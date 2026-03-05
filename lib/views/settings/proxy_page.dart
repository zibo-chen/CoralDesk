import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/proxy_api.dart' as proxy_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

/// Proxy settings page — configure global outbound proxy
class ProxyPage extends ConsumerStatefulWidget {
  const ProxyPage({super.key});

  @override
  ConsumerState<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends ConsumerState<ProxyPage> {
  bool _enabled = false;
  proxy_api.ProxyScopeDto _scope = proxy_api.ProxyScopeDto.zeroclaw;
  final TextEditingController _httpProxyController = TextEditingController();
  final TextEditingController _httpsProxyController = TextEditingController();
  final TextEditingController _allProxyController = TextEditingController();
  final TextEditingController _noProxyController = TextEditingController();
  final TextEditingController _servicesController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _saveQueued = false;
  bool _isResetting = false;
  Timer? _autoSaveTimer;
  String? _httpError;
  String? _httpsError;
  String? _allError;
  CoralDeskColors get c => CoralDeskColors.of(context);

  /// Get localized display name for a service key
  String _getLocalizedServiceName(String key, AppLocalizations l10n) {
    // Handle wildcard selectors
    switch (key) {
      case 'provider.*':
        return l10n.proxyServiceWildcardProvider;
      case 'channel.*':
        return l10n.proxyServiceWildcardChannel;
      case 'tool.*':
        return l10n.proxyServiceWildcardTool;
      case 'memory.*':
        return l10n.proxyServiceWildcardMemory;
      case 'tunnel.*':
        return l10n.proxyServiceWildcardTunnel;
      case 'transcription.*':
        return l10n.proxyServiceWildcardTranscription;
      // Provider keys
      case 'provider.anthropic':
        return l10n.proxyServiceProviderAnthropic;
      case 'provider.compatible':
        return l10n.proxyServiceProviderCompatible;
      case 'provider.copilot':
        return l10n.proxyServiceProviderCopilot;
      case 'provider.gemini':
        return l10n.proxyServiceProviderGemini;
      case 'provider.glm':
        return l10n.proxyServiceProviderGlm;
      case 'provider.ollama':
        return l10n.proxyServiceProviderOllama;
      case 'provider.openai':
        return l10n.proxyServiceProviderOpenai;
      case 'provider.openrouter':
        return l10n.proxyServiceProviderOpenrouter;
      // Channel keys
      case 'channel.bluebubbles':
        return l10n.proxyServiceChannelBluebubbles;
      case 'channel.dingtalk':
        return l10n.proxyServiceChannelDingtalk;
      case 'channel.discord':
        return l10n.proxyServiceChannelDiscord;
      case 'channel.feishu':
        return l10n.proxyServiceChannelFeishu;
      case 'channel.github':
        return l10n.proxyServiceChannelGithub;
      case 'channel.lark':
        return l10n.proxyServiceChannelLark;
      case 'channel.matrix':
        return l10n.proxyServiceChannelMatrix;
      case 'channel.mattermost':
        return l10n.proxyServiceChannelMattermost;
      case 'channel.nextcloud_talk':
        return l10n.proxyServiceChannelNextcloudTalk;
      case 'channel.napcat':
        return l10n.proxyServiceChannelNapcat;
      case 'channel.qq':
        return l10n.proxyServiceChannelQq;
      case 'channel.signal':
        return l10n.proxyServiceChannelSignal;
      case 'channel.slack':
        return l10n.proxyServiceChannelSlack;
      case 'channel.telegram':
        return l10n.proxyServiceChannelTelegram;
      case 'channel.wati':
        return l10n.proxyServiceChannelWati;
      case 'channel.whatsapp':
        return l10n.proxyServiceChannelWhatsapp;
      // Tool keys
      case 'tool.browser':
        return l10n.proxyServiceToolBrowser;
      case 'tool.composio':
        return l10n.proxyServiceToolComposio;
      case 'tool.http_request':
        return l10n.proxyServiceToolHttpRequest;
      case 'tool.multimodal':
        return l10n.proxyServiceToolMultimodal;
      case 'tool.pushover':
        return l10n.proxyServiceToolPushover;
      // Memory keys
      case 'memory.embeddings':
        return l10n.proxyServiceMemoryEmbeddings;
      // Tunnel keys
      case 'tunnel.custom':
        return l10n.proxyServiceTunnelCustom;
      // Transcription keys
      case 'transcription.groq':
        return l10n.proxyServiceTranscriptionGroq;
      default:
        return key; // Fallback to key if no translation
    }
  }

  /// Get localized category name
  String _getLocalizedCategoryName(String category, AppLocalizations l10n) {
    switch (category) {
      case 'provider':
        return l10n.proxyServiceCategoryProvider;
      case 'channel':
        return l10n.proxyServiceCategoryChannel;
      case 'tool':
        return l10n.proxyServiceCategoryTool;
      case 'memory':
        return l10n.proxyServiceCategoryMemory;
      case 'tunnel':
        return l10n.proxyServiceCategoryTunnel;
      case 'transcription':
        return l10n.proxyServiceCategoryTranscription;
      default:
        return category.toUpperCase();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _httpProxyController.dispose();
    _httpsProxyController.dispose();
    _allProxyController.dispose();
    _noProxyController.dispose();
    _servicesController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await proxy_api.getProxyConfig();
    if (!mounted) return;
    setState(() {
      _enabled = config.enabled;
      _scope = config.scope;
      _httpProxyController.text = config.httpProxy;
      _httpsProxyController.text = config.httpsProxy;
      _allProxyController.text = config.allProxy;
      _noProxyController.text = config.noProxy;
      _servicesController.text = config.services;
      _isLoading = false;
    });
  }

  void _scheduleAutoSave({bool immediate = false}) {
    if (_isLoading) return;

    _autoSaveTimer?.cancel();
    if (immediate) {
      unawaited(_saveConfig());
      return;
    }

    _autoSaveTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_saveConfig());
    });
  }

  String? _validateUrl(String url) {
    if (url.trim().isEmpty) return null;
    final result = proxy_api.validateProxyUrl(url: url);
    if (result == 'ok') return null;
    return result.replaceFirst('error: ', '');
  }

  Future<void> _saveConfig() async {
    if (_isSaving) {
      _saveQueued = true;
      return;
    }

    // Validate URLs first
    final httpErr = _enabled ? _validateUrl(_httpProxyController.text) : null;
    final httpsErr = _enabled ? _validateUrl(_httpsProxyController.text) : null;
    final allErr = _enabled ? _validateUrl(_allProxyController.text) : null;
    setState(() {
      _httpError = httpErr;
      _httpsError = httpsErr;
      _allError = allErr;
    });
    if (httpErr != null || httpsErr != null || allErr != null) return;

    setState(() {
      _isSaving = true;
    });

    final dto = proxy_api.ProxyConfigDto(
      enabled: _enabled,
      httpProxy: _httpProxyController.text.trim(),
      httpsProxy: _httpsProxyController.text.trim(),
      allProxy: _allProxyController.text.trim(),
      noProxy: _noProxyController.text.trim(),
      scope: _scope,
      services: _servicesController.text.trim(),
    );

    // Apply to runtime
    final updateResult = await proxy_api.updateProxyConfig(config: dto);
    if (updateResult != 'ok') {
      setState(() {
        _isSaving = false;
      });
      if (_saveQueued) {
        _saveQueued = false;
        _scheduleAutoSave(immediate: true);
      }
      return;
    }

    // Persist to disk
    await proxy_api.saveProxyToDisk();
    setState(() {
      _isSaving = false;
    });

    if (_saveQueued) {
      _saveQueued = false;
      _scheduleAutoSave(immediate: true);
    }
  }

  Future<void> _resetProxy() async {
    final l10n = AppLocalizations.of(context)!;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.proxyResetConfirmTitle),
        content: Text(l10n.proxyResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.proxyResetButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isResetting = true;
    });

    final result = await proxy_api.resetProxyConfig();

    if (!mounted) return;

    if (result == 'ok') {
      // Clear all local state
      setState(() {
        _enabled = false;
        _scope = proxy_api.ProxyScopeDto.zeroclaw;
        _httpProxyController.clear();
        _httpsProxyController.clear();
        _allProxyController.clear();
        _noProxyController.clear();
        _servicesController.clear();
        _httpError = null;
        _httpsError = null;
        _allError = null;
        _isResetting = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.proxyResetSuccess)));
    } else {
      setState(() {
        _isResetting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsScaffold(
      title: l10n.proxyPageTitle,
      icon: Icons.vpn_key,
      isLoading: _isLoading,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainSection(l10n),
          const SizedBox(height: 24),
          _buildScopeSection(l10n),
          if (_scope == proxy_api.ProxyScopeDto.services) ...[
            const SizedBox(height: 24),
            _buildServicesSection(l10n),
          ],
          const SizedBox(height: 24),
          _buildNoProxySection(l10n),
        ],
      ),
    );
  }

  Widget _buildMainSection(AppLocalizations l10n) {
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
          // Enable toggle with reset button
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.proxyConfiguration,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              // Reset button
              TextButton.icon(
                onPressed: _isResetting ? null : _resetProxy,
                icon: _isResetting
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.textHint,
                        ),
                      )
                    : Icon(Icons.refresh, size: 14, color: c.textHint),
                label: Text(
                  l10n.proxyResetButton,
                  style: TextStyle(fontSize: 12, color: c.textHint),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _enabled,
                activeTrackColor: AppColors.primary,
                onChanged: (v) {
                  setState(() => _enabled = v);
                  _scheduleAutoSave(immediate: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.proxyDescription,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 20),

          // All Proxy (most common use case — shown first)
          _buildUrlField(
            label: l10n.proxyAllProxy,
            hint: 'socks5://127.0.0.1:1080',
            controller: _allProxyController,
            error: _allError,
            helpText: l10n.proxyAllProxyHelp,
            onChanged: (value) => _scheduleAutoSave(),
          ),
          const SizedBox(height: 16),

          // HTTP Proxy
          _buildUrlField(
            label: l10n.proxyHttpProxy,
            hint: 'http://127.0.0.1:8080',
            controller: _httpProxyController,
            error: _httpError,
            helpText: l10n.proxyHttpProxyHelp,
            onChanged: (value) => _scheduleAutoSave(),
          ),
          const SizedBox(height: 16),

          // HTTPS Proxy
          _buildUrlField(
            label: l10n.proxyHttpsProxy,
            hint: 'http://127.0.0.1:8080',
            controller: _httpsProxyController,
            error: _httpsError,
            helpText: l10n.proxyHttpsProxyHelp,
            onChanged: (value) => _scheduleAutoSave(),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? error,
    String? helpText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: c.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(height: 2),
          Text(helpText, style: TextStyle(fontSize: 11, color: c.textHint)),
        ],
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 13, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: c.textHint),
            filled: true,
            fillColor: c.inputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.chatListBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.chatListBorder),
            ),
            errorText: error,
            errorMaxLines: 2,
          ),
          onChanged: (value) {
            if (_httpError != null ||
                _httpsError != null ||
                _allError != null) {
              setState(() {
                _httpError = null;
                _httpsError = null;
                _allError = null;
              });
            }

            onChanged?.call(value);
          },
        ),
      ],
    );
  }

  Widget _buildScopeSection(AppLocalizations l10n) {
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
          Text(
            l10n.proxyScope,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.proxyScopeDescription,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildScopeChip(
                proxy_api.ProxyScopeDto.zeroclaw,
                l10n.proxyScopeZeroclaw,
                Icons.bolt,
                l10n.proxyScopeZeroclawDesc,
              ),
              const SizedBox(width: 8),
              _buildScopeChip(
                proxy_api.ProxyScopeDto.services,
                l10n.proxyScopeServices,
                Icons.tune,
                l10n.proxyScopeServicesDesc,
              ),
              const SizedBox(width: 8),
              _buildScopeChip(
                proxy_api.ProxyScopeDto.environment,
                l10n.proxyScopeEnvironment,
                Icons.terminal,
                l10n.proxyScopeEnvironmentDesc,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(
    proxy_api.ProxyScopeDto value,
    String label,
    IconData icon,
    String description,
  ) {
    final isSelected = _scope == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _scope = value);
          _scheduleAutoSave(immediate: true);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? AppColors.primary : c.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: c.textHint),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection(AppLocalizations l10n) {
    final services = proxy_api.listProxyServices();
    // Group by category
    final grouped = <String, List<proxy_api.ProxyServiceInfo>>{};
    for (final s in services) {
      grouped.putIfAbsent(s.category, () => []).add(s);
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
          Text(
            l10n.proxyServiceSelectors,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.proxyServiceSelectorsHelp,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _servicesController,
            style: TextStyle(fontSize: 13, color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'provider.*, channel.telegram',
              hintStyle: TextStyle(fontSize: 13, color: c.textHint),
              filled: true,
              fillColor: c.inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.chatListBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.chatListBorder),
              ),
            ),
            onChanged: (_) => _scheduleAutoSave(),
          ),
          const SizedBox(height: 12),
          // Quick-select chips grouped by category
          ...grouped.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getLocalizedCategoryName(entry.key, l10n),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.textHint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: entry.value.map((s) {
                      final current = _servicesController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toSet();
                      final isActive = current.contains(s.key);
                      return Tooltip(
                        message: s.key, // Show original key on hover
                        child: FilterChip(
                          label: Text(
                            _getLocalizedServiceName(s.key, l10n),
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: isActive,
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          checkmarkColor: AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) {
                            final items = _servicesController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toSet();
                            if (selected) {
                              items.add(s.key);
                            } else {
                              items.remove(s.key);
                            }
                            setState(() {
                              _servicesController.text = items.join(', ');
                            });
                            _scheduleAutoSave(immediate: true);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProxySection(AppLocalizations l10n) {
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
          Text(
            l10n.proxyNoProxy,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.proxyNoProxyHelp,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noProxyController,
            style: TextStyle(fontSize: 13, color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'localhost, 127.0.0.1, *.local',
              hintStyle: TextStyle(fontSize: 13, color: c.textHint),
              filled: true,
              fillColor: c.inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.chatListBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.chatListBorder),
              ),
            ),
            onChanged: (_) => _scheduleAutoSave(),
          ),
        ],
      ),
    );
  }
}
