import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/finance_providers.dart';
import '../../data/finance_repository.dart';
import '../widgets/account_card.dart';

/// Accounts → Order & default: drag the active accounts into the order every
/// account picker uses, and star the one a new entry starts on. With no star,
/// a new entry starts on the account used last.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Order & default')),
      body: accounts.isEmpty
          ? const Center(child: Text('No accounts yet.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              buildDefaultDragHandles: false,
              itemCount: accounts.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _onReorder(accounts, oldIndex, newIndex),
              header: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Drag to set the order accounts are listed in. Star one to '
                  'start every new entry on it; with none starred, entries '
                  'start on the account you used last.',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              itemBuilder: (context, index) {
                final a = accounts[index];
                // Investments never take a payment, so they can't be the
                // account an entry starts on.
                final canBeDefault =
                    normalizeAccountTypeKey(a.type) != 'investment';
                return Material(
                  key: ValueKey(a.id),
                  color: scheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
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
                        title: Text(
                          a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: a.isDefault ? const Text('Default') : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canBeDefault)
                              IconButton(
                                tooltip: a.isDefault
                                    ? 'Remove ${a.name} as default'
                                    : 'Make ${a.name} the default',
                                onPressed: () => ref
                                    .read(financeControllerProvider)
                                    .setDefaultAccount(
                                      a.isDefault ? null : a.id,
                                    ),
                                icon: Icon(
                                  LucideIcons.star,
                                  color: a.isDefault
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                  fill: a.isDefault ? 1 : 0,
                                ),
                              ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Tooltip(
                                message: 'Drag to reorder ${a.name}',
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(LucideIcons.gripVertical),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < accounts.length - 1)
                        const Divider(height: 1, indent: 52),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
