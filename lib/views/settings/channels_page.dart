import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:coraldesk/src/rust/api/workspace_api.dart' as ws_api;
import 'package:coraldesk/src/rust/api/channel_runtime_api.dart' as channel_rt;

/// Channels configuration page — shows all available communication channels
/// with GUI configuration support
class ChannelsPage extends ConsumerStatefulWidget {
  const ChannelsPage({super.key});

  @override
  ConsumerState<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends ConsumerState<ChannelsPage> {
  List<ws_api.ChannelSummary>? _channels;
  bool _loading = true;
  String? _message;
  bool _listenersRunning = false;
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final channels = await ws_api.listChannels();
    final running = await channel_rt.isChannelListenersRunning();
    if (mounted) {
      setState(() {
        _channels = channels;
        _listenersRunning = running;
        _loading = false;
      });
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    setState(() => _message = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  Future<void> _configureChannel(ws_api.ChannelSummary channel) async {
    // Load existing config
    final configJson = await ws_api.getChannelConfig(
      channelType: channel.channelType,
    );
    final config = jsonDecode(configJson) as Map<String, dynamic>;

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) =>
          _ChannelConfigDialog(channel: channel, currentConfig: config),
    );

    if (result != null) {
      final saveResult = await ws_api.saveChannelConfig(
        channelType: channel.channelType,
        configJson: jsonEncode(result),
      );
      if (!mounted) return;
      if (saveResult == 'ok') {
        _showMessage(
          AppLocalizations.of(context)!.channelConfigSaved(channel.name),
        );
        _loadChannels();
      } else {
        _showMessage(
          AppLocalizations.of(context)!.saveFailedWithError(saveResult),
          isError: true,
        );
      }
    }
  }

  Future<void> _disableChannel(ws_api.ChannelSummary channel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.disableChannelTitle(channel.name),
        ),
        content: Text(AppLocalizations.of(context)!.disableChannelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.disable),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final result = await ws_api.toggleChannel(
        channelType: channel.channelType,
        enabled: false,
      );
      if (!mounted) return;
      if (result == 'ok') {
        _showMessage(
          AppLocalizations.of(context)!.channelDisabled(channel.name),
        );
        _loadChannels();
      } else {
        _showMessage(
          AppLocalizations.of(context)!.operationFailedWithError(result),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: AppLocalizations.of(context)!.pageChannels,
      icon: Icons.wifi,
      isLoading: _loading,
      body: _buildContent(),
      actions: [
        if (_message != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _message!,
              style: const TextStyle(color: AppColors.success, fontSize: 13),
            ),
          ),
        const SizedBox(width: 12),
        // Channel listeners running indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _listenersRunning
                ? AppColors.success.withValues(alpha: 0.1)
                : c.inputBg,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _listenersRunning
                    ? Icons.cell_tower
                    : Icons.signal_cellular_off,
                size: 14,
                color: _listenersRunning ? AppColors.success : c.textHint,
              ),
              const SizedBox(width: 4),
              Text(
                _listenersRunning ? '监听中' : '已停止',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _listenersRunning ? AppColors.success : c.textHint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Start / Stop button
        IconButton(
          icon: Icon(
            _listenersRunning
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outlined,
            size: 22,
          ),
          color: _listenersRunning ? AppColors.error : AppColors.primary,
          tooltip: _listenersRunning ? '停止频道监听' : '启动频道监听',
          onPressed: () async {
            if (_listenersRunning) {
              await channel_rt.stopChannelListeners();
            } else {
              await channel_rt.startChannelListeners();
            }
            _loadChannels();
          },
        ),
        const SizedBox(width: 8),
        if (_channels != null)
          Text(
            AppLocalizations.of(
              context,
            )!.activeCount(_channels!.where((c) => c.enabled).length),
            style: TextStyle(fontSize: 13, color: c.textHint),
          ),
      ],
    );
  }

