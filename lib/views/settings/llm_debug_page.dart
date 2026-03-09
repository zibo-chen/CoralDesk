import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:coraldesk/src/rust/api/llm_debug_api.dart' as llm_debug_api;

/// LLM Debug page — inspect full prompts sent to LLM and their responses
/// for context engineering optimization.
class LlmDebugPage extends ConsumerStatefulWidget {
  const LlmDebugPage({super.key});

  @override
  ConsumerState<LlmDebugPage> createState() => _LlmDebugPageState();
}

class _LlmDebugPageState extends ConsumerState<LlmDebugPage> {
  List<llm_debug_api.LlmDebugEntryDto> _entries = [];
  llm_debug_api.LlmDebugEntryDto? _selectedEntry;
  bool _loading = true;
  bool _debugEnabled = false;
  String? _logPath;
  int _selectedMessageIndex = -1;

  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _debugEnabled = llm_debug_api.isLlmDebugEnabled();
    _logPath = llm_debug_api.getLlmDebugLogPath();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final entries = await llm_debug_api.getLlmDebugEntries(
        limit: 200,
        sessionFilter: '',
      );
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
          // Keep selection if still valid
          if (_selectedEntry != null) {
            final stillExists = entries.any((e) => e.id == _selectedEntry!.id);
            if (!stillExists) _selectedEntry = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _toggleDebug(bool value) {
    llm_debug_api.setLlmDebugEnabled(enabled: value);
    setState(() => _debugEnabled = value);
  }

  Future<void> _clearEntries() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Debug Log'),
        content: const Text(
          'This will delete all recorded LLM call entries. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await llm_debug_api.clearLlmDebugEntries();
      setState(() {
        _entries = [];
        _selectedEntry = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'LLM Debug',
      icon: Icons.bug_report_outlined,
      isLoading: _loading,
      useScrollView: false,
      actions: [
        // Enable/disable toggle
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _debugEnabled ? 'Enabled' : 'Disabled',
              style: TextStyle(
                color: _debugEnabled ? AppColors.success : c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 24,
              child: Switch(
                value: _debugEnabled,
                onChanged: _toggleDebug,
                activeTrackColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Refresh button
        IconButton(
          icon: Icon(Icons.refresh, size: 18, color: c.textSecondary),
          onPressed: _loadEntries,
          tooltip: 'Refresh',
          splashRadius: 16,
        ),
        // Clear button
        IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: c.textSecondary),
          onPressed: _entries.isEmpty ? null : _clearEntries,
          tooltip: 'Clear Log',
          splashRadius: 16,
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_debugEnabled && _entries.isEmpty) {
      return _buildEmptyState();
    }
    return Row(
      children: [
        // Left: Entry list
        SizedBox(width: 360, child: _buildEntryList()),
        // Divider
        Container(width: 1, color: c.chatListBorder),
        // Right: Detail view
        Expanded(
          child: _selectedEntry != null
              ? _buildDetailView(_selectedEntry!)
              : _buildNoSelection(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bug_report_outlined, size: 48, color: c.textHint),
          const SizedBox(height: 16),
          Text(
            'LLM Debug Logging',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable debug logging to capture full LLM request/response payloads.\n'
            'This helps you inspect and optimize your context engineering.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _toggleDebug(true),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Enable Debug Logging'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          if (_logPath != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              'Log: $_logPath',
              style: TextStyle(
                color: c.textHint,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoSelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_back, size: 32, color: c.textHint),
          const SizedBox(height: 12),
          Text(
            'Select an entry to view details',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList() {
    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, size: 32, color: c.textHint),
              const SizedBox(height: 12),
              Text(
                _debugEnabled
                    ? 'No entries yet.\nSend a message to start recording.'
                    : 'Debug logging is disabled.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isSelected = _selectedEntry?.id == entry.id;
        return _buildEntryTile(entry, isSelected);
      },
    );
  }

  Widget _buildEntryTile(
    llm_debug_api.LlmDebugEntryDto entry,
    bool isSelected,
  ) {
    final totalChars = entry.requestMessages.fold<int>(
      0,
      (sum, m) => sum + m.charCount,
    );
    final msgCount = entry.requestMessages.length;
    final hasToolCalls = entry.responseToolCalls.isNotEmpty;

    // Parse timestamp
    String timeStr;
    try {
      final dt = DateTime.parse(entry.timestamp).toLocal();
      timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      timeStr = entry.timestamp;
    }

    final inputTokens = entry.inputTokens?.toInt() ?? 0;
    final outputTokens = entry.outputTokens?.toInt() ?? 0;
    final durationMs = entry.durationMs?.toInt();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedEntry = entry;
          _selectedMessageIndex = -1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? c.sidebarActiveBg : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: c.chatListBorder, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: time + model
            Row(
              children: [
                Icon(
                  entry.success ? Icons.check_circle : Icons.error,
                  size: 14,
                  color: entry.success ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                if (durationMs != null)
                  Text(
                    '${durationMs}ms',
                    style: TextStyle(
                      fontSize: 10,
                      color: c.textHint,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Model name
            Text(
              entry.model,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Stats row
            Row(
              children: [
                _statBadge('$msgCount msgs', Icons.message, c),
                const SizedBox(width: 6),
                _statBadge(_formatChars(totalChars), Icons.text_fields, c),
                if (inputTokens > 0 || outputTokens > 0) ...[
                  const SizedBox(width: 6),
                  _statBadge(
                    '${_formatTokens(inputTokens)}→${_formatTokens(outputTokens)}',
                    Icons.token,
                    c,
                  ),
                ],
                if (hasToolCalls) ...[
                  const SizedBox(width: 6),
                  _statBadge(
                    '${entry.responseToolCalls.length} tools',
                    Icons.build,
                    c,
                  ),
                ],
              ],
            ),
            if (entry.error.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.error,
                style: const TextStyle(fontSize: 11, color: AppColors.error),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBadge(String text, IconData icon, CoralDeskColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c.textHint),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: c.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(llm_debug_api.LlmDebugEntryDto entry) {
    return Column(
      children: [
        // Header bar
        _buildDetailHeader(entry),
        const Divider(height: 1),
        // Content
        Expanded(
          child: Row(
            children: [
              // Message list
              SizedBox(width: 200, child: _buildMessageList(entry)),
              Container(width: 1, color: c.chatListBorder),
              // Message content
              Expanded(
                child:
                    _selectedMessageIndex >= 0 &&
                        _selectedMessageIndex < entry.requestMessages.length
                    ? _buildMessageContent(
                        entry.requestMessages[_selectedMessageIndex],
                      )
                    : _selectedMessageIndex == -2
                    ? _buildResponseContent(entry)
                    : _buildOverview(entry),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailHeader(llm_debug_api.LlmDebugEntryDto entry) {
    final inputTokens = entry.inputTokens?.toInt() ?? 0;
    final outputTokens = entry.outputTokens?.toInt() ?? 0;
    final durationMs = entry.durationMs?.toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: c.surfaceBg,
      child: Row(
        children: [
          Icon(
            entry.success ? Icons.check_circle : Icons.error,
            size: 16,
            color: entry.success ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.provider} / ${entry.model}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Iteration ${entry.iteration + 1} · '
                  'Temp ${entry.temperature.toStringAsFixed(1)} · '
                  '${entry.requestMessages.length} messages · '
                  '${inputTokens > 0 ? "$inputTokens in / $outputTokens out" : "no token info"}'
                  '${durationMs != null ? " · ${durationMs}ms" : ""}'
                  '${entry.stopReason.isNotEmpty ? " · stop: ${entry.stopReason}" : ""}',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (entry.toolNames.isNotEmpty)
            Tooltip(
              message: 'Tools: ${entry.toolNames.join(", ")}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${entry.toolNames.length} tools',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList(llm_debug_api.LlmDebugEntryDto entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Request Messages',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: entry.requestMessages.length + 1, // +1 for response
            itemBuilder: (context, index) {
              if (index < entry.requestMessages.length) {
                final msg = entry.requestMessages[index];
                final isSelected = _selectedMessageIndex == index;
                return _buildMessageListItem(
                  index: index,
                  role: msg.role,
                  charCount: msg.charCount,
                  isSelected: isSelected,
                );
              } else {
                // Response item
                final isSelected = _selectedMessageIndex == -2;
                return _buildMessageListItem(
                  index: -2,
                  role: 'response',
                  charCount: entry.responseText.length,
                  isSelected: isSelected,
                  isResponse: true,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageListItem({
    required int index,
    required String role,
    required int charCount,
    required bool isSelected,
    bool isResponse = false,
  }) {
    final roleColors = {
      'system': const Color(0xFF9C27B0),
      'user': AppColors.primary,
      'assistant': AppColors.success,
      'tool': AppColors.warning,
      'response': const Color(0xFF00BCD4),
    };

    final roleIcons = {
      'system': Icons.settings_suggest,
      'user': Icons.person,
      'assistant': Icons.smart_toy,
      'tool': Icons.build,
      'response': Icons.reply_all,
    };

    final color = roleColors[role] ?? c.textSecondary;
    final icon = roleIcons[role] ?? Icons.message;

    return InkWell(
      onTap: () {
        setState(() => _selectedMessageIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isResponse
                        ? 'LLM Response'
                        : '${_capitalize(role)} ${isResponse ? "" : "#${index + 1}"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    _formatChars(charCount),
                    style: TextStyle(
                      fontSize: 10,
                      color: c.textHint,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(llm_debug_api.LlmDebugEntryDto entry) {
    final totalChars = entry.requestMessages.fold<int>(
      0,
      (s, m) => s + m.charCount,
    );
    final roleCounts = <String, int>{};
    final roleChars = <String, int>{};
    for (final msg in entry.requestMessages) {
      roleCounts[msg.role] = (roleCounts[msg.role] ?? 0) + 1;
      roleChars[msg.role] = (roleChars[msg.role] ?? 0) + msg.charCount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Context composition
          Text(
            'Context Composition',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...roleCounts.entries.map((e) {
            final pct = roleChars[e.key]! / totalChars * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCompositionBar(
                label: _capitalize(e.key),
                chars: roleChars[e.key]!,
                count: e.value,
                percentage: pct,
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total context: ${_formatChars(totalChars)} across ${entry.requestMessages.length} messages',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (entry.responseText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Response: ${_formatChars(entry.responseText.length)}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
                if (entry.toolNames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tools available: ${entry.toolNames.join(", ")}',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textHint,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Click a message on the left to inspect its full content.',
            style: TextStyle(
              fontSize: 12,
              color: c.textHint,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionBar({
    required String label,
    required int chars,
    required int count,
    required double percentage,
  }) {
    final roleColors = {
      'System': const Color(0xFF9C27B0),
      'User': AppColors.primary,
      'Assistant': AppColors.success,
      'Tool': AppColors.warning,
    };
    final color = roleColors[label] ?? c.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '$label ($count msgs · ${_formatChars(chars)})',
              style: TextStyle(fontSize: 12, color: c.textPrimary),
            ),
            const Spacer(),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                color: c.textHint,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: c.inputBg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageContent(llm_debug_api.LlmDebugMessageDto msg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: c.inputBg,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _roleColor(msg.role).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  msg.role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _roleColor(msg.role),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatChars(msg.charCount),
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              const Spacer(),
              // Copy button
              IconButton(
                icon: Icon(Icons.copy, size: 16, color: c.textSecondary),
                onPressed: () {
                  _copyToClipboard(msg.content);
                },
                tooltip: 'Copy content',
                splashRadius: 14,
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 12,
                  color: c.textPrimary,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponseContent(llm_debug_api.LlmDebugEntryDto entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: c.inputBg,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LLM RESPONSE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00BCD4),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatChars(entry.responseText.length),
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              if (entry.responseToolCalls.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.responseToolCalls.length} tool calls',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: Icon(Icons.copy, size: 16, color: c.textSecondary),
                onPressed: () {
                  _copyToClipboard(entry.responseText);
                },
                tooltip: 'Copy response',
                splashRadius: 14,
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.responseText.isNotEmpty)
                    Text(
                      entry.responseText,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textPrimary,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  if (entry.responseToolCalls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tool Calls:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...entry.responseToolCalls.map(
                      (tc) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.inputBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.inputBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tc.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tc.arguments,
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary,
                                fontFamily: 'monospace',
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (entry.error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Error: ${entry.error}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 200,
      ),
    );
  }

  Color _roleColor(String role) {
    return switch (role) {
      'system' => const Color(0xFF9C27B0),
      'user' => AppColors.primary,
      'assistant' => AppColors.success,
      'tool' => AppColors.warning,
      _ => c.textSecondary,
    };
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _formatChars(int chars) {
    if (chars < 1000) return '${chars}c';
    if (chars < 1000000) return '${(chars / 1000).toStringAsFixed(1)}K';
    return '${(chars / 1000000).toStringAsFixed(1)}M';
  }

  static String _formatTokens(int tokens) {
    if (tokens < 1000) return '$tokens';
    if (tokens < 1000000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '${(tokens / 1000000).toStringAsFixed(1)}M';
  }
}
