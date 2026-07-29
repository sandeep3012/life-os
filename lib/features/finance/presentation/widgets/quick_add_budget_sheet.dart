import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

class QuickAddBudgetResult {
  const QuickAddBudgetResult({
    required this.categoryId,
    required this.limitMinor,
    required this.period,
  });

  final String categoryId;
  final int limitMinor;
  final String period;
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

  bool get _isEditing => widget.initial != null;

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
