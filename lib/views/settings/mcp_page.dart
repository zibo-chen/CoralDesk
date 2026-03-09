import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/mcp_api.dart' as mcp_api;
import 'package:coraldesk/services/mcp_test_client.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:coraldesk/views/settings/widgets/desktop_dialog.dart';

/// Connection status for an MCP server.
enum McpServerStatus { notTested, testing, connected, error }

/// State tracked per server.
class _ServerState {
  McpServerStatus status;
  String? error;
  List<McpToolInfo> tools;
  bool showTools;

  _ServerState({
    this.status = McpServerStatus.notTested,
    this.error,
    this.tools = const [],
    this.showTools = false,
  });
}

/// MCP servers management page — add, edit, remove MCP tool servers.
///
/// Now includes connection status, tool discovery, and test functionality
/// so users can see exactly what's happening without checking config files.
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

  /// Per-server connection state.
  final Map<String, _ServerState> _serverStates = {};

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
        // Initialize state for every server we haven't seen
        for (final s in config.servers) {
          _serverStates.putIfAbsent(s.name, _ServerState.new);
        }
        // Remove stale entries
        _serverStates.removeWhere(
          (name, _) => !config.servers.any((s) => s.name == name),
        );
      });

      // Auto-test if enabled and we have untested servers
      if (config.enabled) {
        _autoTestUntested();
      }
    }
  }

  /// Automatically test servers whose status is [notTested].
  Future<void> _autoTestUntested() async {
    final config = _config;
    if (config == null || !config.enabled) return;

    for (final server in config.servers) {
      final state = _serverStates[server.name];
      if (state != null && state.status == McpServerStatus.notTested) {
        _testServer(server);
      }
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
      // Reset state so it re-tests
      _serverStates[server.name] = _ServerState();
      _loadConfig();
    } else {
      _showMessage(result, isError: true);
    }
  }

  Future<void> _deleteServer(String name) async {
    final result = await mcp_api.removeMcpServer(name: name);
    if (!mounted) return;
    if (result == 'ok') {
      _serverStates.remove(name);
      _showMessage(AppLocalizations.of(context)!.mcpServerDeleted);
      _loadConfig();
    } else {
      _showMessage(result, isError: true);
    }
  }

  /// Test a single MCP server connection.
  Future<void> _testServer(mcp_api.McpServerDto server) async {
    setState(() {
      _serverStates[server.name] = _ServerState(
        status: McpServerStatus.testing,
      );
    });

    McpTestResult result;

    if (server.transport == 'stdio') {
      result = await McpTestClient.testStdio(
        serverName: server.name,
        command: server.command,
        args: server.args,
        env: {for (final kv in server.env) kv.key: kv.value},
      );
    } else {
      result = await McpTestClient.testHttp(
        serverName: server.name,
        url: server.url,
        headers: {for (final kv in server.headers) kv.key: kv.value},
      );
    }

    if (!mounted) return;
    setState(() {
      _serverStates[server.name] = _ServerState(
        status: result.success
            ? McpServerStatus.connected
            : McpServerStatus.error,
        error: result.error,
        tools: result.tools,
      );
    });

    if (result.success) {
      _showMessage(
        AppLocalizations.of(
          context,
        )!.mcpTestSuccess(result.toolCount, result.elapsed.inMilliseconds),
      );
    } else {
      _showMessage(
        AppLocalizations.of(
          context,
        )!.mcpTestFailed(result.error ?? 'Unknown error'),
        isError: true,
      );
    }
  }

  /// Test all configured servers.
  Future<void> _testAllServers() async {
    final config = _config;
    if (config == null) return;
    for (final server in config.servers) {
      _testServer(server);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    setState(() {
      _message = msg;
      _isError = isError;
    });
    Future.delayed(const Duration(seconds: 4), () {
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
                const SizedBox(height: 16),
                if (config.enabled) ...[
                  _buildOverviewCard(config),
                  const SizedBox(height: 16),
                ],
                _buildServersList(config),
              ],
            ),
    );
  }

  // ─────────────────── Enable Toggle ───────────────────

  Widget _buildEnableToggle(mcp_api.McpConfigDto config) {
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: config.enabled
                      ? AppColors.success.withValues(alpha: 0.15)
                      : c.surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.power_settings_new,
                  size: 18,
                  color: config.enabled ? AppColors.success : c.textHint,
                ),
              ),
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
          if (!config.enabled) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.mcpDisabledHint,
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────── Overview Card ───────────────────

  Widget _buildOverviewCard(mcp_api.McpConfigDto config) {
    final totalServers = config.servers.length;
    final connectedServers = _serverStates.values
        .where((s) => s.status == McpServerStatus.connected)
        .length;
    final totalTools = _serverStates.values.fold(
      0,
      (sum, s) => sum + s.tools.length,
    );
    final errorServers = _serverStates.values
        .where((s) => s.status == McpServerStatus.error)
        .length;
    final testingServers = _serverStates.values
        .where((s) => s.status == McpServerStatus.testing)
        .length;

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
                Icons.dashboard_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.mcpOverviewTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(
                icon: Icons.dns_outlined,
                label: 'Servers',
                value: '$connectedServers / $totalServers',
                color: connectedServers == totalServers && totalServers > 0
                    ? AppColors.success
                    : AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.build_outlined,
                label: AppLocalizations.of(context)!.mcpTools,
                value: '$totalTools',
                color: AppColors.primary,
              ),
              if (errorServers > 0) ...[
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.error_outline,
                  label: AppLocalizations.of(context)!.mcpConnectionError,
                  value: '$errorServers',
                  color: AppColors.error,
                ),
              ],
              if (testingServers > 0) ...[
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.sync,
                  label: AppLocalizations.of(context)!.mcpTesting,
                  value: '$testingServers',
                  color: AppColors.warning,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────── Servers List ───────────────────

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
                )!.mcpAddServer.replaceAll('Add ', '').replaceAll('添加', ''),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              if (config.servers.isNotEmpty && config.enabled)
                TextButton.icon(
                  onPressed: _testAllServers,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(AppLocalizations.of(context)!.mcpTestAll),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
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
            ...config.servers.map((s) => _buildServerCard(s, config.enabled)),
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

  // ─────────────────── Server Card ───────────────────

  Widget _buildServerCard(mcp_api.McpServerDto server, bool mcpEnabled) {
    final state = _serverStates[server.name] ?? _ServerState();

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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _statusBorderColor(state.status),
          width: state.status == McpServerStatus.connected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Transport icon with status indicator
                _buildServerIcon(transportIcon, state.status),
                const SizedBox(width: 12),
                // Server info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            server.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(state),
                        ],
                      ),
                      const SizedBox(height: 4),
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
                      if (state.status == McpServerStatus.connected &&
                          state.tools.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.mcpToolCount(state.tools.length),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Transport label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                // Actions
                if (mcpEnabled) ...[
                  // Test button
                  _buildActionButton(
                    icon: state.status == McpServerStatus.testing
                        ? Icons.sync
                        : Icons.play_arrow_outlined,
                    tooltip: AppLocalizations.of(context)!.mcpTestConnection,
                    onPressed: state.status == McpServerStatus.testing
                        ? null
                        : () => _testServer(server),
                    spinning: state.status == McpServerStatus.testing,
                  ),
                  // Show tools
                  if (state.tools.isNotEmpty)
                    _buildActionButton(
                      icon: state.showTools
                          ? Icons.expand_less
                          : Icons.expand_more,
                      tooltip: state.showTools
                          ? AppLocalizations.of(context)!.mcpHideTools
                          : AppLocalizations.of(context)!.mcpShowTools,
                      onPressed: () {
                        setState(() => state.showTools = !state.showTools);
                      },
                    ),
                ],
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  tooltip: AppLocalizations.of(context)!.mcpEditServer,
                  onPressed: () => _showServerDialog(server),
                ),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  tooltip: AppLocalizations.of(context)!.mcpDeleteServer,
                  onPressed: () => _confirmDelete(server.name),
                  color: AppColors.error,
                ),
              ],
            ),
          ),

          // Error message
          if (state.status == McpServerStatus.error && state.error != null)
            _buildErrorBanner(state.error!),

          // Tools list (expandable)
          if (state.showTools && state.tools.isNotEmpty)
            _buildToolsList(server.name, state.tools),
        ],
      ),
    );
  }

  Widget _buildServerIcon(IconData icon, McpServerStatus status) {
    final bgColor = switch (status) {
      McpServerStatus.connected => AppColors.success.withValues(alpha: 0.12),
      McpServerStatus.error => AppColors.error.withValues(alpha: 0.12),
      McpServerStatus.testing => AppColors.warning.withValues(alpha: 0.12),
      McpServerStatus.notTested => AppColors.primary.withValues(alpha: 0.08),
    };
    final iconColor = switch (status) {
      McpServerStatus.connected => AppColors.success,
      McpServerStatus.error => AppColors.error,
      McpServerStatus.testing => AppColors.warning,
      McpServerStatus.notTested => AppColors.primary,
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: status == McpServerStatus.testing
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20, color: iconColor),
        ),
        // Small status dot
        if (status != McpServerStatus.notTested)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
                border: Border.all(color: c.surfaceBg, width: 2),
              ),
              child: status == McpServerStatus.connected
                  ? const Icon(Icons.check, size: 7, color: Colors.white)
                  : status == McpServerStatus.error
                  ? const Icon(Icons.close, size: 7, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(_ServerState state) {
    final (label, color) = switch (state.status) {
      McpServerStatus.connected => (
        AppLocalizations.of(context)!.mcpConnected,
        AppColors.success,
      ),
      McpServerStatus.error => (
        AppLocalizations.of(context)!.mcpConnectionError,
        AppColors.error,
      ),
      McpServerStatus.testing => (
        AppLocalizations.of(context)!.mcpTesting,
        AppColors.warning,
      ),
      McpServerStatus.notTested => (
        AppLocalizations.of(context)!.mcpNotTested,
        c.textHint,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    bool spinning = false,
    Color? color,
  }) {
    return IconButton(
      icon: spinning
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color ?? c.textSecondary,
              ),
            )
          : Icon(icon, size: 18, color: color ?? c.textSecondary),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Color _statusBorderColor(McpServerStatus status) {
    return switch (status) {
      McpServerStatus.connected => AppColors.success.withValues(alpha: 0.4),
      McpServerStatus.error => AppColors.error.withValues(alpha: 0.4),
      McpServerStatus.testing => AppColors.warning.withValues(alpha: 0.3),
      McpServerStatus.notTested => c.chatListBorder,
    };
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: AppColors.error.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(fontSize: 12, color: AppColors.error),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsList(String serverName, List<McpToolInfo> tools) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.chatListBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(Icons.build_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${AppLocalizations.of(context)!.mcpTools} (${tools.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...tools.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${serverName}__${tool.name}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (tool.description.isNotEmpty)
                          Text(
                            tool.description,
                            style: TextStyle(fontSize: 11, color: c.textHint),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Dialogs ───────────────────

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

  // Test state within dialog
  bool _isTesting = false;
  McpTestResult? _testResult;

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

  /// Test connection from within the dialog (before saving).
  Future<void> _testFromDialog() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    McpTestResult result;
    if (_transport == 'stdio') {
      final args = _argsCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final env = <String, String>{};
      for (final kv in _env) {
        if (kv.key.text.trim().isNotEmpty) {
          env[kv.key.text.trim()] = kv.value.text.trim();
        }
      }
      result = await McpTestClient.testStdio(
        serverName: name,
        command: _commandCtrl.text.trim(),
        args: args,
        env: env,
      );
    } else {
      final headers = <String, String>{};
      for (final kv in _headers) {
        if (kv.key.text.trim().isNotEmpty) {
          headers[kv.key.text.trim()] = kv.value.text.trim();
        }
      }
      result = await McpTestClient.testHttp(
        serverName: name,
        url: _urlCtrl.text.trim(),
        headers: headers,
      );
    }

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;

    return DesktopDialog(
      title: isEdit ? l10n.mcpEditServer : l10n.mcpAddServer,
      icon: Icons.extension_outlined,
      width: 700,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity ──
          DialogSection(
            title: 'SERVER',
            icon: Icons.dns_outlined,
            children: [
              FieldRow(
                children: [
                  _buildFieldWidget(
                    l10n.mcpServerName,
                    _nameCtrl,
                    enabled: !isEdit,
                  ),
                  _buildFieldWidget(
                    l10n.mcpTimeout,
                    _timeoutCtrl,
                    hint: '30',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ],
          ),

          // ── Transport ──
          DialogSection(
            title: 'TRANSPORT',
            icon: Icons.swap_horiz,
            children: [
              FieldColumn(child: _buildTransportSelector(l10n)),
              if (_transport == 'stdio') ...[
                FieldRow(
                  children: [
                    _buildFieldWidget(l10n.mcpCommand, _commandCtrl),
                    _buildFieldWidget(
                      l10n.mcpArgs,
                      _argsCtrl,
                      maxLines: 3,
                      hint: l10n.mcpArgsHint,
                    ),
                  ],
                ),
                _buildKvSection(l10n.mcpEnvVars, _env, () => _addKv(_env)),
              ] else ...[
                FieldColumn(
                  child: _buildFieldWidget(
                    l10n.mcpUrl,
                    _urlCtrl,
                    hint: 'https://...',
                  ),
                ),
                _buildKvSection(
                  l10n.mcpHeaders,
                  _headers,
                  () => _addKv(_headers),
                ),
              ],
            ],
          ),

          // ── Test Result (within dialog) ──
          if (_testResult != null) _buildDialogTestResult(),
        ],
      ),
      actions: [
        // Test button in dialog
        OutlinedButton.icon(
          onPressed: _isTesting ? null : _testFromDialog,
          icon: _isTesting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_outlined, size: 16),
          label: Text(_isTesting ? l10n.mcpTesting : l10n.mcpTestConnection),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
        ),
        const SizedBox(width: 8),
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

  Widget _buildDialogTestResult() {
    final result = _testResult!;
    final color = result.success ? AppColors.success : AppColors.error;
    final icon = result.success
        ? Icons.check_circle_outline
        : Icons.error_outline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.success
                      ? AppLocalizations.of(context)!.mcpTestSuccess(
                          result.toolCount,
                          result.elapsed.inMilliseconds,
                        )
                      : AppLocalizations.of(
                          context,
                        )!.mcpTestFailed(result.error ?? 'Unknown error'),
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          // Show discovered tools
          if (result.success && result.tools.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: result.tools.map((tool) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tool.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldWidget(
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
          onSelectionChanged: (sel) {
            setState(() {
              _transport = sel.first;
              _testResult = null;
            });
          },
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
