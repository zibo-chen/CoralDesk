import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/src/rust/api/workspace_api.dart' as ws_api;
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

class GatewayPage extends ConsumerStatefulWidget {
  const GatewayPage({super.key});

  @override
  ConsumerState<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends ConsumerState<GatewayPage> {
  ws_api.GatewayConfigDto? _config;

  bool _loading = true;
  bool _saving = false;
  bool _requirePairing = true;
  bool _allowPublicBind = false;
  bool _trustForwardedHeaders = false;
  bool _sessionPersistence = true;
  bool _messageIsError = false;
  String? _message;

  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _pathPrefixCtrl;
  late final TextEditingController _pairRateLimitCtrl;
  late final TextEditingController _webhookRateLimitCtrl;
  late final TextEditingController _rateLimitMaxKeysCtrl;
  late final TextEditingController _idempotencyTtlCtrl;
  late final TextEditingController _idempotencyMaxKeysCtrl;
  late final TextEditingController _sessionTtlHoursCtrl;
  late final TextEditingController _webDistDirCtrl;
  late final TextEditingController _pairingCodeLengthCtrl;
  late final TextEditingController _pairingCodeTtlCtrl;
  late final TextEditingController _pairingMaxPendingCtrl;
  late final TextEditingController _pairingMaxFailedCtrl;
  late final TextEditingController _pairingLockoutCtrl;

  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController();
    _portCtrl = TextEditingController();
    _pathPrefixCtrl = TextEditingController();
    _pairRateLimitCtrl = TextEditingController();
    _webhookRateLimitCtrl = TextEditingController();
    _rateLimitMaxKeysCtrl = TextEditingController();
    _idempotencyTtlCtrl = TextEditingController();
    _idempotencyMaxKeysCtrl = TextEditingController();
    _sessionTtlHoursCtrl = TextEditingController();
    _webDistDirCtrl = TextEditingController();
    _pairingCodeLengthCtrl = TextEditingController();
    _pairingCodeTtlCtrl = TextEditingController();
    _pairingMaxPendingCtrl = TextEditingController();
    _pairingMaxFailedCtrl = TextEditingController();
    _pairingLockoutCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _pathPrefixCtrl.dispose();
    _pairRateLimitCtrl.dispose();
    _webhookRateLimitCtrl.dispose();
    _rateLimitMaxKeysCtrl.dispose();
    _idempotencyTtlCtrl.dispose();
    _idempotencyMaxKeysCtrl.dispose();
    _sessionTtlHoursCtrl.dispose();
    _webDistDirCtrl.dispose();
    _pairingCodeLengthCtrl.dispose();
    _pairingCodeTtlCtrl.dispose();
    _pairingMaxPendingCtrl.dispose();
    _pairingMaxFailedCtrl.dispose();
    _pairingLockoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final config = await ws_api.getGatewayConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _requirePairing = config.requirePairing;
        _allowPublicBind = config.allowPublicBind;
        _trustForwardedHeaders = config.trustForwardedHeaders;
        _sessionPersistence = config.sessionPersistence;
        _hostCtrl.text = config.host;
        _portCtrl.text = config.port.toString();
        _pathPrefixCtrl.text = config.pathPrefix ?? '';
        _pairRateLimitCtrl.text = config.pairRateLimitPerMinute.toString();
        _webhookRateLimitCtrl.text = config.webhookRateLimitPerMinute
            .toString();
        _rateLimitMaxKeysCtrl.text = config.rateLimitMaxKeys.toString();
        _idempotencyTtlCtrl.text = config.idempotencyTtlSecs.toString();
        _idempotencyMaxKeysCtrl.text = config.idempotencyMaxKeys.toString();
        _sessionTtlHoursCtrl.text = config.sessionTtlHours.toString();
        _webDistDirCtrl.text = config.webDistDir ?? '';
        _pairingCodeLengthCtrl.text = config.pairingCodeLength.toString();
        _pairingCodeTtlCtrl.text = config.pairingCodeTtlSecs.toString();
        _pairingMaxPendingCtrl.text = config.pairingMaxPendingCodes.toString();
        _pairingMaxFailedCtrl.text = config.pairingMaxFailedAttempts.toString();
        _pairingLockoutCtrl.text = config.pairingLockoutSecs.toString();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _save() async {
    final current = _config;
    if (current == null) {
      _showMessage(
        AppLocalizations.of(context)!.gatewayConfigUnavailable,
        isError: true,
      );
      return;
    }

    final validationError = _validateInputs(AppLocalizations.of(context)!);
    if (validationError != null) {
      _showMessage(validationError, isError: true);
      return;
    }

    setState(() => _saving = true);
    final result = await ws_api.saveGatewayConfig(
      configDto: ws_api.GatewayConfigDto(
        host: _fallback(_hostCtrl.text, current.host),
        port: _parseInt(_portCtrl.text, current.port),
        requirePairing: _requirePairing,
        allowPublicBind: _allowPublicBind,
        trustForwardedHeaders: _trustForwardedHeaders,
        pathPrefix: _trimOrNull(_pathPrefixCtrl.text),
        pairRateLimitPerMinute: _parseInt(
          _pairRateLimitCtrl.text,
          current.pairRateLimitPerMinute,
        ),
        webhookRateLimitPerMinute: _parseInt(
          _webhookRateLimitCtrl.text,
          current.webhookRateLimitPerMinute,
        ),
        rateLimitMaxKeys: _parseInt(
          _rateLimitMaxKeysCtrl.text,
          current.rateLimitMaxKeys,
        ),
        idempotencyTtlSecs: _parseBigInt(
          _idempotencyTtlCtrl.text,
          current.idempotencyTtlSecs,
        ),
        idempotencyMaxKeys: _parseInt(
          _idempotencyMaxKeysCtrl.text,
          current.idempotencyMaxKeys,
        ),
        sessionPersistence: _sessionPersistence,
        sessionTtlHours: _parseInt(
          _sessionTtlHoursCtrl.text,
          current.sessionTtlHours,
        ),
        webDistDir: _trimOrNull(_webDistDirCtrl.text),
        pairingCodeLength: _parseInt(
          _pairingCodeLengthCtrl.text,
          current.pairingCodeLength,
        ),
        pairingCodeTtlSecs: _parseBigInt(
          _pairingCodeTtlCtrl.text,
          current.pairingCodeTtlSecs,
        ),
        pairingMaxPendingCodes: _parseInt(
          _pairingMaxPendingCtrl.text,
          current.pairingMaxPendingCodes,
        ),
        pairingMaxFailedAttempts: _parseInt(
          _pairingMaxFailedCtrl.text,
          current.pairingMaxFailedAttempts,
        ),
        pairingLockoutSecs: _parseBigInt(
          _pairingLockoutCtrl.text,
          current.pairingLockoutSecs,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (result == 'ok') {
      _showMessage(AppLocalizations.of(context)!.configSaved);
      _load();
    } else {
      _showMessage(
        _localizeGatewayError(result, AppLocalizations.of(context)!),
        isError: true,
      );
    }
  }

  int _parseInt(String value, int fallback) =>
      int.tryParse(value.trim()) ?? fallback;

  BigInt _parseBigInt(String value, BigInt fallback) =>
      BigInt.tryParse(value.trim()) ?? fallback;

  String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _gatewayPreview() {
    final host = _hostCtrl.text.trim().isEmpty
        ? '127.0.0.1'
        : _hostCtrl.text.trim();
    final port = _portCtrl.text.trim().isEmpty
        ? '42617'
        : _portCtrl.text.trim();
    final prefix = _trimOrNull(_pathPrefixCtrl.text) ?? '';
    return 'http://$host:$port$prefix';
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

  bool get _isLocalOnly {
    final host = _hostCtrl.text.trim().toLowerCase();
    final isLocalHost =
        host.isEmpty ||
        host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1';
    return isLocalHost && !_allowPublicBind;
  }

  Future<void> _copyEndpoint() async {
    await Clipboard.setData(ClipboardData(text: _gatewayPreview()));
    if (!mounted) return;
    _showMessage(AppLocalizations.of(context)!.copiedToClipboard);
  }

  String? _validateInputs(AppLocalizations l10n) {
    if (_hostCtrl.text.trim().isEmpty) {
      return l10n.gatewayHostRequired;
    }

    final pathPrefix = _pathPrefixCtrl.text.trim();
    if (pathPrefix.isNotEmpty && !pathPrefix.startsWith('/')) {
      return l10n.gatewayPathPrefixStartWithSlash;
    }
    if (pathPrefix.length > 1 && pathPrefix.endsWith('/')) {
      return l10n.gatewayPathPrefixNoTrailingSlash;
    }
    return null;
  }

  String _localizeGatewayError(String error, AppLocalizations l10n) {
    final normalized = error.startsWith('error: ') ? error.substring(7) : error;
    switch (normalized) {
      case 'gateway host cannot be empty':
        return l10n.gatewayHostRequired;
      case 'gateway path prefix must start with /':
        return l10n.gatewayPathPrefixStartWithSlash;
      case 'gateway path prefix must not end with /':
        return l10n.gatewayPathPrefixNoTrailingSlash;
      case 'not initialized':
        return l10n.gatewayConfigUnavailable;
      default:
        return normalized;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.pageGateway,
      icon: Icons.router_outlined,
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
          _buildEndpointCard(l10n),
          const SizedBox(height: 24),
          _buildCoreCard(l10n),
          const SizedBox(height: 24),
          _buildSecurityCard(l10n),
          const SizedBox(height: 24),
          _buildLimitsCard(l10n),
          const SizedBox(height: 24),
          _buildPairingCard(l10n),
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
    return SettingsCard(
      title: l10n.gatewayOverviewTitle,
      icon: Icons.info_outline,
      children: [
        Text(
          l10n.gatewayOverviewDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(
              _isLocalOnly ? l10n.gatewayModeLocal : l10n.gatewayModePublic,
              _isLocalOnly ? AppColors.primary : Colors.orange,
            ),
            _buildStatusChip(
              _requirePairing
                  ? l10n.gatewayModePairingOn
                  : l10n.gatewayModePairingOff,
              _requirePairing ? AppColors.success : AppColors.error,
            ),
            _buildStatusChip(
              _sessionPersistence
                  ? l10n.gatewayModeSessionsOn
                  : l10n.gatewayModeSessionsOff,
              _sessionPersistence ? AppColors.primary : c.textHint,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildFactRow(Icons.qr_code_2_outlined, l10n.gatewayUsagePairing),
        const SizedBox(height: 10),
        _buildFactRow(Icons.webhook_outlined, l10n.gatewayUsageWebhooks),
        const SizedBox(height: 10),
        _buildFactRow(Icons.route_outlined, l10n.gatewayUsageProxy),
      ],
    );
  }

  Widget _buildEndpointCard(AppLocalizations l10n) {
    return SettingsCard(
      title: l10n.gatewayEndpointTitle,
      icon: Icons.link,
      children: [
        Text(
          l10n.gatewayEndpointDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.inputBorder),
          ),
          child: SelectableText(
            _gatewayPreview(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _copyEndpoint,
            icon: const Icon(Icons.copy_all_outlined, size: 16),
            label: Text(l10n.gatewayCopyEndpoint),
          ),
        ),
      ],
    );
  }

  Widget _buildCoreCard(AppLocalizations l10n) {
    return SettingsCard(
      title: l10n.gatewayCoreTitle,
      icon: Icons.settings_input_component_outlined,
      children: [
        Text(
          l10n.gatewayCoreDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildTextField(
                controller: _hostCtrl,
                label: l10n.gatewayHostLabel,
                hint: l10n.gatewayHostHint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _portCtrl,
                label: l10n.gatewayPortLabel,
                hint: l10n.gatewayPortHint,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _pathPrefixCtrl,
          label: l10n.gatewayPathPrefixLabel,
          hint: l10n.gatewayPathPrefixHint,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _webDistDirCtrl,
          label: l10n.gatewayWebDistDirLabel,
          hint: l10n.gatewayWebDistDirHint,
        ),
      ],
    );
  }

  Widget _buildSecurityCard(AppLocalizations l10n) {
    return SettingsCard(
      title: l10n.gatewaySecurityTitle,
      icon: Icons.shield_outlined,
      children: [
        Text(
          l10n.gatewaySecurityDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          title: l10n.gatewayRequirePairingLabel,
          description: l10n.gatewayRequirePairingDesc,
          value: _requirePairing,
          onChanged: (value) => setState(() => _requirePairing = value),
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          title: l10n.gatewayAllowPublicBindLabel,
          description: l10n.gatewayAllowPublicBindDesc,
          value: _allowPublicBind,
          onChanged: (value) => setState(() => _allowPublicBind = value),
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          title: l10n.gatewayTrustForwardedHeadersLabel,
          description: l10n.gatewayTrustForwardedHeadersDesc,
          value: _trustForwardedHeaders,
          onChanged: (value) => setState(() => _trustForwardedHeaders = value),
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          title: l10n.gatewaySessionPersistenceLabel,
          description: l10n.gatewaySessionPersistenceDesc,
          value: _sessionPersistence,
          onChanged: (value) => setState(() => _sessionPersistence = value),
        ),
      ],
    );
  }

  Widget _buildLimitsCard(AppLocalizations l10n) {
    return SettingsCard(
      title: l10n.gatewayLimitsTitle,
      icon: Icons.speed_outlined,
      children: [
        Text(
          l10n.gatewayLimitsDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        _buildNumberGrid([
          (
            label: l10n.gatewayPairRateLimitLabel,
            controller: _pairRateLimitCtrl,
          ),
          (
            label: l10n.gatewayWebhookRateLimitLabel,
            controller: _webhookRateLimitCtrl,
          ),
          (
            label: l10n.gatewayRateLimitMaxKeysLabel,
            controller: _rateLimitMaxKeysCtrl,
          ),
          (
            label: l10n.gatewayIdempotencyTtlLabel,
            controller: _idempotencyTtlCtrl,
          ),
          (
            label: l10n.gatewayIdempotencyMaxKeysLabel,
            controller: _idempotencyMaxKeysCtrl,
          ),
          (
            label: l10n.gatewaySessionTtlHoursLabel,
            controller: _sessionTtlHoursCtrl,
          ),
        ]),
      ],
    );
  }

  Widget _buildPairingCard(AppLocalizations l10n) {
    return SettingsCard(
      title: l10n.gatewayPairingTitle,
      icon: Icons.qr_code_2_outlined,
      children: [
        Text(
          l10n.gatewayPairingDesc,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        _buildNumberGrid([
          (
            label: l10n.gatewayPairingCodeLengthLabel,
            controller: _pairingCodeLengthCtrl,
          ),
          (
            label: l10n.gatewayPairingCodeTtlLabel,
            controller: _pairingCodeTtlCtrl,
          ),
          (
            label: l10n.gatewayPairingMaxPendingLabel,
            controller: _pairingMaxPendingCtrl,
          ),
          (
            label: l10n.gatewayPairingMaxFailedLabel,
            controller: _pairingMaxFailedCtrl,
          ),
          (
            label: l10n.gatewayPairingLockoutLabel,
            controller: _pairingLockoutCtrl,
          ),
        ]),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _buildNumberGrid(
    List<({String label, TextEditingController controller})> fields,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: fields
          .map(
            (field) => SizedBox(
              width: 220,
              child: TextField(
                controller: field.controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: field.label),
              ),
            ),
          )
          .toList(),
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

  Widget _buildFactRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.4, color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}
