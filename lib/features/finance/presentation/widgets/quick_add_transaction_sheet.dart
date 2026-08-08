import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/finance_providers.dart';
import '../../domain/payment_mode.dart';
import '../screens/category_management_screen.dart';

class QuickAddTransactionResult {
  const QuickAddTransactionResult({
    required this.accountId,
    this.categoryId,
    required this.merchant,
    required this.amountMinor,
    required this.date,
    this.paymentMode,
  });

  final String accountId;
  final String? categoryId;
  final String merchant;

  /// Already signed: negative for expense, positive for income.
  final int amountMinor;
  final DateTime date;
  final String? paymentMode;
}

Future<QuickAddTransactionResult?> showQuickAddTransactionSheet(
  BuildContext context, {
  required List<Account> accounts,
  required List<Category> categories,
  Transaction? initial,
}) {
  return showModalBottomSheet<QuickAddTransactionResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickAddTransactionSheet(
      accounts: accounts,
      categories: categories,
      initial: initial,
    ),
  );
}

class _QuickAddTransactionSheet extends ConsumerStatefulWidget {
  const _QuickAddTransactionSheet({
    required this.accounts,
    required this.categories,
    this.initial,
  });

  final List<Account> accounts;
  final List<Category> categories;
  final Transaction? initial;

  @override
  ConsumerState<_QuickAddTransactionSheet> createState() => _QuickAddTransactionSheetState();
}

/// Sentinel dropdown value for the trailing "Add new category" entry —
/// distinct from any real category id.
const _addCategoryValue = '__add_category__';

class _QuickAddTransactionSheetState extends ConsumerState<_QuickAddTransactionSheet> {
  late final _merchantController = TextEditingController(text: widget.initial?.merchant);
  late final _amountController = TextEditingController(
    text: widget.initial == null
        ? null
        : (widget.initial!.amountMinor.abs() / 100).toStringAsFixed(2),
  );
  late String _accountId = widget.initial?.accountId ?? widget.accounts.first.id;
  late List<Category> _categories = List.of(widget.categories);
  late String? _categoryId = widget.initial?.categoryId;
  late bool _isExpense = (widget.initial?.amountMinor ?? -1) < 0;
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late String? _paymentMode = widget.initial?.paymentMode;

  /// See the identical field in `_QuickAddBudgetSheetState` — forces the
  /// (uncontrolled) category dropdown back to `_categoryId` after "Add new
  /// category" resolves or is cancelled.
  int _categoryFieldEpoch = 0;

  bool get _isEditing => widget.initial != null;

  Category? get _selectedCategory =>
      _categories.where((c) => c.id == _categoryId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _merchantController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
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

  Future<void> _editSelectedCategory() async {
    final existing = _selectedCategory;
    if (existing == null) return;
    final result = await showCategoryEditorSheet(context, existing: existing);
    if (result == null) return;
    final updated = await ref.read(financeControllerProvider).updateCategory(
      id: existing.id,
      name: result.name,
      icon: result.icon,
      colorHex: result.colorHex,
      kind: result.kind,
    );
    if (!mounted) return;
    setState(() {
      _categories = [
        for (final c in _categories) if (c.id == updated.id) updated else c,
      ];
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _merchantController.text.trim().isNotEmpty &&
        (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

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
            _isEditing ? 'Edit transaction' : 'New transaction',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Expense')),
              ButtonSegment(value: false, label: Text('Income')),
            ],
            selected: {_isExpense},
            onSelectionChanged: (s) => setState(() => _isExpense = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchantController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Merchant / description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Amount (₹)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              for (final a in widget.accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (value) => setState(() => _accountId = value!),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
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
              ),
              if (_selectedCategory != null)
                IconButton(
                  tooltip: 'Edit category',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _editSelectedCategory,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Payment mode', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in paymentModes)
                ChoiceChip(
                  avatar: Icon(m.icon, size: 16),
                  label: Text(m.label),
                  selected: _paymentMode == m.id,
                  onSelected: (_) => setState(
                    () => _paymentMode = _paymentMode == m.id ? null : m.id,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(DateFormat.yMMMd().format(_date)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSubmit
                  ? () {
                      final rupees = double.parse(_amountController.text.trim());
                      final minor = (rupees * 100).round();
                      Navigator.of(context).pop(
                        QuickAddTransactionResult(
                          accountId: _accountId,
                          categoryId: _categoryId,
                          merchant: _merchantController.text.trim(),
                          amountMinor: _isExpense ? -minor : minor,
                          date: _date,
                          paymentMode: _paymentMode,
                        ),
                      );
                    }
                  : null,
              child: Text(_isEditing ? 'Save changes' : 'Add transaction'),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
