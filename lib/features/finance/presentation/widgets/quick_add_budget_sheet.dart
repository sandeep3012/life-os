import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';

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
  Budget? initial,
}) {
  return showModalBottomSheet<QuickAddBudgetResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickAddBudgetSheet(categories: categories, initial: initial),
  );
}

class _QuickAddBudgetSheet extends StatefulWidget {
  const _QuickAddBudgetSheet({required this.categories, this.initial});

  final List<Category> categories;
  final Budget? initial;

  @override
  State<_QuickAddBudgetSheet> createState() => _QuickAddBudgetSheetState();
}

class _QuickAddBudgetSheetState extends State<_QuickAddBudgetSheet> {
  late final _limitController = TextEditingController(
    text: widget.initial == null
        ? null
        : (widget.initial!.limitMinor / 100).toStringAsFixed(2),
  );
  late String? _categoryId =
      widget.initial?.categoryId ?? (widget.categories.isEmpty ? null : widget.categories.first.id);
  late String _period = widget.initial?.period ?? 'monthly';
  late DateTime _effectiveMonth = _startOfMonth(DateTime.now());

  bool get _isEditing => widget.initial != null;

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

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _categoryId != null && (double.tryParse(_limitController.text.trim()) ?? 0) > 0;

    return Padding(
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
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in widget.categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Limit (₹)'),
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
    );
  }
}
