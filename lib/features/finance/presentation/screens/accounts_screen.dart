import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/widgets/empty_state_message.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/finance_providers.dart';
import '../../data/finance_repository.dart';
import '../widgets/account_card.dart';
import '../widgets/add_account_flow.dart';
import 'account_detail_screen.dart';
import 'account_order_screen.dart';

/// Every account in one place: net worth on top, accounts grouped by type
/// with a total per group, and archived accounts folded away at the bottom.
/// Finance home only has room for a scrolling strip of them.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final visible = settings.balancesVisible;
    final currency = settings.currencyCode;
    final active = ref.watch(activeAccountsProvider);
    final archived = ref.watch(archivedAccountsProvider);
    final types = ref.watch(accountTypesProvider).value ?? const [];
    String money(int minor) => formatMinorMasked(
      minor,
      currencyCode: currency,
      visible: visible,
      showDecimals: false,
    );

    // Groups in the order the user's account types are listed, then any
    // type that isn't in that list, by name.
    final groups = <String, List<Account>>{};
    for (final a in active) {
      groups.putIfAbsent(normalizeAccountTypeKey(a.type), () => []).add(a);
    }
    final order = [
      for (final t in types) normalizeAccountTypeKey(t.name),
    ];
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a), ib = order.indexOf(b);
        if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
        if (ia >= 0) return -1;
        if (ib >= 0) return 1;
        return a.compareTo(b);
      });

    // Same split as Net worth: a card owed on counts as a liability.
    var assets = 0, liabilities = 0;
    for (final a in active) {
      final owed =
          normalizeAccountTypeKey(a.type) == 'credit card' &&
          a.balanceMinor < 0;
      if (owed) {
        liabilities += -a.balanceMinor;
      } else {
        assets += a.balanceMinor;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: visible ? 'Hide balances' : 'Show balances',
            icon: Icon(visible ? LucideIcons.eye : LucideIcons.eyeOff),
            onPressed: () => ref
                .read(settingsControllerProvider)
                .setBalancesVisible(!visible),
          ),
          if (active.length > 1)
            IconButton(
              tooltip: 'Account order',
              icon: const Icon(LucideIcons.arrowUpDown),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountOrderScreen()),
              ),
            ),
          IconButton(
            tooltip: 'Add account',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => addAccountFlow(context, ref),
          ),
        ],
      ),
      body: active.isEmpty && archived.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyStateMessage(
                    emoji: '🏦',
                    message: 'No accounts yet. Add your bank, cash or card.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => addAccountFlow(context, ref),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Add account'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _NetWorthCard(
                  total: money(assets - liabilities),
                  assets: money(assets),
                  liabilities: money(liabilities),
                  count: active.length,
                ),
                for (final key in keys) ...[
                  const SizedBox(height: 20),
                  _GroupHeader(
                    label: _typeLabel(groups[key]!.first.type, types),
                    total: money(
                      groups[key]!.fold(0, (s, a) => s + a.balanceMinor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AccountList(
                    accounts: groups[key]!,
                    types: types,
                    money: money,
                    defaultId: ref.watch(preferredAccountIdProvider),
                  ),
                ],
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        setState(() => _showArchived = !_showArchived),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _GroupLabel('Archived (${archived.length})'),
                          ),
                          AnimatedRotation(
                            turns: _showArchived ? 0.5 : 0,
                            duration: AppMotion.of(context, AppMotion.navColor),
                            child: const Icon(
                              LucideIcons.chevronDown,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: AppMotion.of(
                      context,
                      AppMotion.recurringReveal,
                    ),
                    alignment: Alignment.topCenter,
                    child: _showArchived
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _AccountList(
                              accounts: archived,
                              types: types,
                              money: money,
                              dimmed: true,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ],
            ),
    );
  }

  /// The type as the user named it in Account types, else the stored text.
  static String _typeLabel(String type, List<AccountType> types) {
    final key = normalizeAccountTypeKey(type);
    for (final t in types) {
      if (normalizeAccountTypeKey(t.name) == key) return t.name;
    }
    return type.isEmpty ? 'Other' : type[0].toUpperCase() + type.substring(1);
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.total,
    required this.assets,
    required this.liabilities,
    required this.count,
  });

  final String total;
  final String assets;
  final String liabilities;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    Widget split(String label, String value, Color ink) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.numeric,
              fontFeatures: AppFonts.tabular,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net worth · $count account${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                total,
                style: const TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                split('Assets', assets, colors.good),
                split('Owed on cards', liabilities, colors.critical),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.total});

  final String label;
  final String total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _GroupLabel(label)),
      Text(
        total,
        style: TextStyle(
          fontFamily: AppFonts.numeric,
          fontFeatures: AppFonts.tabular,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.accounts,
    required this.types,
    required this.money,
    this.defaultId,
    this.dimmed = false,
  });

  final List<Account> accounts;

  /// The account new entries start on, labelled "Default".
  final String? defaultId;
  final List<AccountType> types;
  final String Function(int minor) money;

  /// Archived accounts read as set aside.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < accounts.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 68),
            Opacity(
              opacity: dimmed ? 0.6 : 1,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconOrEmoji(
                    value: accountIconValueFor(accounts[i].type, types),
                    size: 19,
                    color: scheme.primary,
                  ),
                ),
                title: Text(
                  accounts[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: accounts[i].id == defaultId && !dimmed
                    ? const Text('Default')
                    : null,
                trailing: Text(
                  money(accounts[i].balanceMinor),
                  style: TextStyle(
                    fontFamily: AppFonts.numeric,
                    fontFeatures: AppFonts.tabular,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accounts[i].balanceMinor < 0
                        ? colors.critical
                        : scheme.onSurface,
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AccountDetailScreen(accountId: accounts[i].id),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
