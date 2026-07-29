import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/finance_providers.dart';
import '../widgets/account_card.dart';
import 'account_detail_screen.dart';

class ArchivedAccountsScreen extends ConsumerWidget {
  const ArchivedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archived accounts')),
      body: archived.isEmpty
          ? Center(
              child: Text(
                'No archived accounts.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: archived.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final account = archived[index];
                return SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AccountCard(
                      account: account,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccountDetailScreen(accountId: account.id),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
