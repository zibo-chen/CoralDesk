import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/src/rust/api/workspace_api.dart' as ws_api;
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key});

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  ws_api.BrowserConfigDto? _config;

  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  bool _nativeHeadless = true;
  bool _computerUseAllowRemoteEndpoint = false;
  bool _showComputerUseApiKey = false;
  bool _messageIsError = false;
  String _backend = 'agent_browser';
  String? _message;

  late final TextEditingController _allowedDomainsCtrl;
  late final TextEditingController _sessionNameCtrl;
  late final TextEditingController _nativeWebdriverUrlCtrl;
  late final TextEditingController _nativeChromePathCtrl;
  late final TextEditingController _computerUseEndpointCtrl;
  late final TextEditingController _computerUseApiKeyCtrl;
  late final TextEditingController _computerUseWindowAllowlistCtrl;
  late final TextEditingController _computerUseMaxXCtrl;
  late final TextEditingController _computerUseMaxYCtrl;

  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _allowedDomainsCtrl = TextEditingController();
    _sessionNameCtrl = TextEditingController();
    _nativeWebdriverUrlCtrl = TextEditingController();
    _nativeChromePathCtrl = TextEditingController();
    _computerUseEndpointCtrl = TextEditingController();
    _computerUseApiKeyCtrl = TextEditingController();
    _computerUseWindowAllowlistCtrl = TextEditingController();
    _computerUseMaxXCtrl = TextEditingController();
    _computerUseMaxYCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _allowedDomainsCtrl.dispose();
    _sessionNameCtrl.dispose();
    _nativeWebdriverUrlCtrl.dispose();
    _nativeChromePathCtrl.dispose();
    _computerUseEndpointCtrl.dispose();
    _computerUseApiKeyCtrl.dispose();
    _computerUseWindowAllowlistCtrl.dispose();
    _computerUseMaxXCtrl.dispose();
    _computerUseMaxYCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final config = await ws_api.getBrowserConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _enabled = config.enabled;
        _backend = config.backend;
        _nativeHeadless = config.nativeHeadless;
        _computerUseAllowRemoteEndpoint = config.computerUseAllowRemoteEndpoint;
        _allowedDomainsCtrl.text = _joinList(config.allowedDomains);
        _sessionNameCtrl.text = config.sessionName ?? '';
        _nativeWebdriverUrlCtrl.text = config.nativeWebdriverUrl;
        _nativeChromePathCtrl.text = config.nativeChromePath ?? '';
        _computerUseEndpointCtrl.text = config.computerUseEndpoint;
        _computerUseApiKeyCtrl.text = config.computerUseApiKey ?? '';
        _computerUseWindowAllowlistCtrl.text = _joinList(
          config.computerUseWindowAllowlist,
        );
        _computerUseMaxXCtrl.text =
            config.computerUseMaxCoordinateX?.toString() ?? '';
        _computerUseMaxYCtrl.text =
            config.computerUseMaxCoordinateY?.toString() ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(
        _localizeBrowserError(error.toString(), AppLocalizations.of(context)!),
        isError: true,
      );
    }
  }

  Future<void> _save() async {
    final current = _config;
    if (current == null) {
      _showMessage(
        AppLocalizations.of(context)!.browserConfigUnavailable,
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    final result = await ws_api.saveBrowserConfig(
      configDto: ws_api.BrowserConfigDto(
        enabled: _enabled,
        backend: _backend,
        allowedDomains: _parseList(_allowedDomainsCtrl.text),
        sessionName: _trimOrNull(_sessionNameCtrl.text),
        nativeHeadless: _nativeHeadless,
        nativeWebdriverUrl: _fallback(
          _nativeWebdriverUrlCtrl.text,
          'http://127.0.0.1:9515',
        ),
        nativeChromePath: _trimOrNull(_nativeChromePathCtrl.text),
        computerUseEndpoint: _fallback(
          _computerUseEndpointCtrl.text,
          'http://127.0.0.1:8787/v1/actions',
        ),
        computerUseApiKey: _trimOrNull(_computerUseApiKeyCtrl.text),
        computerUseAllowRemoteEndpoint: _computerUseAllowRemoteEndpoint,
        computerUseWindowAllowlist: _parseList(
          _computerUseWindowAllowlistCtrl.text,
        ),
        computerUseMaxCoordinateX: _parseNullableInt(_computerUseMaxXCtrl.text),
        computerUseMaxCoordinateY: _parseNullableInt(_computerUseMaxYCtrl.text),
        agentBrowserCommand: current.agentBrowserCommand,
        agentBrowserAvailable: current.agentBrowserAvailable,
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (result == 'ok') {
      _showMessage(AppLocalizations.of(context)!.configSaved);
      _load();
    } else {
      _showMessage(
        _localizeBrowserError(result, AppLocalizations.of(context)!),
        isError: true,
      );
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

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  int? _parseNullableInt(String value) => int.tryParse(value.trim());

  Future<void> _copyBrowserCommand() async {
    final command = _config?.agentBrowserCommand ?? '';
    if (command.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: command));
    if (!mounted) return;
    _showMessage(AppLocalizations.of(context)!.copiedToClipboard);
  }

  String _localizeBrowserError(String error, AppLocalizations l10n) {
    final normalized = error.startsWith('error: ') ? error.substring(7) : error;
    switch (normalized) {
      case 'not initialized':
        return l10n.browserConfigUnavailable;
      default:
        return normalized;
    }
  }

  String _backendLabel(String backend, AppLocalizations l10n) {
    return switch (backend) {
      'agent_browser' => l10n.browserBackendOptionAgentBrowser,
      'rust_native' => l10n.browserBackendOptionRustNative,
      'computer_use' => l10n.browserBackendOptionComputerUse,
      'auto' => l10n.browserBackendOptionAuto,
      _ => backend,
    };
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.featureBrowser,
      icon: Icons.open_in_browser,
      isLoading: _loading,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: l10n.refresh,
          onPressed: _loading ? null : _load,
        ),
        if (_message != null)
          StatusLabel(text: _message!, isError: _messageIsError),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewCard(l10n),
          const SizedBox(height: 24),
          _buildCoreCard(l10n),
          const SizedBox(height: 24),
          _buildNativeCard(l10n),
          const SizedBox(height: 24),
          _buildComputerUseCard(l10n),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(_saving ? l10n.saving : l10n.save),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(AppLocalizations l10n) {
    final config = _config;
    final command = config?.agentBrowserCommand ?? '';
    final hasCommand = command.trim().isNotEmpty;

    return SettingsCard(
      title: l10n.browserOverviewTitle,
      icon: Icons.dashboard_customize_outlined,
      children: [
        Text(
          l10n.browserOverviewDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(
              _enabled ? l10n.browserModeEnabled : l10n.browserModeDisabled,
              _enabled ? AppColors.primary : c.textHint,
            ),
            _buildStatusChip(_backendLabel(_backend, l10n), AppColors.primary),
            _buildStatusChip(
              (config?.agentBrowserAvailable ?? false)
                  ? l10n.browserModeAgentBrowserReady
                  : l10n.browserModeAgentBrowserMissing,
              (config?.agentBrowserAvailable ?? false)
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          label: l10n.browserCommandLabel,
          value: hasCommand ? command : l10n.browserCommandUnavailable,
          onCopy: hasCommand ? _copyBrowserCommand : null,
        ),
      ],
    );
  }

  Widget _buildCoreCard(AppLocalizations l10n) {
    return SettingsCard(
      title: l10n.browserCoreTitle,
      icon: Icons.settings_ethernet,
      children: [
        Text(
          l10n.browserCoreDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          title: l10n.browserModeEnabled,
          description: l10n.featureBrowserDesc,
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _backend,
          decoration: InputDecoration(labelText: l10n.browserBackendLabel),
          items: [
            DropdownMenuItem(
              value: 'agent_browser',
              child: Text(l10n.browserBackendOptionAgentBrowser),
            ),
            DropdownMenuItem(
              value: 'rust_native',
              child: Text(l10n.browserBackendOptionRustNative),
            ),
            DropdownMenuItem(
              value: 'computer_use',
              child: Text(l10n.browserBackendOptionComputerUse),
            ),
            DropdownMenuItem(
              value: 'auto',
              child: Text(l10n.browserBackendOptionAuto),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _backend = value);
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _sessionNameCtrl,
          label: l10n.browserSessionNameLabel,
          hint: l10n.browserSessionNameHint,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _allowedDomainsCtrl,
          label: l10n.browserAllowedDomainsLabel,
          hint: l10n.browserAllowedDomainsHint,
          minLines: 1,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildNativeCard(AppLocalizations l10n) {
    return SettingsCard(
      title: l10n.browserNativeTitle,
      icon: Icons.developer_mode_outlined,
      children: [
        Text(
          l10n.browserNativeDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          title: l10n.browserNativeHeadlessLabel,
          description: l10n.browserNativeHeadlessDesc,
          value: _nativeHeadless,
          onChanged: (value) => setState(() => _nativeHeadless = value),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _nativeWebdriverUrlCtrl,
          label: l10n.browserNativeWebdriverUrlLabel,
          hint: l10n.browserNativeWebdriverUrlHint,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _nativeChromePathCtrl,
          label: l10n.browserNativeChromePathLabel,
          hint: l10n.browserNativeChromePathHint,
        ),
      ],
    );
  }

  Widget _buildComputerUseCard(AppLocalizations l10n) {
    return SettingsCard(
      title: l10n.browserComputerUseTitle,
      icon: Icons.mouse_outlined,
      children: [
        Text(
          l10n.browserComputerUseDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _computerUseEndpointCtrl,
          label: l10n.browserComputerUseEndpointLabel,
          hint: l10n.browserComputerUseEndpointHint,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _computerUseApiKeyCtrl,
          obscureText: !_showComputerUseApiKey,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.browserComputerUseApiKeyLabel,
            hintText: l10n.apiKeyHint,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _showComputerUseApiKey = !_showComputerUseApiKey;
                });
              },
              icon: Icon(
                _showComputerUseApiKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          title: l10n.browserComputerUseAllowRemoteLabel,
          description: l10n.browserComputerUseAllowRemoteDesc,
          value: _computerUseAllowRemoteEndpoint,
          onChanged: (value) {
            setState(() => _computerUseAllowRemoteEndpoint = value);
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _computerUseWindowAllowlistCtrl,
          label: l10n.browserComputerUseWindowAllowlistLabel,
          hint: l10n.browserComputerUseWindowAllowlistHint,
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _computerUseMaxXCtrl,
                label: l10n.browserComputerUseMaxCoordinateXLabel,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _computerUseMaxYCtrl,
                label: l10n.browserComputerUseMaxCoordinateYLabel,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: TextStyle(fontSize: 13, height: 1.4, color: c.textPrimary),
          ),
          if (onCopy != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                label: Text(AppLocalizations.of(context)!.tooltipCopy),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
      ),
      value: value,
      onChanged: onChanged,
      tileColor: c.inputBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.inputBorder),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
