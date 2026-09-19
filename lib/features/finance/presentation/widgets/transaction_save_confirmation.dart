import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/save_feedback.dart';
import 'quick_add_transaction_sheet.dart';

/// Uses one confirmation for every successful transaction entry point.
Future<void> showTransactionSaveConfirmation(
  BuildContext context, {
  required WidgetRef ref,
  required QuickAddTransactionResult result,
  required List<Account> accounts,
  required String currencyCode,
  bool updated = false,
}) {
  final account = accounts.where((item) => item.id == result.accountId);
  final destination = account.isEmpty ? 'your ledger' : account.first.name;
  final amount = formatMinor(
    result.amountMinor.abs(),
    currencyCode: currencyCode,
    showDecimals: false,
  );
  return showSaveFeedback(
    context,
    ref,
    title: result.amountMinor > 0
        ? updated
            ? 'Income updated'
            : 'Income saved'
        : updated
        ? 'Expense updated'
        : 'Expense saved',
    message: updated
        ? '$amount updated in $destination.'
        : '$amount logged to $destination.',
  );
}
