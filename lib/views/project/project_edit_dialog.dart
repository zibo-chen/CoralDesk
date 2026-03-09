import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/desktop_dialog.dart';
import 'package:coraldesk/views/project/projects_page.dart'
    show projectTypeIcon;

/// Edit dialog for an existing project
class ProjectEditDialog extends ConsumerStatefulWidget {
  const ProjectEditDialog({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends ConsumerState<ProjectEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _dirCtrl;
  late String _colorTag;
  late ProjectType _type;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project.name);
    _descCtrl = TextEditingController(text: widget.project.description);
    _dirCtrl = TextEditingController(text: widget.project.projectDir);
    _colorTag = widget.project.colorTag;
    _type = widget.project.projectType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  final _colorOptions = [
    '#5B6ABF',
    '#4A90D9',
    '#50C878',
    '#E74C3C',
    '#F39C12',
    '#9B59B6',
    '#1ABC9C',
    '#E67E22',
  ];

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final updated = widget.project.copyWith(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      colorTag: _colorTag,
      projectType: _type,
      projectDir: _dirCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    final ok = await ref.read(projectsProvider.notifier).updateProject(updated);
    if (!mounted) return;
    Navigator.pop(context, ok);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = CoralDeskColors.of(context);

    return DesktopDialog(
      title: l10n.projectEdit,
      icon: Icons.edit_outlined,
      width: 520,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project name
            _sectionLabel(c, l10n.projectName),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.projectNameHint,
                filled: true,
                fillColor: c.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.inputBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            _sectionLabel(c, l10n.projectDescription),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.projectDescriptionHint,
                filled: true,
                fillColor: c.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.inputBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Project type
            _sectionLabel(c, l10n.projectType),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ProjectType.values.map((type) {
                final selected = _type == type;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _type = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : c.inputBorder.withValues(alpha: 0.5),
                          width: selected ? 1.5 : 1,
                        ),
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            projectTypeIcon(type),
                            size: 16,
                            color: selected
                                ? AppColors.primary
                                : c.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? AppColors.primary
                                  : c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Color
            _sectionLabel(c, l10n.projectColor),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((hex) {
                final selected = _colorTag == hex;
                final color = _parseHex(hex);
                return GestureDetector(
                  onTap: () => setState(() => _colorTag = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Directory
            _sectionLabel(c, l10n.projectDirectory),
            const SizedBox(height: 6),
            TextField(
              controller: _dirCtrl,
              decoration: InputDecoration(
                hintText: l10n.projectDirectoryHint,
                filled: true,
                fillColor: c.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.inputBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon: Icon(
                  Icons.folder_open_outlined,
                  size: 18,
                  color: c.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _sectionLabel(CoralDeskColors c, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
    );
  }

  Color _parseHex(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
