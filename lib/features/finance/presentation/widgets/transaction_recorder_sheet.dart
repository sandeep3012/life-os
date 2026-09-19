import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../settings/application/settings_providers.dart';
import 'entry_form_sheet.dart';
import 'quick_add_transaction_sheet.dart';

/// Opens the user's preferred transaction recorder and lets them change that
/// preference from inside either layout. Both the global add button and Finance
/// Home use this entry point so they never drift into separate workflows.
Future<QuickAddTransactionResult?> showTransactionRecorder(
  BuildContext context,
  WidgetRef ref, {
  required List<Account> accounts,
  required List<Category> categories,
  required String currencySymbol,
  EntryKind initialKind = EntryKind.expense,
}) async {
  var layout = ref.read(settingsProvider).transactionEntryLayout;

  while (true) {
    if (!context.mounted) return null;
    var switchRequested = false;
    if (layout == 'form') {
      final result = await showQuickAddTransactionSheet(
        context,
        accounts: accounts,
        categories: categories,
        currencySymbol: currencySymbol,
        initialIsExpense: initialKind == EntryKind.expense,
        onSwitchLayout: () async {
          switchRequested = true;
          await ref
              .read(settingsControllerProvider)
              .setTransactionEntryLayout('keypad');
        },
      );
      if (result != null) return result;
      if (!switchRequested) return null;
      layout = 'keypad';
      continue;
    }

    final result = await showEntryFormSheet(
      context,
      kind: initialKind,
      accounts: accounts,
      categories: categories,
      currencySymbol: currencySymbol,
      onSwitchLayout: () async {
        switchRequested = true;
        await ref
            .read(settingsControllerProvider)
            .setTransactionEntryLayout('form');
      },
    );
    if (result != null) {
      return QuickAddTransactionResult(
        accountId: result.accountId,
        categoryId: result.categoryId,
        merchant:
            result.note ?? (result.amountMinor < 0 ? 'Expense' : 'Income'),
        amountMinor: result.amountMinor,
        date: result.date,
        paymentMode: result.paymentMode,
      );
    }
    if (!switchRequested) return null;
    layout = 'form';
  }
}
