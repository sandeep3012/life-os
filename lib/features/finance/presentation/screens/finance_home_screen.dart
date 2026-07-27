import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../spend_analyzer/presentation/widgets/budget_bar.dart';
import '../../application/finance_providers.dart';
import '../widgets/account_card.dart';
import '../widgets/quick_add_account_sheet.dart';
import '../widgets/quick_add_budget_sheet.dart';
import '../widgets/quick_add_transaction_sheet.dart';
import '../widgets/transaction_tile.dart';

enum _FinanceSection { transactions, budgets }

class FinanceHomeScreen extends ConsumerStatefulWidget {
  const FinanceHomeScreen({super.key});

  @override
  ConsumerState<FinanceHomeScreen> createState() => _FinanceHomeScreenState();
}

class _FinanceHomeScreenState extends ConsumerState<FinanceHomeScreen> {
  _FinanceSection _section = _FinanceSection.transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final totalBalance = ref.watch(totalBalanceMinorProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryById = {for (final c in categories) c.id: c};

    return Scaffold(
      body: SafeArea(
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load accounts: $e')),
          data: (accounts) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accounts.isEmpty ? 'No accounts yet' : 'Across ${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          formatMinor(totalBalance),
                          style: theme.textTheme.headlineMedium?.copyWith(fontFamily: 'Fraunces'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (accounts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: accounts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => AccountCard(account: accounts[index]),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<_FinanceSection>(
                            segments: const [
                              ButtonSegment(
                                value: _FinanceSection.transactions,
                                label: Text('Transactions'),
                              ),
                              ButtonSegment(
                                value: _FinanceSection.budgets,
                                label: Text('Budgets'),
                              ),
                            ],
                            selected: {_section},
                            onSelectionChanged: (s) => setState(() => _section = s.first),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Spend Analyzer',
                          icon: const Icon(Icons.insights_rounded),
                          onPressed: () => context.push(RoutePaths.spendAnalyzer),
                        ),
                      ],
                    ),
                  ),
                ),
                if (accounts.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyAccountsState(),
                  )
                else if (_section == _FinanceSection.transactions)
                  _TransactionsSliver(categoryById: categoryById)
                else
                  _BudgetsSliver(),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleFab(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(_fabLabel(ref)),
      ),
    );
  }

  String _fabLabel(WidgetRef ref) {
    final accounts = ref.read(accountsProvider).value ?? const [];
    if (accounts.isEmpty) return 'New account';
    return _section == _FinanceSection.transactions ? 'New transaction' : 'New budget';
  }

  Future<void> _handleFab(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(accountsProvider).value ?? const [];
    if (accounts.isEmpty) {
      final result = await showQuickAddAccountSheet(context);
      if (result == null) return;
      await ref.read(financeControllerProvider).addAccount(
        name: result.name,
        type: result.type,
        balanceMinor: result.startingBalanceMinor,
      );
      return;
    }

    if (_section == _FinanceSection.transactions) {
      final categories = ref.read(categoriesProvider).value ?? const [];
      final result = await showQuickAddTransactionSheet(
        context,
        accounts: accounts,
        categories: categories,
      );
      if (result == null) return;
      await ref.read(financeControllerProvider).addTransaction(
        accountId: result.accountId,
        categoryId: result.categoryId,
        merchant: result.merchant,
        amountMinor: result.amountMinor,
      );
    } else {
      final categories = ref.read(categoriesProvider).value ?? const [];
      final result = await showQuickAddBudgetSheet(context, categories: categories);
      if (result == null) return;
      await ref.read(financeControllerProvider).addBudget(
        categoryId: result.categoryId,
        limitMinor: result.limitMinor,
        period: result.period,
      );
    }
  }
}

class _TransactionsSliver extends ConsumerWidget {
  const _TransactionsSliver({required this.categoryById});

  final Map<String, Category> categoryById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider).value ?? const [];

    if (transactions.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          icon: Icons.receipt_long_rounded,
          message: 'No transactions yet — add one to get started.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      sliver: SliverList.separated(
        itemCount: transactions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final t = transactions[index];
          return TransactionTile(transaction: t, category: categoryById[t.categoryId]);
        },
      ),
    );
  }
}

class _BudgetsSliver extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetsWithProgressProvider);

    if (progress.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          icon: Icons.pie_chart_rounded,
          message: 'No budgets yet — add one to track spending.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      sliver: SliverList.list(
        children: [for (final p in progress) BudgetBar(progress: p)],
      ),
    );
  }
}

class _EmptyAccountsState extends StatelessWidget {
  const _EmptyAccountsState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.account_balance_wallet_rounded,
      message: 'Add your first account to start tracking finances.',
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
