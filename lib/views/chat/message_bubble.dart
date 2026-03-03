import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;

/// Individual message bubble with hover-based action bar (copy / edit).
class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  /// Called when the user confirms an edit on their own message.
  /// Passes the new text back to the parent (ChatView) for re-send.
  final ValueChanged<String>? onEdit;

  const MessageBubble({super.key, required this.message, this.onEdit});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _hovering = false;
  bool _editing = false;
  late TextEditingController _editController;

  ChatMessage get message => widget.message;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: message.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: message.content));
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.copiedToClipboard),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startEditing() {
    _editController.text = message.content;
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  void _confirmEditing() {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    setState(() => _editing = false);
    widget.onEdit?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    }
    return _buildAssistantBubble(context);
  }

  // ── User bubble ────────────────────────────────────────

  Widget _buildUserBubble(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Flexible(
                  flex: 8,
                  child: _editing
                      ? _buildEditField(c, l10n)
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              16,
                            ).copyWith(bottomRight: const Radius.circular(4)),
                          ),
                          child: SelectableText(
                            message.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                _buildAvatar(
                  icon: Icons.person,
                  bgColor: AppColors.primaryLight,
                ),
              ],
            ),
            // Hover action bar
            if (_hovering && !_editing)
              Padding(
                padding: const EdgeInsets.only(right: 44, top: 4),
                child: _buildActionBar(c, l10n, isUser: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(CoralDeskColors c, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _editController,
            maxLines: null,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: c.textPrimary, height: 1.5),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintStyle: TextStyle(color: c.textHint),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _cancelEditing,
                style: TextButton.styleFrom(
                  foregroundColor: c.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  l10n.cancelEdit,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _confirmEditing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.saveEdit,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Assistant bubble ───────────────────────────────────

  Widget _buildAssistantBubble(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(icon: Icons.pets, bgColor: c.textPrimary),
                const SizedBox(width: 8),
                Flexible(
                  flex: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceBg,
                      borderRadius: BorderRadius.circular(
                        16,
                      ).copyWith(bottomLeft: const Radius.circular(4)),
                      border: Border.all(color: c.chatListBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tool calls if any (expandable)
                        if (message.toolCalls != null) ...[
                          for (final tc in message.toolCalls!)
                            _ToolCallCard(toolCall: tc),
                          const SizedBox(height: 8),
                        ],

                        // Message content
                        if (message.content.isNotEmpty)
                          MarkdownBody(
                            data: message.content,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: c.textPrimary,
                              ),
                              code: TextStyle(
                                fontSize: 13,
                                backgroundColor: c.inputBg,
                                color: AppColors.primaryDark,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: c.inputBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              strong: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              listBullet: TextStyle(
                                fontSize: 14,
                                color: c.textPrimary,
                              ),
                            ),
                            selectable: true,
                          ),

                        // Streaming indicator
                        if (message.isStreaming)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildStreamingDots(),
                          ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
            // Hover action bar
            if (_hovering && !message.isStreaming)
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 4),
                child: _buildActionBar(c, l10n, isUser: false),
              ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────

  Widget _buildActionBar(
    CoralDeskColors c,
    AppLocalizations l10n, {
    required bool isUser,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.chatListBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionButton(
            icon: Icons.copy_outlined,
            tooltip: l10n.copyMessage,
            onTap: _copyContent,
            c: c,
          ),
          if (isUser && widget.onEdit != null)
            _actionButton(
              icon: Icons.edit_outlined,
              tooltip: l10n.editMessage,
              onTap: _startEditing,
              c: c,
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required CoralDeskColors c,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: c.textSecondary),
        ),
      ),
    );
  }

  Widget _buildAvatar({required IconData icon, required Color bgColor}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  Widget _buildStreamingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0),
        const SizedBox(width: 4),
        _dot(1),
        const SizedBox(width: 4),
        _dot(2),
      ],
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }
}

/// Expandable tool call card showing name, status, arguments, and result
class _ToolCallCard extends StatefulWidget {
  final ToolCallInfo toolCall;

  const _ToolCallCard({required this.toolCall});

