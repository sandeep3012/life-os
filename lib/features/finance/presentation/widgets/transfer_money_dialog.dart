import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/finance_providers.dart';
import 'account_option_row.dart';

/// Opens the one transfer flow used by both Finance home and the sidebar.
///
/// Takes no `WidgetRef`: the sidebar opens this after its drawer has closed,
/// by which point the sidebar — and any ref it could pass — is disposed, and
/// reading through it throws. The app's provider container, found from
/// [context], outlives both callers.
Future<void> showTransferMoneyDialog(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // From the sidebar, no screen may have loaded the accounts yet; with nothing
  // listening they'd read as empty ("add at least two accounts"). Hold
  // subscriptions for the whole flow and wait for the first values.
  final accountsSub = container.listen(accountsProvider, (_, _) {});
  final typesSub = container.listen(accountTypesProvider, (_, _) {});
  try {
    await container.read(accountsProvider.future);
    await container.read(accountTypesProvider.future);
    if (!context.mounted) return;
    await _transfer(context, container);
  } finally {
    accountsSub.close();
    typesSub.close();
  }
}

Future<void> _transfer(
  BuildContext context,
  ProviderContainer container,
) async {
  final accounts = container.read(transactableAccountsProvider);
  final accountTypes = container.read(accountTypesProvider).value ?? const [];
  if (accounts.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add at least two active accounts to transfer money.'),
      ),
    );
    return;
  }

  final amountController = TextEditingController();
  String fromId = accounts.first.id;
  String toId = accounts[1].id;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final valid =
            fromId != toId &&
            (double.tryParse(amountController.text.trim()) ?? 0) > 0;
        return AlertDialog(
          title: const Text('Transfer money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: fromId,
                decoration: const InputDecoration(labelText: 'From account'),
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: OptionRow.account(account, accountTypes),
                    ),
                ],
                onChanged: (value) => setState(() => fromId = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: toId,
                decoration: const InputDecoration(labelText: 'To account'),
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: OptionRow.account(account, accountTypes),
                    ),
                ],
                onChanged: (value) => setState(() => toId = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Transfer'),
            ),
          ],
        );
      },
    ),
  );
  final amount = ((double.tryParse(amountController.text.trim()) ?? 0) * 100)
      .round();
  Future<void>.delayed(
    const Duration(milliseconds: 400),
    amountController.dispose,
  );
  if (confirmed != true || amount <= 0) return;

  await container
      .read(financeControllerProvider)
      .transfer(
        fromAccountId: fromId,
        toAccountId: toId,
        amountMinor: amount,
        date: DateTime.now(),
      );
  if (!context.mounted) return;
  String nameOf(String id) => accounts.firstWhere((a) => a.id == id).name;
  final money = formatMinor(
    amount,
    currencyCode: container.read(settingsProvider).currencyCode,
  );
  await showSaveFeedbackIn(
    context,
    title: 'Transfer complete',
    message: '$money moved from ${nameOf(fromId)} to ${nameOf(toId)}.',
  );
}
