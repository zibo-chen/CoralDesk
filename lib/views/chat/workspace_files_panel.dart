import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/constants.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;

/// A slide-out panel showing files in the session's workspace directory.
class WorkspaceFilesPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const WorkspaceFilesPanel({super.key, required this.onClose});

  @override
  ConsumerState<WorkspaceFilesPanel> createState() =>
      _WorkspaceFilesPanelState();
}

class _WorkspaceFilesPanelState extends ConsumerState<WorkspaceFilesPanel> {
  List<agent_api.SessionFileEntry>? _files;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) {
      setState(() {
        _files = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final files = await agent_api.listSessionWorkspaceFiles(
      sessionId: sessionId,
    );
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  Future<void> _openFile(String path) async {
    await agent_api.openInSystem(path: path);
  }

  Future<void> _saveFileAs(
    String srcPath,
    String fileName,
    AppLocalizations l10n,
  ) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: l10n.saveFileAs,
      fileName: fileName,
    );
    if (result == null) return;
    final res = await agent_api.copyFileTo(src: srcPath, dst: result);
    if (!mounted) return;
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
  }

  Future<void> _openWorkspaceFolder() async {
    final sessionId = ref.read(activeSessionIdProvider);
    if (sessionId == null) return;
    final dir = await agent_api.getSessionWorkspaceDir(sessionId: sessionId);
    await agent_api.openInSystem(path: dir);
  }

  IconData _iconForName(String name, bool isDir) {
    if (isDir) return Icons.folder_outlined;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'dart' ||
      'rs' ||
      'py' ||
      'js' ||
      'ts' ||
      'java' ||
      'kt' ||
      'go' ||
      'c' ||
      'cpp' ||
      'h' ||
      'swift' => Icons.code,
      'json' || 'yaml' || 'yml' || 'toml' || 'xml' => Icons.data_object,
      'md' || 'txt' || 'csv' || 'log' => Icons.description_outlined,
      'png' ||
      'jpg' ||
      'jpeg' ||
      'gif' ||
      'svg' ||
      'webp' => Icons.image_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'zip' || 'tar' || 'gz' || '7z' => Icons.folder_zip_outlined,
      'html' || 'css' => Icons.web,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Listen for session changes to refresh
    ref.listen(activeSessionIdProvider, (prev, next) {
      if (prev != next) _refresh();
    });

    // On Windows/Linux the absolute-positioned window controls overlap
    // the top-right corner, so add extra top padding to push content below.
    final isDesktopNotMac = AppConstants.isDesktop && !AppConstants.isMacOS;
    final topInset = isDesktopNotMac ? AppConstants.windowControlHeight : 0.0;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: c.surfaceBg,
        border: Border(left: BorderSide(color: c.chatListBorder, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: AppConstants.titleBarHeight + topInset,
            padding: EdgeInsets.only(left: 16, right: 16, top: topInset),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: c.chatListBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 18, color: c.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.workspaceFiles,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 18, color: c.textSecondary),
                  tooltip: l10n.refreshFiles,
                  onPressed: _refresh,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.folder_outlined,
                    size: 18,
                    color: c.textSecondary,
                  ),
                  tooltip: l10n.openWorkspaceFolder,
                  onPressed: _openWorkspaceFolder,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: c.textSecondary),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _files == null || _files!.isEmpty
                ? _buildEmptyState(c, l10n)
                : _buildFileList(c, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(CoralDeskColors c, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off_outlined, size: 40, color: c.textHint),
          const SizedBox(height: 12),
          Text(
            l10n.noWorkspaceFiles,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.noWorkspaceFilesHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(CoralDeskColors c, AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _files!.length,
      itemBuilder: (context, index) {
        final file = _files![index];
        return _FileListTile(
          file: file,
          icon: _iconForName(file.name, file.isDir),
          sizeLabel: file.isDir ? '' : _formatSize(file.size.toInt()),
          onOpen: () => _openFile(file.path),
          onSaveAs: file.isDir
              ? null
              : () => _saveFileAs(file.path, file.name, l10n),
          colors: c,
          l10n: l10n,
        );
      },
    );
  }
}

class _FileListTile extends StatefulWidget {
  final agent_api.SessionFileEntry file;
  final IconData icon;
  final String sizeLabel;
  final VoidCallback onOpen;
  final VoidCallback? onSaveAs;
  final CoralDeskColors colors;
  final AppLocalizations l10n;

  const _FileListTile({
    required this.file,
    required this.icon,
    required this.sizeLabel,
    required this.onOpen,
    this.onSaveAs,
    required this.colors,
    required this.l10n,
  });

  @override
  State<_FileListTile> createState() => _FileListTileState();
}

class _FileListTileState extends State<_FileListTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        color: _hovering ? c.chatListBorder.withValues(alpha: 0.3) : null,
        child: InkWell(
          onTap: widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: c.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.file.name,
                        style: TextStyle(fontSize: 13, color: c.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.sizeLabel.isNotEmpty)
                        Text(
                          widget.sizeLabel,
                          style: TextStyle(fontSize: 11, color: c.textHint),
                        ),
                    ],
                  ),
                ),
                if (_hovering) ...[
                  if (widget.onSaveAs != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        icon: Icon(
                          Icons.save_alt,
                          size: 16,
                          color: c.textSecondary,
                        ),
                        tooltip: widget.l10n.saveFileAs,
                        onPressed: widget.onSaveAs,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
