import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/category_color.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';
import '../../../../core/widgets/inline_add_button.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/finance_providers.dart';

/// The swatch row, in display order. A new category starts on
/// [_defaultColorHex] rather than whichever colour happens to lead the row.
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

const _defaultColorHex = '#2E9E63';

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
///
/// [fixedKind], when passed, locks the sheet to that `kind` and hides the
/// Expense/Income toggle — for callers outside finance (e.g. the habit
/// category picker, which creates `kind: 'habit'` rows) where that toggle
/// wouldn't make sense.
Future<CategoryEditorResult?> showCategoryEditorSheet(
  BuildContext context, {
  Category? existing,
  String? fixedKind,
}) {
  return showCompactEditorSheet<CategoryEditorResult>(
    context: context,
    builder: (context) =>
        _CategoryEditorSheet(existing: existing, fixedKind: fixedKind),
  );
}

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return InlineAddHost(
      builder: (context, inlineAddVisible, onInlineAddVisibility) => Scaffold(
        appBar: AppBar(title: const Text('Categories')),
        body: categories.isEmpty
            ? const Center(child: Text('No categories yet.'))
            : ListView.separated(
                // The extended FAB floats over the list, so without room below
                // the last row its trash button sits underneath it and can't be
                // tapped. 20 (page margin) + 56 (FAB) + 16 (FAB margin) + 8, plus the
                // bottom inset, which the FAB is lifted by but the list's body isn't.
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  100 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                itemCount: categories.length + 1,
                separatorBuilder: (_, index) => index == categories.length - 1
                    ? const SizedBox.shrink()
                    : const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == categories.length) {
                    return InlineAddButton(
                      label: 'Add category',
                      onTap: () => _openEditor(context, ref),
                      onVisibilityChanged: onInlineAddVisibility,
                      padding: const EdgeInsets.only(top: 16),
                    );
                  }
                  final c = categories[index];
                  final color =
                      categoryColor(c.colorHex) ??
                      Theme.of(context).colorScheme.onSurfaceVariant;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.16),
                      foregroundColor: color,
                      child: IconOrEmoji(value: c.icon),
                    ),
                    title: Text(c.name),
                    subtitle: Text(c.kind),
                    onTap: () => _openEditor(context, ref, existing: c),
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.trash2),
                      onPressed: () => _delete(context, ref, c),
                    ),
                  );
                },
              ),
        // One add affordance at a time: the dashed row at the end of the list
        // while it is on screen, the FAB once it has scrolled away.
        floatingActionButton: inlineAddVisible
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openEditor(context, ref),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Add category'),
              ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Category? existing,
  }) async {
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

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final controller = ref.read(financeControllerProvider);
    // Only transactions block a delete. A budget goes with its category, and
    // the hidden tombstone rows a deleted budget leaves behind are not user
    // data — counting them is what made a category refuse to delete while
    // nothing visible used it.
    final usage = await controller.categoryTransactionCount(category.id);
    final budget = await controller.categoryActiveBudget(category.id);
    if (!context.mounted) return;

    if (usage > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Can't delete this category"),
          content: Text(
            'It\'s used by $usage transaction${usage == 1 ? '' : 's'}. Move ${usage == 1 ? 'it' : 'them'} to another category first, or leave this one in place.',
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
        content: Text(
          budget == null
              ? '"${category.name}" will be removed.'
              : '"${category.name}" has no transactions, but it has a '
                    '${budget.period} budget of ${formatMinor(budget.limitMinor, currencyCode: ref.read(settingsProvider).currencyCode, showDecimals: false)}. '
                    'Deleting the category will remove that budget too.',
        ),
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
  const _CategoryEditorSheet({this.existing, this.fixedKind});

  final Category? existing;
  final String? fixedKind;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late String _icon = widget.existing?.icon ?? defaultCategoryIcon;
  late String _colorHex = widget.existing?.colorHex ?? _defaultColorHex;
  late String _kind = widget.existing?.kind ?? widget.fixedKind ?? 'expense';

  bool get _isEditing => widget.existing != null;

  /// The icon choices preview in the chosen colour; "No color" previews in a
  /// neutral, which is also what the saved category renders with.
  Color get _tint =>
      categoryColor(_colorHex) ??
      Theme.of(context).colorScheme.onSurfaceVariant;

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
    return CompactEditorSheet(
      title: _isEditing ? 'Edit category' : 'New category',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Category name'),
          ),
          if (widget.fixedKind == null) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          ],
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
                  color: _tint,
                  onTap: () => setState(() => _icon = name),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Colorful icons', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final emoji in pickableEmojis)
                _IconChoice(
                  emoji: emoji,
                  selected: _icon == emoji,
                  color: _tint,
                  onTap: () => setState(() => _icon = emoji),
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
              _NoColorChoice(
                selected: _colorHex == noCategoryColorHex,
                onTap: () => setState(() => _colorHex = noCategoryColorHex),
              ),
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
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    this.icon,
    this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData? icon;
  final String? emoji;
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
            color: selected
                ? color
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: emoji != null
            ? EmojiGlyph(emoji!)
            : Icon(
                icon,
                size: 20,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

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
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : null,
        ),
      ),
    );
  }
}

/// The "No color" swatch: an empty ring with a slash, so it reads as the
/// absence of a colour rather than as a very pale one.
class _NoColorChoice extends StatelessWidget {
  const _NoColorChoice({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'No color',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Icon(
            LucideIcons.ban,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
