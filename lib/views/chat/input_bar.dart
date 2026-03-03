import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/constants.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';

/// Chat input bar at the bottom of the chat view
class ChatInputBar extends ConsumerStatefulWidget {
  final Function(String) onSend;

  const ChatInputBar({super.key, required this.onSend});

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
                      const Spacer(),
                      // Character count
                      Text(
                        '${_controller.text.length}/${AppConstants.maxInputLength}',
                        style: TextStyle(fontSize: 12, color: c.textHint),
                      ),
                      const SizedBox(width: 12),
                      // Send button
                      InkWell(
                        onTap:
                            _controller.text.trim().isNotEmpty && !isProcessing
                            ? _send
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color:
                                _controller.text.trim().isNotEmpty &&
                                    !isProcessing
                                ? AppColors.primary
                                : c.inputBg,
                          ),
                          child: Icon(
                            Icons.arrow_upward,
                            size: 18,
                            color:
                                _controller.text.trim().isNotEmpty &&
                                    !isProcessing
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
