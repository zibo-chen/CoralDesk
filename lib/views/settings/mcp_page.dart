import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/mcp_api.dart' as mcp_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

/// MCP servers management page — add, edit, remove MCP tool servers
class McpPage extends ConsumerStatefulWidget {
  const McpPage({super.key});

  @override
  ConsumerState<McpPage> createState() => _McpPageState();
}

class _McpPageState extends ConsumerState<McpPage> {
  mcp_api.McpConfigDto? _config;
  bool _loading = true;
  String? _message;
  bool _isError = false;
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final config = await mcp_api.getMcpConfig();
    if (mounted) {
      setState(() {
        _config = config;
        _loading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    final result = await mcp_api.setMcpEnabled(enabled: enabled);
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(
        enabled
            ? AppLocalizations.of(context)!.featureEnabled
            : AppLocalizations.of(context)!.featureDisabled,
        isError: false,
      );
      _loadConfig();
    } else {
      _showMessage(
        AppLocalizations.of(context)!.operationFailed,
        isError: true,
      );
    }
  }

  Future<void> _addServer(mcp_api.McpServerDto server) async {
    final result = await mcp_api.addMcpServer(server: server);
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(AppLocalizations.of(context)!.mcpServerAdded);
      _loadConfig();
    } else {
      _showMessage(result, isError: true);
    }
  }

