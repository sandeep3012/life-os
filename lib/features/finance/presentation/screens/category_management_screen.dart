import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/finance_providers.dart';

const _paletteHex = [
  '#E0475A',
  '#2E9E63',
  '#2F6FED',
  '#A67C00',
  '#A63FBE',
  '#D63860',
  '#0E9488',
  '#8B84A3',
];

class CategoryEditorResult {
  const CategoryEditorResult({
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.kind,
  });

  final String name;
  final String icon;
  final String colorHex;
  final String kind;
}

/// Opens the add/edit category sheet directly — used by the category
/// management screen, and inline from the transaction/budget category
/// pickers so a missing category can be created (or the selected one
/// edited) without leaving that flow.
Future<CategoryEditorResult?> showCategoryEditorSheet(
  BuildContext context, {
  Category? existing,
}) {
  return showModalBottomSheet<CategoryEditorResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CategoryEditorSheet(existing: existing),
  );
}

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categories.isEmpty
          ? const Center(child: Text('No categories yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = categories[index];
                final color = Color(int.parse(c.colorHex.replaceFirst('#', '0xFF')));
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.16),
                    foregroundColor: color,
                    child: Icon(resolveIcon(c.icon)),
                  ),
                  title: Text(c.name),
                  subtitle: Text(c.kind),
                  onTap: () => _openEditor(context, ref, existing: c),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(context, ref, c),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Category? existing}) async {
    final result = await showCategoryEditorSheet(context, existing: existing);
    if (result == null) return;

    final controller = ref.read(financeControllerProvider);
    if (existing == null) {
      await controller.addCategory(
        name: result.name,
        icon: result.icon,
        colorHex: result.colorHex,
        kind: result.kind,
      );
    } else {
      await controller.updateCategory(
        id: existing.id,
        name: result.name,
        icon: result.icon,
        colorHex: result.colorHex,
        kind: result.kind,
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Category category) async {
    final controller = ref.read(financeControllerProvider);
    final usage = await controller.categoryUsageCount(category.id);
    if (!context.mounted) return;

    if (usage > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Can't delete this category"),
          content: Text(
            'It\'s used by $usage transaction${usage == 1 ? '' : 's'}/budget${usage == 1 ? '' : 's'}. Remove those first, or leave the category in place.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this category?'),
        content: Text('"${category.name}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteCategory(category.id);
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({this.existing});

  final Category? existing;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late String _icon = widget.existing?.icon ?? pickableIcons.first;
  late String _colorHex = widget.existing?.colorHex ?? _paletteHex.first;
  late String _kind = widget.existing?.kind ?? 'expense';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEditing ? 'Edit category' : 'New category', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Category name'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Expense')),
              ButtonSegment(value: 'income', label: Text('Income')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          Text('Icon', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in pickableIcons)
                _IconChoice(
                  icon: resolveIcon(name),
                  selected: _icon == name,
                  color: Color(int.parse(_colorHex.replaceFirst('#', '0xFF'))),
                  onTap: () => setState(() => _icon = name),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Color', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hex in _paletteHex)
                _ColorChoice(
                  color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                  selected: _colorHex == hex,
                  onTap: () => setState(() => _colorHex = hex),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      CategoryEditorResult(
                        name: _nameController.text.trim(),
                        icon: _icon,
                        colorHex: _colorHex,
                        kind: _kind,
                      ),
                    ),
              child: Text(_isEditing ? 'Save changes' : 'Add category'),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Icon(icon, size: 20, color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
              : null,
        ),
      ),
    );
  }
}
