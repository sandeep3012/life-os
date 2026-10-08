import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/finance_providers.dart';
import 'quick_add_account_sheet.dart';

/// "Add account" from anywhere: the account sheet, then the save. Shared by
/// Finance home and the Accounts screen so both add accounts the same way.
Future<void> addAccountFlow(BuildContext context, WidgetRef ref) async {
  final accountTypes = ref.read(accountTypesProvider).value ?? const [];
  final result = await showQuickAddAccountSheet(
    context,
    accountTypes: accountTypes,
    currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
  );
  if (result == null) return;
  await ref
      .read(financeControllerProvider)
      .addAccount(
        name: result.name,
        type: result.type,
        balanceMinor: result.startingBalanceMinor,
      );
}
