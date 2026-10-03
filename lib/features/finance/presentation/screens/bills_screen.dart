import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/empty_state_message.dart';
import '../../../../core/widgets/inline_add_button.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/utils/category_color.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/finance_providers.dart';
import '../widgets/account_option_row.dart';
import '../widgets/quick_add_bill_sheet.dart';

const _frequencyLabels = {
  'once': 'One-time',
  'monthly': 'Monthly',
  'yearly': 'Yearly',
};

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  /// Opens the sheet for a new bill, or for [existing] to edit it.
  static Future<void> openSheet(
    BuildContext context,
    WidgetRef ref, {
    Bill? existing,
  }) async {
    final accounts = ref.read(transactableAccountsProvider);
    if (accounts.isEmpty) return;
    final categories = ref.read(categoriesProvider).value ?? const [];
    final accountTypes = ref.read(accountTypesProvider).value ?? const [];
    final result = await showQuickAddBillSheet(
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
      await controller.addBill(
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
    } else {
      await controller.updateBill(
        id: existing.id,
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
    if (!context.mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: existing == null ? 'Bill saved' : 'Bill updated',
      message: existing == null
          ? '“${result.name}” is due ${DateFormat.yMMMd().format(result.dueDate)}.'
          : 'Changes to “${result.name}” were saved.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(upcomingBillsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryById = {for (final c in categories) c.id: c};
    // Keeps the accounts stream alive for [openSheet], which reads it rather
    // than watching it. Riverpod disposes an unlistened StreamProvider before
    // its first emission, so without this the add button reads an empty list
    // and returns without opening anything. The recurring screen already
    // watches accounts for its rows, which is why only this one was affected.
    ref.watch(accountsProvider);

    return InlineAddHost(
      builder: (context, inlineAddVisible, onInlineAddVisibility) => Scaffold(
        appBar: AppBar(title: const Text('Bills')),
        body: bills.isEmpty
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
                itemCount: bills.length + 1,
                separatorBuilder: (_, index) => index == bills.length - 1
                    ? const SizedBox.shrink()
                    : const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == bills.length) {
                    return InlineAddButton(
                      label: 'Add bill',
                      onTap: () => openSheet(context, ref),
                      onVisibilityChanged: onInlineAddVisibility,
                      padding: const EdgeInsets.only(top: 16),
                    );
                  }
                  final bill = bills[index];
                  return _BillTile(
                    bill: bill,
                    category: categoryById[bill.categoryId],
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
                label: const Text('New bill'),
              ),
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
    final accountTypes = ref.read(accountTypesProvider).value ?? const [];
    var accountId = bill.accountId ?? accounts.first.id;
    if (!accounts.any((a) => a.id == accountId)) accountId = accounts.first.id;

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => _PayFromDialog(
        accounts: accounts,
        accountTypes: accountTypes,
        initialAccountId: accountId,
      ),
    );
    if (chosen == null) return;
    await ref
        .read(financeControllerProvider)
        .markBillPaid(bill, accountId: chosen);
    if (!context.mounted) return;
    await showCelebration(
      context,
      ref,
      title: 'Bill paid',
      message: '"${bill.name}" is settled.',
      emoji: '🧾',
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bill?'),
        content: Text(
          '"${bill.name}" and its reminder will be removed. Past payments stay.',
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
      await ref.read(financeControllerProvider).deleteBill(bill.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final currencyCode = ref.watch(settingsProvider).currencyCode;
    final overdue = bill.dueDate.isBefore(dateOnly(DateTime.now()));
    // Matches transaction/recurring rows: the bill's own category colour,
    // not one flat module accent for every bill — overdue still wins, since
    // that's the more urgent thing to notice.
    final color = overdue
        ? colors.critical
        : category != null
        ? (categoryColor(category!.colorHex) ??
              theme.colorScheme.onSurfaceVariant)
        : colors.finance;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => BillsScreen.openSheet(context, ref, existing: bill),
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
            : Icon(LucideIcons.receipt, size: 18, color: color),
      ),
      title: Text(
        bill.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${_frequencyLabels[bill.frequency] ?? bill.frequency} · '
        '${overdue ? "Overdue" : "Due"} ${DateFormat.yMMMd().format(bill.dueDate)}',
        style: TextStyle(color: overdue ? colors.critical : null),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMinor(bill.amountMinor, currencyCode: currencyCode),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Mark as paid',
            icon: const Icon(LucideIcons.circleCheck),
            onPressed: () => _markPaid(context, ref),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(LucideIcons.trash2),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _PayFromDialog extends StatefulWidget {
  const _PayFromDialog({
    required this.accounts,
    required this.accountTypes,
    required this.initialAccountId,
  });

  final List<Account> accounts;

  /// Supplies each account's glyph; see [OptionRow.account].
  final List<AccountType> accountTypes;
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
          for (final a in widget.accounts)
            DropdownMenuItem(
              value: a.id,
              child: OptionRow.account(a, widget.accountTypes),
            ),
        ],
        onChanged: (v) => setState(() => _accountId = v ?? _accountId),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _accountId),
          child: const Text('Mark paid'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateMessage(
      emoji: '🧾',
      title: 'No bills tracked yet',
      message:
          'Add a bill to get reminded before it\'s due, and mark it paid when it is.',
    );
  }
}
