import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/constants.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/models/project.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/providers_api.dart' as providers_api;
import 'package:coraldesk/src/rust/api/agent_workspace_api.dart'
    as workspace_api;

/// Chat input bar at the bottom of the chat view
class ChatInputBar extends ConsumerStatefulWidget {
  final Function(String) onSend;
  final VoidCallback? onCancel;

  const ChatInputBar({super.key, required this.onSend, this.onCancel});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  CoralDeskColors get c => CoralDeskColors.of(context);
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(isCurrentSessionProcessingProvider);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(40, 8, 40, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            constraints: BoxConstraints(
              minHeight: _isExpanded ? 200 : 56,
              maxHeight: _isExpanded ? 400 : 120,
            ),
            decoration: BoxDecoration(
              color: c.surfaceBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.chatListBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      // Enter to send, Shift+Enter for newline
                      // Skip if IME is composing (e.g. pinyin input)
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed &&
                          !_controller.value.composing.isValid) {
                        _send();
                      }
                    },
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      maxLength: AppConstants.maxInputLength,
                      enabled: !isProcessing,
                      decoration: InputDecoration(
                        hintText: isProcessing
                            ? l10n.processing
                            : l10n.typeYourMessage,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                          20,
                          16,
                          20,
                          8,
                        ),
                        counterText: '',
                        filled: false,
                        hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textPrimary,
                        height: 1.5,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ),
                // Bottom toolbar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      // Expand button
                      IconButton(
                        icon: Icon(
                          _isExpanded
                              ? Icons.close_fullscreen
                              : Icons.open_in_full,
                          size: 16,
                        ),
                        color: c.textHint,
                        onPressed: () {
                          setState(() => _isExpanded = !_isExpanded);
                        },
                        tooltip: _isExpanded ? l10n.collapse : l10n.expand,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // File attachment button
                      _AttachmentButton(),
                      const SizedBox(width: 4),
                      // Model selector button
                      _ModelSelectorButton(),
                      const SizedBox(width: 4),
                      // Agent selector button
                      _AgentSelectorButton(),
                      const SizedBox(width: 4),
                      // Multi-agent toggle
                      _MultiAgentToggleButton(),
                      const Spacer(),
                      // Character count
                      Text(
                        '${_controller.text.length}/${AppConstants.maxInputLength}',
                        style: TextStyle(fontSize: 12, color: c.textHint),
                      ),
                      const SizedBox(width: 12),
                      // Send or Stop button
                      if (isProcessing)
                        // Stop generation button
                        Tooltip(
                          message: l10n.stopGenerating,
                          child: InkWell(
                            onTap: widget.onCancel,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.red.shade400,
                              ),
                              child: const Icon(
                                Icons.stop,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        // Send button
                        InkWell(
                          onTap: _controller.text.trim().isNotEmpty
                              ? _send
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _controller.text.trim().isNotEmpty
                                  ? AppColors.primary
                                  : c.inputBg,
                            ),
                            child: Icon(
                              Icons.arrow_upward,
                              size: 18,
                              color: _controller.text.trim().isNotEmpty
                                  ? Colors.white
                                  : c.textHint,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tagline
          Text(
            l10n.appTagline,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
        ],
      ),
    );
  }
}

/// Model selector button — shows current model and allows switching
class _ModelSelectorButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ModelSelectorButton> createState() =>
      _ModelSelectorButtonState();
}

class _ModelSelectorButtonState extends ConsumerState<_ModelSelectorButton> {
  String? _currentProvider;
  String? _currentModel;

  @override
  void initState() {
    super.initState();
    _loadCurrentModel();
    _loadProfilesForMenu();
  }

  Future<void> _loadCurrentModel() async {
    final status = await agent_api.getRuntimeStatus();
    if (mounted) {
      setState(() {
        _currentProvider = status.provider;
        _currentModel = status.model;
      });
    }
  }

