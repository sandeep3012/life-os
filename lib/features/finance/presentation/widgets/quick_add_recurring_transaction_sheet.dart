import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../domain/payment_mode.dart';

class QuickAddRecurringTransactionResult {
  const QuickAddRecurringTransactionResult({
    required this.accountId,
    this.categoryId,
    required this.merchant,
    required this.amountMinor,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.paymentMode,
  });

  final String accountId;
  final String? categoryId;
  final String merchant;

  /// Already signed: negative for expense, positive for income.
  final int amountMinor;

  /// daily | weekly | monthly | yearly
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final String? paymentMode;
}

const _frequencies = [
  ('daily', 'Daily'),
  ('weekly', 'Weekly'),
  ('monthly', 'Monthly'),
  ('yearly', 'Yearly'),
];

Future<QuickAddRecurringTransactionResult?> showQuickAddRecurringTransactionSheet(
  BuildContext context, {
  required List<Account> accounts,
  required List<Category> categories,
}) {
  return showModalBottomSheet<QuickAddRecurringTransactionResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _QuickAddRecurringTransactionSheet(accounts: accounts, categories: categories),
  );
}

class _QuickAddRecurringTransactionSheet extends StatefulWidget {
  const _QuickAddRecurringTransactionSheet({required this.accounts, required this.categories});

  final List<Account> accounts;
  final List<Category> categories;

  @override
  State<_QuickAddRecurringTransactionSheet> createState() =>
      _QuickAddRecurringTransactionSheetState();
}

class _QuickAddRecurringTransactionSheetState
    extends State<_QuickAddRecurringTransactionSheet> {
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  late String _accountId = widget.accounts.first.id;
  String? _categoryId;
  bool _isExpense = true;
  String? _paymentMode;
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _endDate = picked);
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
            Text('New recurring transaction', style: Theme.of(context).textTheme.titleLarge),
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
              decoration: const InputDecoration(hintText: 'e.g. Netflix, Rent, Salary'),
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
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category (optional)'),
              items: [
                for (final c in widget.categories)
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
              ],
              onChanged: (value) => setState(() => _categoryId = value),
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
                    onSelected: (_) =>
                        setState(() => _paymentMode = _paymentMode == m.id ? null : m.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Repeats', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (value, label) in _frequencies)
                  ChoiceChip(
                    label: Text(label),
                    selected: _frequency == value,
                    onSelected: (_) => setState(() => _frequency = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickStartDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Starts'),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(DateFormat.yMMMd().format(_startDate)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickEndDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Ends (optional)',
                  suffixIcon: _endDate == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _endDate = null),
                        ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(_endDate == null ? 'Never' : DateFormat.yMMMd().format(_endDate!)),
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
                          QuickAddRecurringTransactionResult(
                            accountId: _accountId,
                            categoryId: _categoryId,
                            merchant: _merchantController.text.trim(),
                            amountMinor: _isExpense ? -minor : minor,
                            frequency: _frequency,
                            startDate: _startDate,
                            endDate: _endDate,
                            paymentMode: _paymentMode,
                          ),
                        );
                      }
                    : null,
                child: const Text('Add recurring transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
