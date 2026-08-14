import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/finance_providers.dart';
import '../widgets/quick_add_bill_sheet.dart';

const _frequencyLabels = {'once': 'One-time', 'monthly': 'Monthly', 'yearly': 'Yearly'};

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  Future<void> _addBill(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(transactableAccountsProvider);
    if (accounts.isEmpty) return;
    final categories = ref.read(categoriesProvider).value ?? const [];
    final result = await showQuickAddBillSheet(context, accounts: accounts, categories: categories);
    if (result == null) return;
    await ref
        .read(financeControllerProvider)
        .addBill(
          name: result.name,
          accountId: result.accountId,
          categoryId: result.categoryId,
          amountMinor: result.amountMinor,
          dueDate: result.dueDate,
          frequency: result.frequency,
          reminderEnabled: result.reminderEnabled,
          reminderMode: result.reminderMode,
          reminderDaysBefore: result.reminderDaysBefore,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(upcomingBillsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryById = {for (final c in categories) c.id: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      body: bills.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: bills.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bill = bills[index];
                return _BillTile(bill: bill, category: categoryById[bill.categoryId]);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBill(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New bill'),
      ),
    );
  }
}

class _BillTile extends ConsumerWidget {
  const _BillTile({required this.bill, this.category});

  final Bill bill;
  final Category? category;

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(transactableAccountsProvider);
    if (accounts.isEmpty) return;
    var accountId = bill.accountId ?? accounts.first.id;
    if (!accounts.any((a) => a.id == accountId)) accountId = accounts.first.id;

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => _PayFromDialog(accounts: accounts, initialAccountId: accountId),
    );
    if (chosen == null) return;
    await ref.read(financeControllerProvider).markBillPaid(bill, accountId: chosen);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bill?'),
        content: Text('"${bill.name}" and its reminder will be removed. Past payments stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(financeControllerProvider).deleteBill(bill.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final overdue = bill.dueDate.isBefore(dateOnly(DateTime.now()));
    final color = overdue ? colors.critical : colors.finance;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Icon(
          category != null ? resolveIcon(category!.icon) : Icons.receipt_long_rounded,
          size: 18,
          color: color,
        ),
      ),
      title: Text(bill.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${_frequencyLabels[bill.frequency] ?? bill.frequency} · '
        '${overdue ? "Overdue" : "Due"} ${DateFormat.yMMMd().format(bill.dueDate)}',
        style: TextStyle(color: overdue ? colors.critical : null),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMinor(bill.amountMinor),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Mark as paid',
            icon: const Icon(Icons.check_circle_outline_rounded),
            onPressed: () => _markPaid(context, ref),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _PayFromDialog extends StatefulWidget {
  const _PayFromDialog({required this.accounts, required this.initialAccountId});

  final List<Account> accounts;
  final String initialAccountId;

  @override
  State<_PayFromDialog> createState() => _PayFromDialogState();
}

class _PayFromDialogState extends State<_PayFromDialog> {
  late String _accountId = widget.initialAccountId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pay from'),
      content: DropdownButtonFormField<String>(
        initialValue: _accountId,
        items: [
          for (final a in widget.accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
        ],
        onChanged: (v) => setState(() => _accountId = v ?? _accountId),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _accountId), child: const Text('Mark paid')),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No bills tracked yet', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Add a bill to get reminded before it\'s due, and mark it paid when it is.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