  Future<void> _switchModel(String provider, String model) async {
    final result = await providers_api.switchActiveModel(
      provider: provider,
      model: model,
    );
    if (result == 'ok' && mounted) {
      setState(() {
        _currentProvider = provider;
        _currentModel = model;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Short display: show only model name (truncated)
    final displayModel = _currentModel ?? '...';
    final truncated = displayModel.length > 24
        ? '${displayModel.substring(0, 22)}…'
        : displayModel;

    return PopupMenuButton<_ModelChoice>(
      tooltip: l10n.chatModelSelector,
      offset: const Offset(0, -200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: c.surfaceBg,
      onSelected: (choice) {
        _switchModel(choice.provider, choice.model);
      },
      itemBuilder: (context) {
        // We'll build items asynchronously; for now use a FutureBuilder approach
        // Since PopupMenuButton needs sync items, we preload in initState
        return _buildMenuItems(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: c.inputBg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.model_training, size: 14, color: c.textHint),
            const SizedBox(width: 4),
            Text(
              truncated,
              style: TextStyle(fontSize: 11, color: c.textSecondary),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: c.textHint),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<_ModelChoice>> _buildMenuItems(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final items = <PopupMenuEntry<_ModelChoice>>[];

    // Current model header
    if (_currentProvider != null && _currentModel != null) {
      items.add(
        PopupMenuItem<_ModelChoice>(
          enabled: false,
          child: Text(
            l10n.chatCurrentModel(_currentProvider!, _currentModel!),
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
        ),
      );
      items.add(const PopupMenuDivider());
    }

    // Load profiles synchronously (count is sync, but we need the list)
    // We'll use a cached approach - load profiles when menu opens
    // For now, use synchronous profile count to know if we have profiles
    final profileCount = providers_api.modelProviderProfileCount();
    if (profileCount > 0) {
      // We can't async inside itemBuilder, but we can load eagerly
      // and cache. For simplicity, show a "switch" hint with profiles
      // loaded at build time via initState
      _loadProfilesForMenu();
      if (_cachedProfiles != null) {
        for (final profile in _cachedProfiles!) {
          final model = profile.defaultModel ?? 'default';
          final displayName = profile.name ?? profile.id;
          final isCurrent =
              _currentProvider == profile.id && _currentModel == model;
          items.add(
            PopupMenuItem<_ModelChoice>(
              value: _ModelChoice(provider: profile.id, model: model),
              child: Row(
                children: [
                  if (isCurrent)
                    const Icon(Icons.check, size: 16, color: AppColors.primary)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          model,
                          style: TextStyle(fontSize: 11, color: c.textHint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    if (items.isEmpty) {
      items.add(
        PopupMenuItem<_ModelChoice>(
          enabled: false,
          child: Text(
            l10n.noProviderProfiles,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
        ),
      );
    }

    return items;
  }

  List<providers_api.ModelProviderProfileDto>? _cachedProfiles;

  void _loadProfilesForMenu() {
    // Eagerly load profiles
    providers_api.listModelProviderProfiles().then((profiles) {
      if (mounted) {
        setState(() => _cachedProfiles = profiles);
      }
    });
  }
}

class _ModelChoice {
  final String provider;
  final String model;
  const _ModelChoice({required this.provider, required this.model});
}

/// Agent selector button — allows binding a session to an agent workspace
class _AgentSelectorButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AgentSelectorButton> createState() =>
      _AgentSelectorButtonState();
}

class _AgentSelectorButtonState extends ConsumerState<_AgentSelectorButton> {
  @override
  void initState() {
    super.initState();
    // Ensure workspace list is loaded into provider
    ref.read(agentWorkspacesProvider.notifier).load();
  }

  Future<void> _switchAgent(String? workspaceId) async {
    final sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) return;

    if (workspaceId == null) {
      // Unbind — revert to default
      await ref.read(sessionAgentBindingProvider.notifier).unbind(sessionId);
    } else {
      await ref
          .read(sessionAgentBindingProvider.notifier)
          .bind(sessionId, workspaceId);
    }
    // Force session agent recreation on next message
    await agent_api.removeSessionAgent(sessionId: sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(agentWorkspacesProvider);
    final activeAgentId = ref.watch(activeSessionAgentProvider);
    final sessionProject = ref.watch(activeSessionProjectProvider);

    // Find active workspace name
    String displayName = l10n.agentSelectorDefault;
    String displayEmoji = '🤖';
    if (activeAgentId != null) {
      final ws = workspaces
          .cast<workspace_api.AgentWorkspaceSummary?>()
          .firstWhere((w) => w?.id == activeAgentId, orElse: () => null);
      if (ws != null) {
        displayName = ws.name;
        displayEmoji = ws.avatar.isNotEmpty ? ws.avatar : '🤖';
      }
    }

    final truncated = displayName.length > 16
        ? '${displayName.substring(0, 14)}…'
        : displayName;

    // Show project icon prefix when in project session
    final isProjectSession = sessionProject != null;

    return PopupMenuButton<String?>(
      tooltip: l10n.agentSelectorTitle,
      offset: const Offset(0, -200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: c.surfaceBg,
      onSelected: (choice) => _switchAgent(choice),
      itemBuilder: (context) {
        ref.read(agentWorkspacesProvider.notifier).refresh(); // Refresh on open
        return _buildMenuItems(
          context,
          workspaces,
          activeAgentId,
          sessionProject,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: activeAgentId != null
              ? AppColors.primary.withValues(alpha: 0.12)
              : isProjectSession
              ? AppColors.primary.withValues(alpha: 0.06)
              : c.inputBg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isProjectSession) ...[
              Text(sessionProject.icon, style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 2),
            ],
            Text(displayEmoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              truncated,
              style: TextStyle(
                fontSize: 11,
                color: activeAgentId != null
                    ? AppColors.primary
                    : c.textSecondary,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: c.textHint),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String?>> _buildMenuItems(
    BuildContext context,
    List<workspace_api.AgentWorkspaceSummary> workspaces,
    String? activeAgentId,
    Project? sessionProject,
  ) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final items = <PopupMenuEntry<String?>>[];

    // Default (no agent)
    final isDefault = activeAgentId == null;
    items.add(
      PopupMenuItem<String?>(
        value: null,
        child: Row(
          children: [
            if (isDefault)
              const Icon(Icons.check, size: 16, color: AppColors.primary)
            else
              const SizedBox(width: 16),
            const SizedBox(width: 8),
            Text(
              l10n.agentSelectorDefault,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isDefault ? FontWeight.w600 : FontWeight.normal,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    // ── Project roles section ──
    if (sessionProject != null && sessionProject.hasRoles) {
      items.add(const PopupMenuDivider());
      // Section header
      items.add(
        PopupMenuItem<String?>(
          enabled: false,
          height: 28,
          child: Text(
            '${sessionProject.icon} ${sessionProject.name} roles',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );

      final projectRoleIds = sessionProject.roleIds.toSet();
      for (final roleId in sessionProject.roleIds) {
        final ws = workspaces
            .cast<workspace_api.AgentWorkspaceSummary?>()
            .firstWhere((w) => w?.id == roleId, orElse: () => null);
        if (ws == null) continue;

        final isCurrent = activeAgentId == ws.id;
        final isDefaultRole = sessionProject.defaultRoleId == ws.id;
        items.add(
          PopupMenuItem<String?>(
            value: ws.id,
            child: Row(
              children: [
                if (isCurrent)
                  const Icon(Icons.check, size: 16, color: AppColors.primary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  ws.avatar.isNotEmpty ? ws.avatar : '🤖',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ws.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: c.textPrimary,
                            ),
                          ),
                          if (isDefaultRole) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'default',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (ws.description.isNotEmpty)
                        Text(
                          ws.description,
                          style: TextStyle(fontSize: 11, color: c.textHint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Other workspaces section (non-project roles)
      final otherWorkspaces = workspaces
          .where((w) => w.enabled && !projectRoleIds.contains(w.id))
          .toList();
      if (otherWorkspaces.isNotEmpty) {
        items.add(const PopupMenuDivider());
        items.add(
          PopupMenuItem<String?>(
            enabled: false,
            height: 28,
            child: Text(
              l10n.agentSelectorTitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.textHint,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
        for (final ws in otherWorkspaces) {
          final isCurrent = activeAgentId == ws.id;
          items.add(_buildWorkspaceMenuItem(ws, isCurrent, c));
        }
      }
    } else {
      // ── No project: show all workspaces flat ──
      if (workspaces.isNotEmpty) {
        items.add(const PopupMenuDivider());
      }

      // Enabled workspaces
      for (final ws in workspaces.where((w) => w.enabled)) {
        final isCurrent = activeAgentId == ws.id;
        items.add(_buildWorkspaceMenuItem(ws, isCurrent, c));
      }

      if (workspaces.where((w) => w.enabled).isEmpty) {
        items.add(
          PopupMenuItem<String?>(
            enabled: false,
            child: Text(
              l10n.agentWorkspaceNoWorkspaces,
              style: TextStyle(fontSize: 12, color: c.textHint),
            ),
          ),
        );
      }
    }

    return items;
  }

  PopupMenuItem<String?> _buildWorkspaceMenuItem(
    workspace_api.AgentWorkspaceSummary ws,
    bool isCurrent,
    CoralDeskColors c,
  ) {
    return PopupMenuItem<String?>(
      value: ws.id,
      child: Row(
        children: [
          if (isCurrent)
            const Icon(Icons.check, size: 16, color: AppColors.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(
            ws.avatar.isNotEmpty ? ws.avatar : '🤖',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ws.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: c.textPrimary,
                  ),
                ),
                if (ws.description.isNotEmpty)
                  Text(
                    ws.description,
                    style: TextStyle(fontSize: 11, color: c.textHint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-agent mode toggle button.
/// Shows a team icon and lets the user enable/disable multi-agent mode
/// with role selection.
class _MultiAgentToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CoralDeskColors.of(context);
    final isMulti = ref.watch(isMultiAgentProvider);

    return Tooltip(
      message: isMulti ? 'Multi-agent ON' : 'Multi-agent',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showRoleSheet(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isMulti
                ? AppColors.primary.withValues(alpha: 0.12)
                : c.inputBg,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.groups_outlined,
                size: 16,
                color: isMulti ? AppColors.primary : c.textSecondary,
              ),
              if (isMulti) ...[
                const SizedBox(width: 4),
                Text(
                  'Team',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleSheet(BuildContext context, WidgetRef ref) async {
    var activeId = ref.read(activeSessionIdProvider);
    // Create a session if none exists
    if (activeId == null) {
      activeId = ref.read(chatControllerProvider).createSession();
    }

    final sessions = ref.read(sessionsProvider);
    final session = sessions.where((s) => s.id == activeId).firstOrNull;
    final currentRoles = List<String>.from(session?.activeRoles ?? []);
    final isMulti = session?.isMultiAgent ?? false;

    // Fetch preset workspaces from Rust
    final workspaces = await workspace_api.listAgentWorkspaces();
    final presetWorkspaces = workspaces
        .where((w) => w.isPreset && w.enabled)
        .toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return _MultiAgentDialog(
          workspaces: presetWorkspaces,
          initialRoles: currentRoles,
          initialEnabled: isMulti,
          onConfirm: (enabled, roleIds) {
            ref
                .read(sessionsProvider.notifier)
                .setMultiAgent(activeId!, enabled, roleIds);
          },
        );
      },
    );
  }
}

/// Dialog for toggling multi-agent mode and selecting role workspaces.
class _MultiAgentDialog extends StatefulWidget {
  final List<workspace_api.AgentWorkspaceSummary> workspaces;
  final List<String> initialRoles;
  final bool initialEnabled;
  final void Function(bool enabled, List<String> roles) onConfirm;

  const _MultiAgentDialog({
    required this.workspaces,
    required this.initialRoles,
    required this.initialEnabled,
    required this.onConfirm,
  });

  @override
  State<_MultiAgentDialog> createState() => _MultiAgentDialogState();
}

class _MultiAgentDialogState extends State<_MultiAgentDialog> {
  late bool _enabled;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    _selected = widget.initialRoles.isNotEmpty
        ? widget.initialRoles.toSet()
        : widget.workspaces.map((w) => w.id).toSet(); // default: all presets
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF6C757D);
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) return Color(int.parse('FF$cleaned', radix: 16));
    if (cleaned.length == 8) return Color(int.parse(cleaned, radix: 16));
    return const Color(0xFF6C757D);
  }

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.groups, size: 22),
          const SizedBox(width: 8),
          const Text('Multi-Agent Mode', style: TextStyle(fontSize: 16)),
          const Spacer(),
          Switch(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected))
                return AppColors.primary;
              return null;
            }),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select which agent workspaces participate in this session. '
              'Each workspace has its own skills, tools, and MCP servers.',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            if (widget.workspaces.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No preset workspaces found. They will be created on next app restart.',
                  style: TextStyle(color: c.textHint),
                ),
              )
            else
              ...widget.workspaces.map((ws) {
                final isChecked = _selected.contains(ws.id);
                final color = _parseColor(ws.colorTag);
                return CheckboxListTile(
                  value: isChecked,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: color,
                  title: Row(
                    children: [
                      Text(ws.avatar, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ws.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      // Capability counts
                      if (ws.allowedSkillsCount > 0 ||
                          ws.allowedToolsCount > 0 ||
                          ws.allowedMcpServersCount > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ws.allowedSkillsCount > 0)
                              _badge('S:${ws.allowedSkillsCount}', c),
                            if (ws.allowedToolsCount > 0)
                              _badge('T:${ws.allowedToolsCount}', c),
                            if (ws.allowedMcpServersCount > 0)
                              _badge('M:${ws.allowedMcpServersCount}', c),
                          ],
                        ),
                    ],
                  ),
                  subtitle: Text(
                    ws.description,
                    style: TextStyle(fontSize: 11, color: c.textHint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: _enabled
                      ? (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(ws.id);
                            } else {
                              _selected.remove(ws.id);
                            }
                          });
                        }
                      : null,
                );
              }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onConfirm(_enabled, _selected.toList());
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _badge(String text, CoralDeskColors c) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: c.textHint)),
    );
  }
}

/// Attachment button with popup menu for adding files or folders
class _AttachmentButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<String>(
      tooltip: l10n.attachFile,
      icon: Icon(Icons.attach_file, size: 16, color: c.textHint),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      offset: const Offset(0, -120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: c.surfaceBg,
      onSelected: (value) async {
        switch (value) {
          case 'file':
            await _pickFiles(ref);
            break;
          case 'folder':
            await _pickFolder(ref);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'file',
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 18,
                color: c.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(l10n.addFiles),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'folder',
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: c.textSecondary),
              const SizedBox(width: 8),
              Text(l10n.addFolder),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFiles(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();
    if (paths.isEmpty) return;

    var sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) {
      sessionId = ref.read(sessionsProvider.notifier).createSession();
      ref.read(activeSessionIdProvider.notifier).state = sessionId;
    }
    ref.read(sessionFilesProvider.notifier).addFiles(sessionId, paths);
  }

  Future<void> _pickFolder(WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null || result.isEmpty) return;

    var sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) {
      sessionId = ref.read(sessionsProvider.notifier).createSession();
      ref.read(activeSessionIdProvider.notifier).state = sessionId;
    }
    ref.read(sessionFilesProvider.notifier).addFiles(sessionId, [result]);
  }
}
