import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/settings/widgets/settings_scaffold.dart';
import 'package:coraldesk/src/rust/api/knowledge_api.dart' as kb_api;

/// Knowledge Base management page — view, search, add, delete memory entries
class KnowledgePage extends ConsumerStatefulWidget {
  const KnowledgePage({super.key});

  @override
  ConsumerState<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends ConsumerState<KnowledgePage> {
  kb_api.KnowledgeStats? _stats;
  List<kb_api.KnowledgeEntry> _entries = [];
  bool _loading = true;
  String? _message;
  String? _searchQuery;
  String _filterCategory = 'all';
  final TextEditingController _searchController = TextEditingController();
  CoralDeskColors get c => CoralDeskColors.of(context);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final stats = await kb_api.getKnowledgeStats();
      List<kb_api.KnowledgeEntry> entries;
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        entries = await kb_api.searchKnowledge(
          query: _searchQuery!,
          limit: 100,
        );
      } else {
        entries = await kb_api.listKnowledgeEntries(
          category: _filterCategory == 'all' ? null : _filterCategory,
          limit: 200,
        );
      }
      if (mounted) {
        setState(() {
          _stats = stats;
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _showMessage(
          '${AppLocalizations.of(context)!.operationFailed}: $e',
          isError: true,
        );
      }
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    setState(() => _message = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  Future<void> _handleSearch(String query) async {
    _searchQuery = query.isEmpty ? null : query;
    await _loadAll();
  }

  Future<void> _handleAdd() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AddKnowledgeDialog(),
    );
    if (result == null) return;

    final key = result['key'] ?? '';
    final content = result['content'] ?? '';
    final category = result['category'] ?? 'core';

    if (key.isEmpty || content.isEmpty) return;

    final res = await kb_api.addKnowledgeEntry(
      key: key,
      content: content,
      category: category,
    );
    if (!mounted) return;
    if (res == 'ok') {
      _showMessage(AppLocalizations.of(context)!.knowledgeEntryAdded);
      _loadAll();
    } else {
      _showMessage(
        '${AppLocalizations.of(context)!.operationFailed}: $res',
        isError: true,
      );
    }
  }

  Future<void> _handleDelete(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.deleteKnowledgeTitle),
        content: Text(AppLocalizations.of(ctx)!.deleteKnowledgeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppLocalizations.of(ctx)!.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final res = await kb_api.deleteKnowledgeEntry(key: key);
    if (!mounted) return;
    if (res == 'ok') {
      _showMessage(AppLocalizations.of(context)!.knowledgeEntryDeleted);
      _loadAll();
    } else {
      _showMessage(
        '${AppLocalizations.of(context)!.operationFailed}: $res',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.pageKnowledge,
      icon: Icons.menu_book,
      isLoading: _loading,
      body: _buildContent(),
      actions: [
        if (_message != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _message!.contains('失败') || _message!.contains('error')
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _message!,
              style: TextStyle(
                fontSize: 12,
                color: _message!.contains('失败') || _message!.contains('error')
                    ? AppColors.error
                    : AppColors.success,
              ),
            ),
          ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          color: c.textHint,
          onPressed: _loadAll,
          tooltip: l10n.refresh,
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsSection(),
        const SizedBox(height: 24),
        _buildSearchAndActions(),
        const SizedBox(height: 16),
        _buildEntriesList(),
      ],
    );
  }

  Widget _buildStatsSection() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

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
              Icon(
                Icons.analytics_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.knowledgeOverview,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stats.healthy
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      stats.healthy ? Icons.check_circle : Icons.error,
                      size: 12,
                      color: stats.healthy
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      stats.healthy ? l10n.healthy : l10n.unhealthy,
                      style: TextStyle(
                        fontSize: 11,
                        color: stats.healthy
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard(
                l10n.totalEntries,
                '${stats.totalEntries}',
                Icons.folder_outlined,
                AppColors.primary,
              ),
              _buildStatCard(
                l10n.backend,
                stats.backend,
                Icons.storage,
                Colors.teal,
              ),
              _buildStatCard(
                l10n.embeddingProvider,
                stats.embeddingProvider,
                Icons.hub,
                Colors.indigo,
              ),
              _buildStatCard(
                l10n.embeddingModel,
                stats.embeddingModel,
                Icons.model_training,
                Colors.deepPurple,
              ),
              _buildStatCard(
                l10n.autoSave,
                stats.autoSave ? l10n.enabled : l10n.disabled,
                Icons.save,
                stats.autoSave ? AppColors.success : c.textHint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActions() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        // Search bar
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: l10n.searchKnowledge,
                hintStyle: TextStyle(fontSize: 13, color: c.textHint),
                prefixIcon: Icon(Icons.search, size: 18, color: c.textHint),
                filled: true,
                fillColor: c.inputBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: _handleSearch,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Category filter
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.inputBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterCategory,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
              dropdownColor: c.cardBg,
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(l10n.knowledgeCategoryAll),
                ),
                DropdownMenuItem(
                  value: 'core',
                  child: Text(l10n.knowledgeCategoryCore),
                ),
                DropdownMenuItem(
                  value: 'daily',
                  child: Text(l10n.knowledgeCategoryDaily),
                ),
                DropdownMenuItem(
                  value: 'conversation',
                  child: Text(l10n.knowledgeCategoryConversation),
                ),
              ],
              onChanged: (v) {
                setState(() => _filterCategory = v ?? 'all');
                _searchQuery = null;
                _searchController.clear();
                _loadAll();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Add button
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _handleAdd,
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.addKnowledge),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntriesList() {
    final l10n = AppLocalizations.of(context)!;
    if (_entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.chatListBorder),
        ),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: c.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noKnowledgeEntries,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noKnowledgeHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textHint),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              l10n.knowledgeEntries,
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
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_entries.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._entries.map((entry) => _buildEntryCard(entry)),
      ],
    );
  }

  Widget _buildEntryCard(kb_api.KnowledgeEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.chatListBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _categoryIcon(entry.category),
                  size: 16,
                  color: _categoryColor(entry.category),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _categoryColor(
                      entry.category,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _categoryColor(entry.category),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (entry.score > 0)
                  Text(
                    '${(entry.score * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textHint,
                      fontFamily: 'monospace',
                    ),
                  ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _handleDelete(entry.key),
                  borderRadius: BorderRadius.circular(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: c.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.content,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.timestamp.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.timestamp,
                style: TextStyle(
                  fontSize: 10,
                  color: c.textHint,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'core' => Icons.star,
      'daily' => Icons.today,
      'conversation' => Icons.chat,
      _ => Icons.label,
    };
  }

  Color _categoryColor(String category) {
    return switch (category) {
      'core' => Colors.amber,
      'daily' => Colors.blue,
      'conversation' => Colors.green,
      _ => Colors.purple,
    };
  }
}

/// Dialog for adding a new knowledge entry
class _AddKnowledgeDialog extends StatefulWidget {
  @override
  State<_AddKnowledgeDialog> createState() => _AddKnowledgeDialogState();
}

class _AddKnowledgeDialogState extends State<_AddKnowledgeDialog> {
  final _keyController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = 'core';

  @override
  void dispose() {
    _keyController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addKnowledge),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: l10n.knowledgeKeyLabel,
                hintText: l10n.knowledgeKeyHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.knowledgeContentLabel,
                hintText: l10n.knowledgeContentHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.knowledgeCategoryLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'core',
                  child: Text(l10n.knowledgeCategoryCore),
                ),
                DropdownMenuItem(
                  value: 'daily',
                  child: Text(l10n.knowledgeCategoryDaily),
                ),
                DropdownMenuItem(
                  value: 'conversation',
                  child: Text(l10n.knowledgeCategoryConversation),
                ),
              ],
              onChanged: (v) {
                setState(() => _category = v ?? 'core');
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'key': _keyController.text,
              'content': _contentController.text,
              'category': _category,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
