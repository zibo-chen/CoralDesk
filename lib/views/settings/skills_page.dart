import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/src/rust/api/skills_api.dart' as skills_api;
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';

/// Skills management page - browse, install, remove, and configure skills
class SkillsPage extends ConsumerStatefulWidget {
  const SkillsPage({super.key});

  @override
  ConsumerState<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends ConsumerState<SkillsPage> {
  skills_api.SkillsConfigDto? _config;
  List<skills_api.SkillDto> _skills = [];
  bool _loading = true;
  bool _installing = false;
  String? _message;
  bool _isError = false;
  final _installController = TextEditingController();
  final _installFocus = FocusNode();
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _installController.dispose();
    _installFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final config = await skills_api.getSkillsConfig();
    final skills = await skills_api.listSkills();
    if (mounted) {
      setState(() {
        _config = config;
        _skills = skills;
        _loading = false;
      });
    }
  }

  Future<void> _toggleOpenSkills(bool enabled) async {
    final result = await skills_api.toggleOpenSkills(enabled: enabled);
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(
        AppLocalizations.of(context)!.communitySkillsToggled(
          enabled
              ? AppLocalizations.of(context)!.enabled
              : AppLocalizations.of(context)!.disabled,
        ),
        isError: false,
      );
      _loadAll();
    } else {
      _showMessage(
        '${AppLocalizations.of(context)!.operationFailed}: $result',
        isError: true,
      );
    }
  }

  Future<void> _updateInjectionMode(String mode) async {
    final result = await skills_api.updatePromptInjectionMode(mode: mode);
    if (!mounted) return;
    if (result == 'ok') {
      _showMessage(
        AppLocalizations.of(context)!.injectionModeUpdated(mode),
        isError: false,
      );
      _loadAll();
    } else {
      _showMessage(
        '${AppLocalizations.of(context)!.operationFailed}: $result',
        isError: true,
      );
    }
  }

  Future<void> _installSkill() async {
    final source = _installController.text.trim();
    if (source.isEmpty) return;

    setState(() => _installing = true);

    final result = await skills_api.installSkill(source: source);
    if (!mounted) return;

    if (result.startsWith('ok:')) {
      final name = result.substring(3);
      _installController.clear();
      _showMessage(
        AppLocalizations.of(context)!.skillInstalled(name),
        isError: false,
      );
      _loadAll();
    } else {
      final error = result.startsWith('error: ') ? result.substring(7) : result;
      _showMessage(
        AppLocalizations.of(context)!.installFailed(error),
        isError: true,
      );
    }

    setState(() => _installing = false);
  }

  Future<void> _removeSkill(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.removeSkillTitle),
        content: Text(AppLocalizations.of(ctx)!.removeSkillConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppLocalizations.of(ctx)!.removeSkill),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await skills_api.removeSkill(name: name);
    if (!mounted) return;

    if (result == 'ok') {
      _showMessage(
        AppLocalizations.of(context)!.skillRemoved(name),
        isError: false,
      );
      _loadAll();
    } else {
      final error = result.startsWith('error: ') ? result.substring(7) : result;
      _showMessage(
        AppLocalizations.of(context)!.removeFailed(error),
        isError: true,
      );
    }
  }

  void _showMessage(String msg, {required bool isError}) {
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
    return SettingsScaffold(
      title: AppLocalizations.of(context)!.pageSkills,
      icon: Icons.psychology,
      isLoading: _loading,
      actions: [
        if (_message != null)
          Flexible(
            child: StatusLabel(text: _message!, isError: _isError),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInstallSection(),
          const SizedBox(height: 24),
          _buildConfigSection(),
          const SizedBox(height: 24),
          _buildSkillsList(),
        ],
      ),
    );
  }

  // ─────────────── Install Section ───────────────────

  Widget _buildInstallSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.installSkill,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.supportedSources,
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _installController,
                  focusNode: _installFocus,
                  enabled: !_installing,
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(
                      context,
                    )!.installSkillPlaceholder,
                    hintStyle: TextStyle(fontSize: 12, color: c.textHint),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: c.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: c.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: c.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(Icons.link, size: 18, color: c.textHint),
                  ),
                  onSubmitted: (_) => _installSkill(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _installing ? null : _installSkill,
                  icon: _installing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(
                    _installing
                        ? AppLocalizations.of(context)!.installing
                        : AppLocalizations.of(context)!.installSkill,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildQuickInstallChip(
                'besoeasy/open-skills',
                'https://github.com/besoeasy/open-skills',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInstallChip(String label, String url) {
    return InkWell(
      onTap: _installing
          ? null
          : () {
              _installController.text = url;
              _installFocus.requestFocus();
            },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 12, color: c.textHint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: c.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection() {
    final config = _config;
    if (config == null) return const SizedBox.shrink();

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
              Icon(Icons.tune, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.skillsConfig,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary stats row
          Row(
            children: [
              _buildStatChip(
                AppLocalizations.of(context)!.localSkills,
                '${config.localSkillsCount}',
                Icons.folder_outlined,
                AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                AppLocalizations.of(context)!.communitySkills,
                '${config.communitySkillsCount}',
                Icons.public,
                config.openSkillsEnabled ? AppColors.success : c.textHint,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Open Skills toggle
          _buildToggleRow(
            AppLocalizations.of(context)!.openSourceSkills,
            AppLocalizations.of(context)!.openSourceSkillsDesc,
            config.openSkillsEnabled,
            _toggleOpenSkills,
          ),
          const SizedBox(height: 12),

          // Injection mode
          Text(
            AppLocalizations.of(context)!.promptInjectionMode,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildModeChip(
                'full',
                AppLocalizations.of(context)!.fullMode,
                AppLocalizations.of(context)!.fullModeDesc,
                config.promptInjectionMode,
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                'compact',
                AppLocalizations.of(context)!.compactMode,
                AppLocalizations.of(context)!.compactModeDesc,
                config.promptInjectionMode,
              ),
            ],
          ),

          if (config.skillsDir.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.folder_open, size: 14, color: c.textHint),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    config.skillsDir,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textHint,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillsList() {
    if (_skills.isEmpty) {
      return _buildEmptySkills();
    }

    // Group by source
    final localSkills = _skills.where((s) => s.source == 'local').toList();
    final communitySkills = _skills
        .where((s) => s.source == 'community')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (localSkills.isNotEmpty)
          _buildSkillGroup(
            AppLocalizations.of(context)!.localSkills,
            localSkills.length,
            Icons.folder,
            localSkills,
            AppColors.primary,
          ),
        if (communitySkills.isNotEmpty) ...[
          if (localSkills.isNotEmpty) const SizedBox(height: 24),
          _buildSkillGroup(
            AppLocalizations.of(context)!.communitySkills,
            communitySkills.length,
            Icons.public,
            communitySkills,
            AppColors.success,
          ),
        ],
      ],
    );
  }

  Widget _buildEmptySkills() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: c.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noSkillsAvailable,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noSkillsHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textHint),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.quickStartSkill,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '[skill]\n'
                  'name = "my-skill"\n'
                  'description = "技能描述"\n'
                  'version = "0.1.0"\n'
                  'tags = ["productivity"]\n'
                  '\n'
                  '[[tools]]\n'
                  'name = "my_tool"\n'
                  'description = "工具描述"\n'
                  'kind = "shell"\n'
                  'command = "echo hello"',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: c.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillGroupHeader(
    String title,
    int count,
    IconData icon, {
    Color? color,
  }) {
    final displayColor = color ?? AppColors.primary;
    return Row(
      children: [
        Icon(icon, size: 18, color: displayColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: displayColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: displayColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillGroup(
    String title,
    int count,
    IconData icon,
    List<skills_api.SkillDto> skills,
    Color color,
  ) {
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
          _buildSkillGroupHeader(title, count, icon, color: color),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // Use grid layout for wider screens
              final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
              final aspectRatio = crossAxisCount == 2 ? 2.2 : 3.5;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: skills.length,
                itemBuilder: (context, index) =>
                    _buildCompactSkillCard(skills[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSkillCard(skills_api.SkillDto skill) {
    final isLocal = skill.source == 'local';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with name and actions
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (skill.version.isNotEmpty)
                      Text(
                        'v${skill.version}',
                        style: TextStyle(fontSize: 10, color: c.textHint),
                      ),
                  ],
                ),
              ),
              // Remove button (only for local skills)
              if (isLocal)
                Tooltip(
                  message: AppLocalizations.of(context)!.removeSkill,
                  child: InkWell(
                    onTap: () => _removeSkill(skill.name),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: AppColors.error.withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.error.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Description
          if (skill.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              skill.description,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const Spacer(),

          // Bottom row: tags + tools count
          Row(
            children: [
              // Tags (show first 2)
              if (skill.tags.isNotEmpty) ...[
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: skill.tags.take(2).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.cardBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(fontSize: 9, color: c.textHint),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else
                const Spacer(),

              // Tools count badge
              if (skill.tools.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.build_outlined,
                        size: 10,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${skill.tools.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

              // Prompts count badge
              if (skill.prompts.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.note_outlined, size: 10, color: Colors.purple),
                      const SizedBox(width: 3),
                      Text(
                        '${skill.prompts.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
              Text(subtitle, style: TextStyle(fontSize: 12, color: c.textHint)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildModeChip(
    String value,
    String label,
    String description,
    String current,
  ) {
    final isSelected = current == value;
    return Expanded(
      child: InkWell(
        onTap: () => _updateInjectionMode(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : c.inputBg,
            border: Border.all(
              color: isSelected ? AppColors.primary : c.inputBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 16,
                    color: isSelected ? AppColors.primary : c.textHint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected ? AppColors.primary : c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
