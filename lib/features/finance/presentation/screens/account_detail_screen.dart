import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../application/finance_providers.dart';
import '../widgets/account_card.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final account = ref
        .watch(accountsProvider)
        .value
        ?.where((a) => a.id == widget.accountId)
        .firstOrNull;

    if (account == null) {
      return const Scaffold(body: Center(child: Text('Account not found')));
    }

    final negative = account.balanceMinor < 0;

    return Scaffold(
      appBar: AppBar(title: Text(account.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.finance.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(accountIcon(account.type), color: colors.finance),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.name, style: theme.textTheme.titleMedium),
                            Text(
                              account.type,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    formatMinor(account.balanceMinor),
                    style: TextStyle(
                      fontFamily: 'PlexMono',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: negative ? colors.critical : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!account.isActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This account is archived. It\'s excluded from your balance total and hidden from new transactions.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: account.isActive
                ? OutlinedButton.icon(
                    onPressed: _busy ? null : () => _deactivate(account.id),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Deactivate account'),
                  )
                : FilledButton.icon(
                    onPressed: _busy ? null : () => _reactivate(account.id),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Reactivate account'),
                  ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _attemptDelete(account.id),
              style: TextButton.styleFrom(foregroundColor: colors.critical),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete account'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivate(String accountId) async {
    setState(() => _busy = true);
    await ref.read(financeControllerProvider).deactivateAccount(accountId);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reactivate(String accountId) async {
    setState(() => _busy = true);
    await ref.read(financeControllerProvider).reactivateAccount(accountId);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _attemptDelete(String accountId) async {
    setState(() => _busy = true);
    final usage = await ref.read(financeControllerProvider).checkAccountUsage(accountId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (usage.transactionCount > 0 || usage.goalLinkCount > 0) {
      final parts = [
        if (usage.transactionCount > 0)
          '${usage.transactionCount} transaction${usage.transactionCount == 1 ? '' : 's'}',
        if (usage.goalLinkCount > 0)
          '${usage.goalLinkCount} linked goal${usage.goalLinkCount == 1 ? '' : 's'}',
      ].join(' and ');

      if (!mounted) return;
      final deactivateInstead = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Can\'t delete this account'),
          content: Text(
            'This account still has $parts. Deleting it would lose that history, so delete is blocked — deactivate it instead to keep the history but hide it from balances and new transactions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Deactivate instead'),
            ),
          ],
        ),
      );
      if (deactivateInstead == true) await _deactivate(accountId);
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this account?'),
        content: const Text('This account has no transactions or linked goals. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await ref.read(financeControllerProvider).deleteAccount(accountId);
    if (mounted) Navigator.of(context).pop();
  }
}
