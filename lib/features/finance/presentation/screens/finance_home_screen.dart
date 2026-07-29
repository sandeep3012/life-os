import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../spend_analyzer/presentation/widgets/budget_bar.dart';
import '../../application/finance_providers.dart';
import '../../domain/budget_progress.dart';
import '../widgets/account_card.dart';
import '../widgets/quick_add_account_sheet.dart';
import '../widgets/quick_add_budget_sheet.dart';
import '../widgets/quick_add_transaction_sheet.dart';
import '../widgets/transaction_tile.dart';
import 'account_detail_screen.dart';
import 'archived_accounts_screen.dart';

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
    final activeAccounts = ref.watch(activeAccountsProvider);
    final archivedCount = ref.watch(archivedAccountsProvider).length;
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeAccounts.isEmpty
                                    ? 'No accounts yet'
                                    : 'Across ${activeAccounts.length} account${activeAccounts.length == 1 ? '' : 's'}',
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
                        if (archivedCount > 0)
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ArchivedAccountsScreen()),
                            ),
                            icon: const Icon(Icons.archive_outlined, size: 18),
                            label: Text('Archived ($archivedCount)'),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: activeAccounts.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        if (index == activeAccounts.length) {
                          return AddAccountCard(onTap: () => _addAccount(context, ref));
                        }
                        final account = activeAccounts[index];
                        return AccountCard(
                          account: account,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AccountDetailScreen(accountId: account.id),
                            ),
                          ),
                        );
                      },
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
    final accounts = ref.read(activeAccountsProvider);
    if (accounts.isEmpty) return 'New account';
    return _section == _FinanceSection.transactions ? 'New transaction' : 'New budget';
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final result = await showQuickAddAccountSheet(context);
    if (result == null) return;
    await ref.read(financeControllerProvider).addAccount(
      name: result.name,
      type: result.type,
      balanceMinor: result.startingBalanceMinor,
    );
  }

  Future<void> _handleFab(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(activeAccountsProvider);
    if (accounts.isEmpty) {
      await _addAccount(context, ref);
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
        date: result.date,
      );
    } else {
      final categories = ref.read(categoriesProvider).value ?? const [];
      final result = await showQuickAddBudgetSheet(context, categories: categories);
      if (result == null) return;
      await ref.read(financeControllerProvider).addBudget(
        categoryId: result.categoryId,
        limitMinor: result.limitMinor,
        period: result.period,
        effectiveMonth: result.effectiveMonth,
      );
    }
  }
}

/// Delay before a swiped-away transaction/budget is actually deleted from the
/// database, giving the snackbar's Undo button a window to cancel it.
const _undoWindow = Duration(seconds: 4);

class _TransactionsSliver extends ConsumerStatefulWidget {
  const _TransactionsSliver({required this.categoryById});

  final Map<String, Category> categoryById;

  @override
  ConsumerState<_TransactionsSliver> createState() => _TransactionsSliverState();
}

class _TransactionsSliverState extends ConsumerState<_TransactionsSliver> {
  final Set<String> _pendingDeleteIds = {};
  final Map<String, Timer> _timers = {};

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = (ref.watch(transactionsProvider).value ?? const [])
        .where((t) => !_pendingDeleteIds.contains(t.id))
        .toList();

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
          return Dismissible(
            key: ValueKey(t.id),
            direction: DismissDirection.endToStart,
            background: const _SwipeDeleteBackground(),
            onDismissed: (_) => _scheduleDelete(t),
            child: TransactionTile(
              transaction: t,
              category: widget.categoryById[t.categoryId],
              onEdit: () => _editTransaction(t),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editTransaction(Transaction t) async {
    final accounts = ref.read(activeAccountsProvider);
    final categories = ref.read(categoriesProvider).value ?? const [];
    final result = await showQuickAddTransactionSheet(
      context,
      accounts: accounts,
      categories: categories,
      initial: t,
    );
    if (result == null) return;
    await ref.read(financeControllerProvider).updateTransaction(
      id: t.id,
      accountId: result.accountId,
      categoryId: result.categoryId,
      merchant: result.merchant,
      amountMinor: result.amountMinor,
      date: result.date,
    );
  }

  void _scheduleDelete(Transaction t) {
    setState(() => _pendingDeleteIds.add(t.id));
    _timers[t.id] = Timer(_undoWindow, () async {
      _timers.remove(t.id);
      await ref.read(financeControllerProvider).deleteTransaction(t.id);
      if (mounted) setState(() => _pendingDeleteIds.remove(t.id));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${t.merchant}"'),
        duration: _undoWindow,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _timers.remove(t.id)?.cancel();
            if (mounted) setState(() => _pendingDeleteIds.remove(t.id));
          },
        ),
      ),
    );
  }
}

class _BudgetsSliver extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BudgetsSliver> createState() => _BudgetsSliverState();
}

class _BudgetsSliverState extends ConsumerState<_BudgetsSliver> {
  final Set<String> _pendingDeleteIds = {};
  final Map<String, Timer> _timers = {};

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref
        .watch(budgetsWithProgressProvider)
        .where((p) => !_pendingDeleteIds.contains(p.budget.id))
        .toList();

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
        children: [
          for (final p in progress)
            Dismissible(
              key: ValueKey(p.budget.id),
              direction: DismissDirection.endToStart,
              background: const _SwipeDeleteBackground(),
              onDismissed: (_) => _scheduleDelete(p),
              child: BudgetBar(progress: p, onEdit: () => _editBudget(p)),
            ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BudgetProgress p) async {
    final categories = ref.read(categoriesProvider).value ?? const [];
    final result = await showQuickAddBudgetSheet(context, categories: categories, initial: p.budget);
    if (result == null) return;
    await ref.read(financeControllerProvider).updateBudget(
      id: p.budget.id,
      categoryId: result.categoryId,
      limitMinor: result.limitMinor,
      period: result.period,
      effectiveMonth: result.effectiveMonth,
    );
  }

  void _scheduleDelete(BudgetProgress p) {
    setState(() => _pendingDeleteIds.add(p.budget.id));
    _timers[p.budget.id] = Timer(_undoWindow, () async {
      _timers.remove(p.budget.id);
      await ref.read(financeControllerProvider).deleteBudget(p.budget.id);
      if (mounted) setState(() => _pendingDeleteIds.remove(p.budget.id));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${p.category.name}" budget'),
        duration: _undoWindow,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _timers.remove(p.budget.id)?.cancel();
            if (mounted) setState(() => _pendingDeleteIds.remove(p.budget.id));
          },
        ),
      ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Theme.of(context).colorScheme.error,
      child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onError),
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