  Widget _buildContent() {
    final channels = _channels;
    if (channels == null || channels.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noChannelsAvailable,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enabled channels
        _buildSection(
          AppLocalizations.of(context)!.activeChannels,
          channels.where((c) => c.enabled).toList(),
        ),
        const SizedBox(height: 24),
        // Available channels
        _buildSection(
          AppLocalizations.of(context)!.availableChannels,
          channels.where((c) => !c.enabled).toList(),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<ws_api.ChannelSummary> channels) {
    if (channels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...channels.map(_buildChannelCard),
      ],
    );
  }

  Widget _buildChannelCard(ws_api.ChannelSummary channel) {
    final icon = _channelIcon(channel.channelType);
    final color = channel.enabled ? AppColors.primary : c.textHint;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: channel.enabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : c.chatListBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  channel.description,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: channel.enabled
                  ? AppColors.success.withValues(alpha: 0.1)
                  : c.inputBg,
            ),
            child: Text(
              channel.enabled
                  ? AppLocalizations.of(context)!.statusActive
                  : AppLocalizations.of(context)!.statusInactive,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: channel.enabled ? AppColors.success : c.textHint,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Configure button
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            color: AppColors.primary,
            tooltip: AppLocalizations.of(
              context,
            )!.configureChannel(channel.name),
            onPressed: () => _configureChannel(channel),
          ),
          // Disable button (only for active channels, excluding CLI)
          if (channel.enabled && channel.channelType != 'cli')
            IconButton(
              icon: const Icon(Icons.power_settings_new, size: 20),
              color: AppColors.error,
              tooltip: AppLocalizations.of(
                context,
              )!.disableChannel(channel.name),
              onPressed: () => _disableChannel(channel),
            ),
        ],
      ),
    );
  }

  IconData _channelIcon(String type) {
    return switch (type) {
      'cli' => Icons.terminal,
      'telegram' => Icons.send,
      'discord' => Icons.headset_mic,
      'slack' => Icons.tag,
      'matrix' => Icons.grid_on,
      'webhook' => Icons.webhook,
      'email' => Icons.email_outlined,
      'lark' => Icons.flight,
      'dingtalk' => Icons.notifications_active,
      'whatsapp' => Icons.chat,
      'signal' => Icons.security,
      'irc' => Icons.forum,
      _ => Icons.wifi,
    };
  }
}

// ─────────────── Channel Config Dialog ───────────────────

class _ChannelConfigDialog extends StatefulWidget {
  final ws_api.ChannelSummary channel;
  final Map<String, dynamic> currentConfig;

  const _ChannelConfigDialog({
    required this.channel,
    required this.currentConfig,
  });

  @override
  State<_ChannelConfigDialog> createState() => _ChannelConfigDialogState();
}

