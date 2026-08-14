import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/finance_providers.dart';
import '../widgets/quick_add_recurring_transaction_sheet.dart';

const _frequencyLabels = {
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
  'yearly': 'Yearly',
};

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  Future<void> _addRecurring(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(transactableAccountsProvider);
    if (accounts.isEmpty) return;
    final categories = ref.read(categoriesProvider).value ?? const [];
    final result = await showQuickAddRecurringTransactionSheet(
      context,
      accounts: accounts,
      categories: categories,
    );
    if (result == null) return;
    await ref
        .read(financeControllerProvider)
        .addRecurringTransaction(
          accountId: result.accountId,
          categoryId: result.categoryId,
          merchant: result.merchant,
          amountMinor: result.amountMinor,
          frequency: result.frequency,
          startDate: result.startDate,
          endDate: result.endDate,
          paymentMode: result.paymentMode,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurring = ref.watch(recurringTransactionsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryById = {for (final c in categories) c.id: c};
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final accountById = {for (final a in accounts) a.id: a};

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring transactions')),
      body: recurring.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: recurring.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final schedule = recurring[index];
                return _RecurringTile(
                  schedule: schedule,
                  category: categoryById[schedule.categoryId],
                  accountName: accountById[schedule.accountId]?.name ?? 'Unknown account',
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRecurring(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New recurring'),
      ),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.schedule, this.category, required this.accountName});

  final RecurringTransaction schedule;
  final Category? category;
  final String accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isIncome = schedule.amountMinor >= 0;
    final color = category != null
        ? Color(int.parse(category!.colorHex.replaceFirst('#', '0xFF')))
        : (isIncome ? colors.good : colors.spend);

    return Opacity(
      opacity: schedule.active ? 1 : 0.5,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(
            category != null ? resolveIcon(category!.icon) : Icons.autorenew_rounded,
            size: 18,
            color: color,
          ),
        ),
        title: Text(schedule.merchant, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${_frequencyLabels[schedule.frequency] ?? schedule.frequency} · $accountName · '
          '${schedule.active ? "Next" : "Paused, was next"} ${DateFormat.yMMMd().format(schedule.nextDueDate)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMinor(schedule.amountMinor, showSign: true),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isIncome ? colors.good : colors.spend,
              ),
            ),
            IconButton(
              tooltip: schedule.active ? 'Pause' : 'Resume',
              icon: Icon(schedule.active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded),
              onPressed: () => ref
                  .read(financeControllerProvider)
                  .setRecurringTransactionActive(schedule.id, !schedule.active),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recurring transaction?'),
        content: Text('"${schedule.merchant}" will stop generating new transactions. Already-generated ones stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(financeControllerProvider).deleteRecurringTransaction(schedule.id);
    }
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
            Icon(Icons.autorenew_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No recurring transactions yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Add subscriptions, rent, or EMIs and they\'ll be entered automatically on schedule.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