  Future<void> _updateServer(mcp_api.McpServerDto server) async {
    final result = await mcp_api.updateMcpServer(server: server);
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(AppLocalizations.of(context)!.mcpServerUpdated);
      _loadConfig();
    } else {
      _showMessage(result, isError: true);
    }
  }

  Future<void> _deleteServer(String name) async {
    final result = await mcp_api.removeMcpServer(name: name);
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(AppLocalizations.of(context)!.mcpServerDeleted);
      _loadConfig();
    } else {
      _showMessage(result, isError: true);
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

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return SettingsScaffold(
      title: AppLocalizations.of(context)!.pageMcpServers,
      icon: Icons.extension,
      isLoading: _loading,
      actions: [
        if (_message != null) StatusLabel(text: _message!, isError: _isError),
      ],
      body: config == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEnableToggle(config),
                const SizedBox(height: 24),
                _buildServersList(config),
              ],
            ),
    );
  }

  Widget _buildEnableToggle(mcp_api.McpConfigDto config) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.power_settings_new, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.mcpEnabled,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.mcpEnabledDesc,
                  style: TextStyle(fontSize: 12, color: c.textHint),
                ),
              ],
            ),
          ),
          Switch(
            value: config.enabled,
            onChanged: _toggleEnabled,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildServersList(mcp_api.McpConfigDto config) {
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
              Icon(Icons.dns_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(
                  context,
                )!.mcpAddServer.replaceAll('Add ', ''),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showServerDialog(null),
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.of(context)!.mcpAddServer),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (config.servers.isEmpty)
            _buildEmptyState()
          else
            ...config.servers.map(_buildServerCard),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.extension_off, size: 48, color: c.textHint),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.mcpNoServers,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.mcpNoServersHint,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard(mcp_api.McpServerDto server) {
    final transportLabel = switch (server.transport) {
      'http' => AppLocalizations.of(context)!.mcpTransportHttp,
      'sse' => AppLocalizations.of(context)!.mcpTransportSse,
      _ => AppLocalizations.of(context)!.mcpTransportStdio,
    };
    final transportIcon = switch (server.transport) {
      'http' => Icons.http,
      'sse' => Icons.stream,
      _ => Icons.terminal,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(transportIcon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  server.transport == 'stdio'
                      ? '${server.command} ${server.args.join(' ')}'
                      : server.url,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textHint,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              transportLabel,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: c.textSecondary),
            onPressed: () => _showServerDialog(server),
            tooltip: AppLocalizations.of(context)!.mcpEditServer,
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.error,
            ),
            onPressed: () => _confirmDelete(server.name),
            tooltip: AppLocalizations.of(context)!.mcpDeleteServer,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: Text(
          AppLocalizations.of(context)!.mcpDeleteServer,
          style: TextStyle(color: c.textPrimary),
        ),
        content: Text(
          AppLocalizations.of(context)!.mcpDeleteConfirm(name),
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteServer(name);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _showServerDialog(mcp_api.McpServerDto? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _McpServerDialog(
        existing: existing,
        colors: c,
        onSave: (server) {
          if (existing != null) {
            _updateServer(server);
          } else {
            _addServer(server);
          }
        },
      ),
    );
  }
}

// ─────────────────────── Server Edit Dialog ───────────────────────

class _McpServerDialog extends StatefulWidget {
  final mcp_api.McpServerDto? existing;
  final CoralDeskColors colors;
  final void Function(mcp_api.McpServerDto server) onSave;

  const _McpServerDialog({
    required this.existing,
    required this.colors,
    required this.onSave,
  });

  @override
  State<_McpServerDialog> createState() => _McpServerDialogState();
}

class _McpServerDialogState extends State<_McpServerDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _commandCtrl;
  late final TextEditingController _argsCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _timeoutCtrl;
  late String _transport;
  late List<_KvEntry> _env;
  late List<_KvEntry> _headers;

  CoralDeskColors get c => widget.colors;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _commandCtrl = TextEditingController(text: e?.command ?? '');
    _argsCtrl = TextEditingController(text: e?.args.join('\n') ?? '');
    _urlCtrl = TextEditingController(text: e?.url ?? '');
    _timeoutCtrl = TextEditingController(
      text: e?.toolTimeoutSecs != null ? e!.toolTimeoutSecs.toString() : '',
    );
    _transport = e?.transport ?? 'stdio';
    _env =
        e?.env
            .map(
              (kv) => _KvEntry(
                TextEditingController(text: kv.key),
                TextEditingController(text: kv.value),
              ),
            )
            .toList() ??
        [];
    _headers =
        e?.headers
            .map(
              (kv) => _KvEntry(
                TextEditingController(text: kv.key),
                TextEditingController(text: kv.value),
              ),
            )
            .toList() ??
        [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commandCtrl.dispose();
    _argsCtrl.dispose();
    _urlCtrl.dispose();
    _timeoutCtrl.dispose();
    for (final kv in _env) {
      kv.key.dispose();
      kv.value.dispose();
    }
    for (final kv in _headers) {
      kv.key.dispose();
      kv.value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: c.cardBg,
      title: Text(
        isEdit ? l10n.mcpEditServer : l10n.mcpAddServer,
        style: TextStyle(color: c.textPrimary),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField(l10n.mcpServerName, _nameCtrl, enabled: !isEdit),
              const SizedBox(height: 16),
              _buildTransportSelector(l10n),
              const SizedBox(height: 16),
              if (_transport == 'stdio') ...[
                _buildField(l10n.mcpCommand, _commandCtrl),
                const SizedBox(height: 12),
                _buildField(
                  l10n.mcpArgs,
                  _argsCtrl,
                  maxLines: 3,
                  hint: l10n.mcpArgsHint,
                ),
                const SizedBox(height: 12),
                _buildKvSection(l10n.mcpEnvVars, _env, () => _addKv(_env)),
              ] else ...[
                _buildField(l10n.mcpUrl, _urlCtrl, hint: 'https://...'),
                const SizedBox(height: 12),
                _buildKvSection(
                  l10n.mcpHeaders,
                  _headers,
                  () => _addKv(_headers),
                ),
              ],
              const SizedBox(height: 12),
              _buildField(
                l10n.mcpTimeout,
                _timeoutCtrl,
                hint: '30',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _onSave,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool enabled = true,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 13, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.textHint),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.chatListBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.chatListBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            filled: true,
            fillColor: c.surfaceBg,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportSelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mcpTransport,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'stdio',
              label: Text(
                l10n.mcpTransportStdio,
                style: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.terminal, size: 16),
            ),
            ButtonSegment(
              value: 'http',
              label: Text(
                l10n.mcpTransportHttp,
                style: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.http, size: 16),
            ),
            ButtonSegment(
              value: 'sse',
              label: Text(
                l10n.mcpTransportSse,
                style: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.stream, size: 16),
            ),
          ],
          selected: {_transport},
          onSelectionChanged: (sel) => setState(() => _transport = sel.first),
          style: ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  Widget _buildKvSection(
    String label,
    List<_KvEntry> entries,
    VoidCallback onAdd,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 14),
              label: Text(l10n.mcpAddKv, style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...entries.asMap().entries.map((entry) {
          final idx = entry.key;
          final kv = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: kv.key,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: l10n.mcpKeyPlaceholder,
                      hintStyle: TextStyle(color: c.textHint),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: c.chatListBorder),
                      ),
                      filled: true,
                      fillColor: c.surfaceBg,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: kv.value,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: l10n.mcpValuePlaceholder,
                      hintStyle: TextStyle(color: c.textHint),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: c.chatListBorder),
                      ),
                      filled: true,
                      fillColor: c.surfaceBg,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    size: 16,
                    color: AppColors.error,
                  ),
                  onPressed: () => setState(() => entries.removeAt(idx)),
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _addKv(List<_KvEntry> list) {
    setState(() {
      list.add(_KvEntry(TextEditingController(), TextEditingController()));
    });
  }

  void _onSave() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final args = _argsCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final timeout = int.tryParse(_timeoutCtrl.text.trim());

    final server = mcp_api.McpServerDto(
      name: name,
      transport: _transport,
      url: _urlCtrl.text.trim(),
      command: _commandCtrl.text.trim(),
      args: args,
      env: _env
          .where((kv) => kv.key.text.trim().isNotEmpty)
          .map(
            (kv) => mcp_api.KeyValueDto(
              key: kv.key.text.trim(),
              value: kv.value.text.trim(),
            ),
          )
          .toList(),
      headers: _headers
          .where((kv) => kv.key.text.trim().isNotEmpty)
          .map(
            (kv) => mcp_api.KeyValueDto(
              key: kv.key.text.trim(),
              value: kv.value.text.trim(),
            ),
          )
          .toList(),
      toolTimeoutSecs: timeout != null ? BigInt.from(timeout) : null,
    );

    widget.onSave(server);
    Navigator.pop(context);
  }
}

class _KvEntry {
  final TextEditingController key;
  final TextEditingController value;
  _KvEntry(this.key, this.value);
}
