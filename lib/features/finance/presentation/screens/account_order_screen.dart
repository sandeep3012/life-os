import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/haptics.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/widgets/reorder_card.dart';
import '../../application/finance_providers.dart';
import '../../data/finance_repository.dart';
import '../widgets/account_card.dart';

/// Accounts → Order: drag the active accounts into the order every account
/// picker uses. The top one a payment can come from is what a new entry
/// starts on.
class AccountOrderScreen extends ConsumerStatefulWidget {
  const AccountOrderScreen({super.key});

  @override
  ConsumerState<AccountOrderScreen> createState() => _AccountOrderScreenState();
}

class _AccountOrderScreenState extends ConsumerState<AccountOrderScreen> {
  /// The order just dropped, shown until the database's stream catches up —
  /// without it the row would jump back for a frame before settling.
  List<Account>? _dropped;

  void _onReorder(List<Account> accounts, int oldIndex, int newIndex) {
    final next = List.of(accounts);
    next.insert(newIndex, next.removeAt(oldIndex));
    setState(() => _dropped = next);
    ref.read(hapticsProvider).light();
    ref
        .read(financeControllerProvider)
        .reorderAccounts([for (final a in next) a.id]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeAccountsProvider, (_, _) {
      if (_dropped != null) setState(() => _dropped = null);
    });
    final scheme = Theme.of(context).colorScheme;
    final List<Account> accounts =
        _dropped ?? ref.watch(activeAccountsProvider);
    final types = ref.watch(accountTypesProvider).value ?? const [];
    // Investments can't be paid from, so the default is the first that can.
    final defaultId = accounts
        .where((a) => normalizeAccountTypeKey(a.type) != 'investment')
        .firstOrNull
        ?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Account order')),
      body: accounts.isEmpty
          ? const Center(child: Text('No accounts yet.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              buildDefaultDragHandles: false,
              proxyDecorator: ReorderCard.decorateDragged,
              onReorderStart: (_) => ref.read(hapticsProvider).selection(),
              itemCount: accounts.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _onReorder(accounts, oldIndex, newIndex),
              header: const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: ReorderHint(
                  'Hold any account and drag it. The one at the top is '
                  'picked first when you add a transaction.',
                ),
              ),
              itemBuilder: (context, index) {
                final a = accounts[index];
                return ReorderCard(
                  key: ValueKey(a.id),
                  index: index,
                  title: a.name,
                  isDefault: a.id == defaultId,
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconOrEmoji(
                      value: accountIconValueFor(a.type, types),
                      size: 19,
                      color: scheme.primary,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