class _ChannelConfigDialogState extends State<_ChannelConfigDialog> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, bool> _boolValues;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _boolValues = {};
    // Initialize controllers from config
    for (final entry in widget.currentConfig.entries) {
      if (entry.value is bool) {
        _boolValues[entry.key] = entry.value as bool;
      } else if (entry.value is List) {
        _controllers[entry.key] = TextEditingController(
          text: (entry.value as List).join(', '),
        );
      } else {
        _controllers[entry.key] = TextEditingController(
          text: entry.value?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = _getFieldDefinitions(widget.channel.channelType);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context)!.configureChannel(widget.channel.name),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields.map((field) => _buildField(field)).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(AppLocalizations.of(context)!.save),
        ),
      ],
    );
  }

  Widget _buildField(_FieldDef field) {
    if (field.type == 'bool') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SwitchListTile(
          title: Text(field.label, style: const TextStyle(fontSize: 14)),
          subtitle: field.description.isNotEmpty
              ? Text(field.description, style: const TextStyle(fontSize: 12))
              : null,
          value: _boolValues[field.key] ?? false,
          activeTrackColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _boolValues[field.key] = v),
        ),
      );
    }

    final controller = _controllers[field.key];
    if (controller == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: field.type == 'password',
        maxLines: field.type == 'text_list' ? 2 : 1,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          hintText: field.hint,
          helperText: field.description.isNotEmpty ? field.description : null,
          helperMaxLines: 2,
        ),
      ),
    );
  }

  void _submit() {
    final result = <String, dynamic>{};

    for (final entry in widget.currentConfig.entries) {
      if (entry.value is bool) {
        result[entry.key] = _boolValues[entry.key] ?? false;
      } else if (entry.value is List) {
        final text = _controllers[entry.key]?.text ?? '';
        if (text.isEmpty) {
          result[entry.key] = <String>[];
        } else {
          result[entry.key] = text
              .split(RegExp(r'[,\n]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } else if (entry.value is int) {
        result[entry.key] =
            int.tryParse(_controllers[entry.key]?.text ?? '0') ?? 0;
      } else {
        result[entry.key] = _controllers[entry.key]?.text ?? '';
      }
    }

    Navigator.pop(context, result);
  }

  List<_FieldDef> _getFieldDefinitions(String type) {
    return switch (type) {
      'cli' => [
        _FieldDef('enabled', 'CLI 启用', 'bool', description: '启用命令行交互通道'),
      ],
      'telegram' => [
        _FieldDef(
          'bot_token',
          'Bot Token',
          'password',
          required: true,
          hint: '123456:ABC-DEF...',
          description: '从 @BotFather 获取',
        ),
        _FieldDef(
          'allowed_users',
          '允许的用户',
          'text_list',
          hint: 'user_id1, user_id2',
          description: '逗号分隔的 Telegram 用户 ID',
        ),
        _FieldDef('mention_only', '仅 @提及时响应', 'bool'),
      ],
      'discord' => [
        _FieldDef(
          'bot_token',
          'Bot Token',
          'password',
          required: true,
          description: 'Discord Bot Token',
        ),
        _FieldDef('guild_id', 'Guild ID', 'text', hint: '可选, 限定服务器'),
        _FieldDef(
          'allowed_users',
          '允许的用户',
          'text_list',
          hint: 'user_id1, user_id2',
        ),
        _FieldDef('listen_to_bots', '监听其他 Bot', 'bool'),
        _FieldDef('mention_only', '仅 @提及时响应', 'bool'),
      ],
      'slack' => [
        _FieldDef(
          'bot_token',
          'Bot Token',
          'password',
          required: true,
          hint: 'xoxb-...',
        ),
        _FieldDef(
          'app_token',
          'App Token',
          'password',
          hint: 'xapp-... (Socket Mode)',
        ),
        _FieldDef('channel_id', 'Channel ID', 'text', hint: '可选, 限定频道'),
        _FieldDef(
          'allowed_users',
          '允许的用户',
          'text_list',
          hint: 'user_id1, user_id2',
        ),
      ],
      'webhook' => [
        _FieldDef('port', '端口', 'number', required: true, hint: '8080'),
        _FieldDef('secret', 'Secret', 'password', hint: '可选, 验证密钥'),
      ],
      'email' => [
        _FieldDef(
          'imap_host',
          'IMAP 主机',
          'text',
          required: true,
          hint: 'imap.gmail.com',
        ),
        _FieldDef('imap_port', 'IMAP 端口', 'number', hint: '993'),
        _FieldDef(
          'smtp_host',
          'SMTP 主机',
          'text',
          required: true,
          hint: 'smtp.gmail.com',
        ),
        _FieldDef('smtp_port', 'SMTP 端口', 'number', hint: '465'),
        _FieldDef('smtp_tls', 'SMTP TLS', 'bool'),
        _FieldDef(
          'username',
          '用户名',
          'text',
          required: true,
          hint: 'you@example.com',
        ),
        _FieldDef('password', '密码', 'password', required: true),
        _FieldDef('from_address', '发件人地址', 'text', hint: 'bot@example.com'),
        _FieldDef(
          'allowed_senders',
          '允许的发件人',
          'text_list',
          hint: 'admin@example.com',
        ),
      ],
      'lark' => [
        _FieldDef(
          'app_id',
          'App ID',
          'text',
          required: true,
          description: '飞书/Lark 应用 ID',
        ),
        _FieldDef('app_secret', 'App Secret', 'password', required: true),
        _FieldDef('allowed_users', '允许的用户', 'text_list'),
        _FieldDef('mention_only', '仅 @提及时响应', 'bool'),
      ],
      'dingtalk' => [
        _FieldDef('client_id', 'Client ID (AppKey)', 'text', required: true),
        _FieldDef(
          'client_secret',
          'Client Secret (AppSecret)',
          'password',
          required: true,
        ),
        _FieldDef('allowed_users', '允许的用户', 'text_list'),
      ],
      'matrix' => [
        _FieldDef(
          'homeserver',
          'Homeserver URL',
          'text',
          required: true,
          hint: 'https://matrix.org',
        ),
        _FieldDef('access_token', 'Access Token', 'password', required: true),
        _FieldDef('user_id', 'User ID', 'text', hint: '@bot:matrix.org'),
        _FieldDef(
          'room_id',
          'Room ID',
          'text',
          required: true,
          hint: '!room:matrix.org',
        ),
        _FieldDef('allowed_users', '允许的用户', 'text_list'),
      ],
      'signal' => [
        _FieldDef(
          'http_url',
          'Signal CLI HTTP URL',
          'text',
          required: true,
          hint: 'http://localhost:8080',
        ),
        _FieldDef('account', '账号', 'text', required: true, hint: '+1234567890'),
        _FieldDef('group_id', 'Group ID', 'text', hint: '可选'),
        _FieldDef('allowed_from', '允许的来源', 'text_list', hint: '+1234567890'),
      ],
      'whatsapp' => [
        _FieldDef('phone_number_id', 'Phone Number ID', 'text', required: true),
        _FieldDef('access_token', 'Access Token', 'password'),
        _FieldDef('verify_token', 'Verify Token', 'text'),
        _FieldDef('allowed_numbers', '允许的号码', 'text_list', hint: '+1234567890'),
      ],
      'irc' => [
        _FieldDef(
          'server',
          '服务器',
          'text',
          required: true,
          hint: 'irc.libera.chat',
        ),
        _FieldDef('port', '端口', 'number', hint: '6697'),
        _FieldDef('nickname', '昵称', 'text', required: true, hint: 'zeroclaw'),
        _FieldDef('channels', '频道', 'text_list', hint: '#channel1, #channel2'),
        _FieldDef('allowed_users', '允许的用户', 'text_list'),
        _FieldDef('verify_tls', '验证 TLS', 'bool'),
        _FieldDef('server_password', '服务器密码', 'password'),
      ],
      _ => [],
    };
  }
}

class _FieldDef {
  final String key;
  final String label;
  final String type; // 'text', 'password', 'number', 'bool', 'text_list'
  final bool required;
  final String hint;
  final String description;

  const _FieldDef(
    this.key,
    this.label,
    this.type, {
    this.required = false,
    this.hint = '',
    this.description = '',
  });
}
