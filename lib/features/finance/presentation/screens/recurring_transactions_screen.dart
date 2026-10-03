import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/inline_add_button.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/utils/category_color.dart';
import '../../../../core/widgets/empty_state_message.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../../settings/application/settings_providers.dart';
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

  /// Opens the sheet for a new schedule, or for [existing] to edit it.
  static Future<void> openSheet(
    BuildContext context,
    WidgetRef ref, {
    RecurringTransaction? existing,
  }) async {
    final accounts = ref.read(transactableAccountsProvider);
    if (accounts.isEmpty) return;
    final categories = ref.read(categoriesProvider).value ?? const [];
    final accountTypes = ref.read(accountTypesProvider).value ?? const [];
    final result = await showQuickAddRecurringTransactionSheet(
      context,
      accounts: accounts,
      accountTypes: accountTypes,
      categories: categories,
      currencySymbol: currencySymbolFor(
        ref.read(settingsProvider).currencyCode,
      ),
      initial: existing,
    );
    if (result == null) return;
    final controller = ref.read(financeControllerProvider);
    if (existing == null) {
      await controller.addRecurringTransaction(
        accountId: result.accountId,
        categoryId: result.categoryId,
        merchant: result.merchant,
        amountMinor: result.amountMinor,
        frequency: result.frequency,
        startDate: result.startDate,
        endDate: result.endDate,
        paymentMode: result.paymentMode,
      );
    } else {
      await controller.updateRecurringTransaction(
        existing: existing,
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
    if (!context.mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: existing == null
          ? 'Recurring transaction saved'
          : 'Recurring transaction updated',
      message: existing == null
          ? '“${result.merchant}” repeats from '
                '${DateFormat.yMMMd().format(result.startDate)}.'
          : 'Changes to “${result.merchant}” were saved.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurring =
        ref.watch(recurringTransactionsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryById = {for (final c in categories) c.id: c};
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final accountById = {for (final a in accounts) a.id: a};

    return InlineAddHost(
      builder: (context, inlineAddVisible, onInlineAddVisibility) => Scaffold(
        appBar: AppBar(title: const Text('Recurring transactions')),
        body: recurring.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                // The extended FAB floats over the list, so without room below the last
                // row its trailing buttons sit underneath it and can't be tapped.
                // 16 (page margin) + 56 (FAB) + 16 (FAB margin) + 12, plus the bottom
                // inset, which the FAB is lifted by but the list's body isn't.
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  100 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                itemCount: recurring.length + 1,
                separatorBuilder: (_, index) => index == recurring.length - 1
                    ? const SizedBox.shrink()
                    : const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == recurring.length) {
                    return InlineAddButton(
                      label: 'Add recurring',
                      onTap: () => openSheet(context, ref),
                      onVisibilityChanged: onInlineAddVisibility,
                      padding: const EdgeInsets.only(top: 16),
                    );
                  }
                  final schedule = recurring[index];
                  return _RecurringTile(
                    schedule: schedule,
                    category: categoryById[schedule.categoryId],
                    accountName:
                        accountById[schedule.accountId]?.name ??
                        'Unknown account',
                  );
                },
              ),
        // One add affordance at a time: the dashed row at the end of the list
        // while it is on screen, the FAB once it has scrolled away.
        floatingActionButton: inlineAddVisible
            ? null
            : FloatingActionButton.extended(
                onPressed: () => openSheet(context, ref),
                icon: const Icon(LucideIcons.plus),
                label: const Text('New recurring'),
              ),
      ),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({
    required this.schedule,
    this.category,
    required this.accountName,
  });

  final RecurringTransaction schedule;
  final Category? category;
  final String accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final currencyCode = ref.watch(settingsProvider).currencyCode;
    final isIncome = schedule.amountMinor >= 0;
    final color = category != null
        ? (categoryColor(category!.colorHex) ??
              theme.colorScheme.onSurfaceVariant)
        : (isIncome ? colors.good : colors.spend);

    return Opacity(
      opacity: schedule.active ? 1 : 0.5,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => RecurringTransactionsScreen.openSheet(
          context,
          ref,
          existing: schedule,
        ),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: category != null
              ? IconOrEmoji(value: category!.icon, size: 18, color: color)
              : Icon(LucideIcons.refreshCw, size: 18, color: color),
        ),
        title: Text(
          schedule.merchant,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${_frequencyLabels[schedule.frequency] ?? schedule.frequency} · $accountName · '
          '${schedule.active ? "Next" : "Paused, was next"} ${DateFormat.yMMMd().format(schedule.nextDueDate)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMinor(
                schedule.amountMinor,
                currencyCode: currencyCode,
                showSign: true,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isIncome ? colors.good : colors.spend,
              ),
            ),
            IconButton(
              tooltip: schedule.active ? 'Pause' : 'Resume',
              icon: Icon(
                schedule.active
                    ? LucideIcons.circlePause
                    : LucideIcons.circlePlay,
              ),
              onPressed: () => ref
                  .read(financeControllerProvider)
                  .setRecurringTransactionActive(schedule.id, !schedule.active),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(LucideIcons.trash2),
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
        content: Text(
          '"${schedule.merchant}" will stop generating new transactions. Already-generated ones stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(financeControllerProvider)
          .deleteRecurringTransaction(schedule.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateMessage(
      emoji: '🔁',
      title: 'No recurring transactions yet',
      message:
          'Add subscriptions, rent, or EMIs and they\'ll be entered automatically on schedule.',
    );
  }
}
