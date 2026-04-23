import 'package:flutter/material.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/desktop_dialog.dart';
import 'package:coraldesk/views/project/projects_page.dart'
    show projectTypeIcon;

/// Result object from project create/edit dialogs
class ProjectFormResult {
  final String name;
  final String description;
  final String icon;
  final String colorTag;
  final ProjectType projectType;
  final String projectDir;

  ProjectFormResult({
    required this.name,
    required this.description,
    required this.icon,
    required this.colorTag,
    required this.projectType,
    required this.projectDir,
  });
}

/// Create project dialog with template selection and step-based UX
class ProjectCreateDialog extends StatefulWidget {
  const ProjectCreateDialog({super.key});

  @override
  State<ProjectCreateDialog> createState() => _ProjectCreateDialogState();
}

class _ProjectCreateDialogState extends State<ProjectCreateDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  String _icon = '📁';
  String _colorTag = '#5B6ABF';
  ProjectType _type = ProjectType.general;
  String _selectedTemplateId = 'blank';
  bool _showAdvanced = false;

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate(ProjectTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _icon = template.icon;
      _colorTag = template.colorTag;
      _type = template.projectType;
      if (template.id != 'blank') {
        _nameCtrl.text = template.name;
        _descCtrl.text = template.description;
      } else {
        _nameCtrl.clear();
        _descCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = CoralDeskColors.of(context);

    return DesktopDialog(
      title: l10n.projectCreate,
      icon: Icons.folder_outlined,
      width: 580,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template cards
            _sectionLabel(c, l10n.projectTemplate),
            const SizedBox(height: 8),
            _buildTemplateGrid(c),
            const SizedBox(height: 20),

            // Project name
            _sectionLabel(c, l10n.projectName),
            const SizedBox(height: 6),
            _buildTextField(
              _nameCtrl,
              l10n.projectNameHint,
              c,
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Description
            _sectionLabel(c, l10n.projectDescription),
            const SizedBox(height: 6),
            _buildTextField(
              _descCtrl,
              l10n.projectDescriptionHint,
              c,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Advanced section toggle
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _showAdvanced ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Advanced Options',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showAdvanced) ...[
              const SizedBox(height: 12),

              // Project type
              _sectionLabel(c, l10n.projectType),
              const SizedBox(height: 6),
              _buildTypeSelector(c),
              const SizedBox(height: 16),

              // Color selector
              _sectionLabel(c, l10n.projectColor),
              const SizedBox(height: 6),
              _buildColorSelector(c),
              const SizedBox(height: 16),

              // Project directory
              _sectionLabel(c, l10n.projectDirectory),
              const SizedBox(height: 6),
              _buildTextField(
                _dirCtrl,
                l10n.projectDirectoryHint,
                c,
                suffixIcon: Icons.folder_open_outlined,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              ProjectFormResult(
                name: _nameCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                icon: _icon,
                colorTag: _colorTag,
                projectType: _type,
                projectDir: _dirCtrl.text.trim(),
              ),
            );
          },
          child: Text(l10n.projectCreate),
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

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    CoralDeskColors c, {
    bool autofocus = false,
    int maxLines = 1,
    IconData? suffixIcon,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
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
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, size: 18, color: c.textHint)
            : null,
      ),
    );
  }

  Widget _buildTemplateGrid(CoralDeskColors c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 500 ? 170.0 : 140.0;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ProjectTemplate.all.map((tpl) {
            final selected = _selectedTemplateId == tpl.id;
            final color = _parseHex(tpl.colorTag);
            return GestureDetector(
              onTap: () => _applyTemplate(tpl),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: cardWidth,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : c.inputBorder.withValues(alpha: 0.5),
                    width: selected ? 2 : 1,
                  ),
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : Colors.transparent,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Icon(
                              tpl.id == 'blank'
                                  ? Icons.add
                                  : projectTypeIcon(tpl.projectType),
                              size: 16,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tpl.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.primary
                                  : c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (tpl.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tpl.description,
                        style: TextStyle(
                          fontSize: 10,
                          color: c.textHint,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTypeSelector(CoralDeskColors c) {
    return Wrap(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    color: selected ? AppColors.primary : c.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.primary : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector(CoralDeskColors c) {
    return Wrap(
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
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
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