  @override
  State<_ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<_ToolCallCard> {
  bool _expanded = false;

  ToolCallInfo get toolCall => widget.toolCall;

  /// Tool names that produce files
  static const _fileToolNames = {
    'file_write',
    'write_file',
    'filewrite',
    'writefile',
    'file_edit',
    'edit_file',
    'fileedit',
    'editfile',
  };

  /// Try to extract the file path from tool call arguments
  String? get _filePath {
    if (!_fileToolNames.contains(toolCall.name)) return null;
    if (toolCall.success != true) return null;
    try {
      final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
      return args['path'] as String?;
    } catch (_) {
      return null;
    }
  }

  Color _statusColor(CoralDeskColors c) => switch (toolCall.status) {
    ToolCallStatus.pending => c.textHint,
    ToolCallStatus.running => AppColors.warning,
    ToolCallStatus.completed => AppColors.success,
    ToolCallStatus.failed => AppColors.error,
  };

  IconData get _statusIcon => switch (toolCall.status) {
    ToolCallStatus.pending => Icons.hourglass_empty,
    ToolCallStatus.running => Icons.sync,
    ToolCallStatus.completed => Icons.check_circle,
    ToolCallStatus.failed => Icons.error,
  };

  /// Try to pretty-print JSON, fall back to raw string
  String _formatJson(String raw) {
    try {
      final obj = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final statusColor = _statusColor(c);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — always visible, clickable
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(_statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 8),
                  Icon(Icons.build, size: 14, color: c.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      toolCall.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (toolCall.result != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        toolCall.success == true
                            ? AppLocalizations.of(context)!.toolCallSuccess
                            : AppLocalizations.of(context)!.toolCallFailed,
                        style: TextStyle(fontSize: 12, color: statusColor),
                      ),
                    ),
                  // File action buttons for file-writing tools
                  if (_filePath != null) ...[
                    _FileActionButtons(filePath: _filePath!),
                    const SizedBox(width: 4),
                  ],
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 18, color: c.textHint),
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildDetails(c),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(CoralDeskColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Arguments section
          if (toolCall.arguments.isNotEmpty) ...[
            _buildSectionHeader(c, 'Arguments'),
            const SizedBox(height: 4),
            _buildCodeBlock(c, _formatJson(toolCall.arguments)),
          ],

          // Result section
          if (toolCall.result != null && toolCall.result!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSectionHeader(c, 'Result'),
            const SizedBox(height: 4),
            _buildCodeBlock(c, toolCall.result!),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(CoralDeskColors c, String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        // Copy button
        SizedBox(
          height: 22,
          width: 22,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 14,
            icon: Icon(Icons.copy, color: c.textHint),
            tooltip: title == 'Arguments' ? 'Copy arguments' : 'Copy result',
            onPressed: () {
              final text = title == 'Arguments'
                  ? _formatJson(toolCall.arguments)
                  : toolCall.result ?? '';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCodeBlock(CoralDeskColors c, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: c.mainBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.chatListBorder),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          content,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
            color: c.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Inline action buttons for file-producing tool calls (Open / Save as)
class _FileActionButtons extends StatelessWidget {
  final String filePath;

  const _FileActionButtons({required this.filePath});

  String get _fileName {
    final parts = filePath.split('/');
    return parts.isNotEmpty ? parts.last : filePath;
  }

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Open file
        SizedBox(
          height: 24,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11),
            ),
            icon: Icon(Icons.open_in_new, size: 13, color: AppColors.primary),
            label: Text(l10n.openFile),
            onPressed: () => agent_api.openInSystem(path: filePath),
          ),
        ),
        const SizedBox(width: 2),
        // Save as
        SizedBox(
          height: 24,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11),
            ),
            icon: Icon(Icons.save_alt, size: 13, color: c.textSecondary),
            label: Text(
              l10n.saveFileAs,
              style: TextStyle(color: c.textSecondary),
            ),
            onPressed: () async {
              final result = await FilePicker.platform.saveFile(
                dialogTitle: l10n.saveFileAs,
                fileName: _fileName,
              );
              if (result == null) return;
              final res = await agent_api.copyFileTo(
                src: filePath,
                dst: result,
              );
              if (!context.mounted) return;
              if (res.startsWith('error:')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.fileSaveFailed),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.fileSaved(res)),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
