import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';

/// Displays the list of attached files for the current session as chips.
/// Shown above the input bar when files are attached.
class FileAttachmentBar extends ConsumerWidget {
  const FileAttachmentBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(sessionFilesProvider);
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (files.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(40, 4, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: 14, color: c.textSecondary),
              const SizedBox(width: 4),
              Text(
                l10n.attachedFiles(files.length),
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  final sessionId = ref.read(activeSessionIdProvider);
                  if (sessionId != null) {
                    ref
                        .read(sessionFilesProvider.notifier)
                        .clearFiles(sessionId);
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    l10n.clearAll,
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: files.map((path) => _FileChip(path: path)).toList(),
          ),
        ],
      ),
    );
  }
}

class _FileChip extends ConsumerWidget {
  final String path;
  const _FileChip({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CoralDeskColors.of(context);
    final name = path.split(Platform.pathSeparator).last;
    final isDir = FileSystemEntity.isDirectorySync(path);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDir ? Icons.folder_outlined : _iconForFile(name),
            size: 14,
            color: isDir ? Colors.amber.shade700 : AppColors.primary,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Tooltip(
              message: path,
              child: Text(
                name,
                style: TextStyle(fontSize: 12, color: c.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              final sessionId = ref.read(activeSessionIdProvider);
              if (sessionId != null) {
                ref
                    .read(sessionFilesProvider.notifier)
                    .removeFile(sessionId, path);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Icon(Icons.close, size: 14, color: c.textHint),
          ),
        ],
      ),
    );
  }

  IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
      case 'rs':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'kt':
      case 'swift':
      case 'go':
      case 'c':
      case 'cpp':
      case 'h':
      case 'rb':
        return Icons.code;
      case 'md':
      case 'txt':
      case 'log':
      case 'csv':
        return Icons.description_outlined;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'toml':
      case 'xml':
        return Icons.data_object;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'webp':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
