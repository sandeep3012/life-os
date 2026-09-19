import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/success_overlay.dart';
import 'quick_add_transaction_sheet.dart';

/// Uses one confirmation for every successful transaction entry point.
Future<void> showTransactionSaveConfirmation(
  BuildContext context, {
  required QuickAddTransactionResult result,
  required List<Account> accounts,
  required String currencyCode,
}) {
  final account = accounts.where((item) => item.id == result.accountId);
  final destination = account.isEmpty ? 'your ledger' : account.first.name;
  final amount = formatMinor(
    result.amountMinor.abs(),
    currencyCode: currencyCode,
    showDecimals: false,
  );
  return showSuccessOverlay(
    context,
    title: result.amountMinor > 0 ? 'Income saved' : 'Expense saved',
    message: '$amount logged to $destination.',
  );
}
