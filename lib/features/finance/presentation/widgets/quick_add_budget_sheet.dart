import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/finance_providers.dart';
import '../screens/category_management_screen.dart';

class QuickAddBudgetResult {
  const QuickAddBudgetResult({
    required this.categoryId,
    required this.limitMinor,
    required this.period,
    required this.effectiveMonth,
  });

  final String categoryId;
  final int limitMinor;
  final String period;

  /// First-of-month date this limit takes effect from.
  final DateTime effectiveMonth;
}

Future<QuickAddBudgetResult?> showQuickAddBudgetSheet(
  BuildContext context, {
  required List<Category> categories,
  required String currencySymbol,
  Budget? initial,
}) {
  return showModalBottomSheet<QuickAddBudgetResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickAddBudgetSheet(
      categories: categories,
      currencySymbol: currencySymbol,
      initial: initial,
    ),
  );
}

/// Sentinel dropdown value for the trailing "Add new category" entry —
/// distinct from any real category id.
const _addCategoryValue = '__add_category__';

class _QuickAddBudgetSheet extends ConsumerStatefulWidget {
  const _QuickAddBudgetSheet({required this.categories, required this.currencySymbol, this.initial});

  final List<Category> categories;
  final String currencySymbol;
  final Budget? initial;

  @override
  ConsumerState<_QuickAddBudgetSheet> createState() => _QuickAddBudgetSheetState();
}

class _QuickAddBudgetSheetState extends ConsumerState<_QuickAddBudgetSheet> {
  late final _limitController = TextEditingController(
    text: widget.initial == null
        ? null
        : (widget.initial!.limitMinor / 100).toStringAsFixed(2),
  );
  late List<Category> _categories = List.of(widget.categories);
  late String? _categoryId =
      widget.initial?.categoryId ?? (_categories.isEmpty ? null : _categories.first.id);
  late String _period = widget.initial?.period ?? 'monthly';
  late DateTime _effectiveMonth = _startOfMonth(DateTime.now());

  bool get _isEditing => widget.initial != null;

  /// Bumped every time the category dropdown needs to be forced back to
  /// `_categoryId` — including when "Add new category" is cancelled, since
  /// the dropdown (an uncontrolled `DropdownButtonFormField`) would
  /// otherwise keep showing that sentinel entry as selected even though
  /// `_categoryId` itself never changed.
  int _categoryFieldEpoch = 0;

  static DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month);

  @override
  void initState() {
    super.initState();
    _limitController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Effective from which month',
    );
    if (picked != null) setState(() => _effectiveMonth = _startOfMonth(picked));
  }

  Future<void> _addCategory() async {
    final result = await showCategoryEditorSheet(context);
    if (result == null) {
      if (mounted) setState(() => _categoryFieldEpoch++);
      return;
    }
    final category = await ref.read(financeControllerProvider).addCategory(
      name: result.name,
      icon: result.icon,
      colorHex: result.colorHex,
      kind: result.kind,
    );
    if (!mounted) return;
    setState(() {
      _categories = [..._categories, category];
      _categoryId = category.id;
      _categoryFieldEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _categoryId != null && (double.tryParse(_limitController.text.trim()) ?? 0) > 0;

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
          Text(
            _isEditing ? 'Edit budget' : 'New budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            // DropdownButtonFormField is uncontrolled (it only reads
            // `initialValue` on first build) — keying on the value
            // forces it to rebuild fresh whenever `_categoryId`
            // changes programmatically (e.g. after adding a category
            // inline), otherwise the dropdown would keep showing
            // whatever the user last tapped in the menu.
            key: ValueKey('$_categoryId#$_categoryFieldEpoch'),
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in _categories)
                DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(resolveIcon(c.icon), size: 16),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ],
                  ),
                ),
              const DropdownMenuItem(
                value: _addCategoryValue,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Add new category'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (value == _addCategoryValue) {
                _addCategory();
              } else {
                setState(() => _categoryId = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: 'Limit (${widget.currencySymbol})'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickMonth,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Effective from'),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(DateFormat.yMMMM().format(_effectiveMonth)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This limit applies from ${DateFormat.yMMMM().format(_effectiveMonth)} onward — earlier months keep whatever was set for them.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSubmit
                  ? () {
                      final rupees = double.parse(_limitController.text.trim());
                      Navigator.of(context).pop(
                        QuickAddBudgetResult(
                          categoryId: _categoryId!,
                          limitMinor: (rupees * 100).round(),
                          period: _period,
                          effectiveMonth: _effectiveMonth,
                        ),
                      );
                    }
                  : null,
              child: Text(_isEditing ? 'Save changes' : 'Add budget'),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
