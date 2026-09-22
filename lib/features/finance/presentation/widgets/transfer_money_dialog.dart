import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/finance_providers.dart';
import 'account_option_row.dart';

/// Opens the one transfer flow used by both Finance home and the sidebar.
Future<void> showTransferMoneyDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final accounts = ref.read(transactableAccountsProvider);
  final accountTypes = ref.read(accountTypesProvider).value ?? const [];
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

  await ref
      .read(financeControllerProvider)
      .transfer(
        fromAccountId: fromId,
        toAccountId: toId,
        amountMinor: amount,
        date: DateTime.now(),
      );
}
