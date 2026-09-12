import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../settings/application/settings_providers.dart';
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
import '../../../../app/theme/app_fonts.dart';

enum _FinanceSection { transactions, budgets }

DateTimeRange _lastThirtyDays() {
  final today = dateOnly(DateTime.now());
  return DateTimeRange(start: DateTime(today.year, today.month, today.day - 29), end: today);
}

String _rangeLabel(DateTimeRange range) =>
    '${DateFormat.yMMMd().format(range.start)} – ${DateFormat.yMMMd().format(range.end)}';

List<Transaction> _filterTransactions(List<Transaction> source, DateTimeRange? range, Set<String> categories) {
  final endExclusive = range == null ? null : DateTime(range.end.year, range.end.month, range.end.day + 1);
  return source.where((t) {
    if (range != null && (t.date.isBefore(dateOnly(range.start)) || !t.date.isBefore(endExclusive!))) return false;
    final category = t.paymentMode == 'transfer' ? '__transfer__' : t.categoryId ?? '__uncategorized__';
    return categories.isEmpty || categories.contains(category);
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
}

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  DateTimeRange? _range = _lastThirtyDays();
  String _preset = 'Last 30 days';
  Set<String> _categories = {};

  Future<void> _selectRange(String preset) async {
    final today = dateOnly(DateTime.now());
    DateTimeRange? range;
    switch (preset) {
      case 'Last 30 days':
        range = _lastThirtyDays();
        break;
      case 'This month':
        range = DateTimeRange(start: DateTime(today.year, today.month), end: today);
        break;
      case 'Last month':
        range = DateTimeRange(start: DateTime(today.year, today.month - 1), end: DateTime(today.year, today.month, 0));
        break;
      case 'This year':
        range = DateTimeRange(start: DateTime(today.year), end: today);
        break;
      case 'Custom range':
        final transactions = ref.read(transactionsProvider).value ?? const <Transaction>[];
        var first = DateTime(1900);
        var last = DateTime(today.year + 10, 12, 31);
        for (final t in transactions) {
          if (t.date.isBefore(first)) first = dateOnly(t.date);
          if (t.date.isAfter(last)) last = dateOnly(t.date);
        }
        range = await showDateRangePicker(context: context, firstDate: first, lastDate: last, initialDateRange: _range);
        if (range == null || !mounted) return;
        break;
      case 'All time':
        range = null;
        break;
    }
    if (mounted) setState(() { _range = range; _preset = preset; });
  }

  Future<void> _selectCategories(List<Category> categories) async {
    final selected = {..._categories};
    final choices = <String, String>{for (final c in categories) c.id: c.name,
      '__uncategorized__': 'Uncategorized', '__transfer__': 'Transfers'};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, update) => SafeArea(
        child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.65, child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Filter categories', style: Theme.of(context).textTheme.titleLarge)),
          CheckboxListTile(title: const Text('All categories'), value: selected.isEmpty, onChanged: (_) => update(selected.clear)),
          Expanded(child: ListView(children: [for (final entry in choices.entries)
            CheckboxListTile(title: Text(entry.value), value: selected.contains(entry.key), onChanged: (checked) => update(() {
              if (checked == true) { selected.add(entry.key); } else { selected.remove(entry.key); }
            })),
          ])),
          Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => Navigator.pop(sheetContext, selected), child: const Text('Apply filters'),
          ))),
        ])),
      )),
    );
    if (result != null && mounted) setState(() => _categories = result);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final data = ref.watch(transactionsProvider);
    final currency = ref.watch(settingsProvider).currencyCode;
    final filtered = _filterTransactions(data.value ?? const [], _range, _categories);
    final ordinary = filtered.where((t) => t.paymentMode != 'transfer');
    final income = ordinary.where((t) => t.amountMinor > 0).fold<int>(0, (sum, t) => sum + t.amountMinor);
    final spend = ordinary.where((t) => t.amountMinor < 0).fold<int>(0, (sum, t) => sum - t.amountMinor);
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction history')),
      body: SafeArea(top: false, child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 12, runSpacing: 8, children: [
              PopupMenuButton<String>(onSelected: _selectRange,
                itemBuilder: (_) => [for (final label in ['Last 30 days', 'This month', 'Last month', 'This year', 'All time', 'Custom range'])
                  PopupMenuItem(value: label, child: Text(label))],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.calendarDays, size: 18),
                    const SizedBox(width: 8), Text(_preset),
                    const Icon(LucideIcons.chevronDown, size: 18),
                  ]),
                ),
              ),
              OutlinedButton.icon(onPressed: () => _selectCategories(categories), icon: const Icon(LucideIcons.listFilter),
                label: Text(_categories.isEmpty ? 'All categories' : '${_categories.length} selected')),
            ]),
            const SizedBox(height: 8),
            Text(_range == null ? 'All dates' : _rangeLabel(_range!)),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Expanded(child: _MonthAmount(label: 'Income', value: income, color: context.appColors.good, currencyCode: currency)),
              const SizedBox(width: 24),
              Expanded(child: _MonthAmount(label: 'Spending', value: spend, color: context.appColors.critical, currencyCode: currency)),
            ]))),
            const SizedBox(height: 8),
            Text('Transfers excluded from totals', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 20),
            Text('${filtered.length} transactions'),
          ],
        ))),
        if (data.isLoading) const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
        else if (data.hasError) const SliverToBoxAdapter(child: Center(child: Text('Could not load transactions.')))
        else _TransactionsSliver(history: true, range: _range, categoryIds: _categories,
          categoryById: {for (final c in categories) c.id: c}, currencyCode: currency),
      ])),
    );
  }
}

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
    // Keeps the account-types stream subscribed (and its `.value` populated)
    // for the whole time this screen is up, so `_addAccount`'s `ref.read`
    // never races an unstarted stream and hands the sheet an empty list —
    // same class of bug as the unwatched-StreamProvider gotcha documented
    // for AiAnalyserController.refresh() in CLAUDE.md.
    ref.watch(accountTypesProvider);
    final totalBalance = ref.watch(totalBalanceMinorProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryById = {for (final c in categories) c.id: c};
    final currencyCode = ref.watch(settingsProvider).currencyCode;
    final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
    final monthEnd = DateTime(DateTime.now().year, DateTime.now().month + 1);
    final monthIncome = transactions
        .where((t) => t.paymentMode != 'transfer' && !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd) && t.amountMinor > 0)
        .fold<int>(0, (sum, t) => sum + t.amountMinor);
    final monthSpend = transactions
        .where((t) => t.paymentMode != 'transfer' && !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd) && t.amountMinor < 0)
        .fold<int>(0, (sum, t) => sum + t.amountMinor.abs());

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
                                formatMinor(totalBalance, currencyCode: currencyCode),
                                style: theme.textTheme.headlineMedium?.copyWith(fontFamily: AppFonts.serif),
                              ),
                            ],
                          ),
                        ),
                        if (archivedCount > 0)
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ArchivedAccountsScreen()),
                            ),
                            icon: const Icon(LucideIcons.archive, size: 18),
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
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(DateFormat('MMMM yyyy').format(monthStart), style: theme.textTheme.titleSmall)),
                          Expanded(child: _MonthAmount(label: 'Income', value: monthIncome, color: context.appColors.good, currencyCode: currencyCode)),
                          Expanded(child: _MonthAmount(label: 'Spend', value: monthSpend, color: context.appColors.critical, currencyCode: currencyCode)),
                        ],
                      ),
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
                          tooltip: 'More',
                          icon: const Icon(LucideIcons.ellipsis),
                          onPressed: () => _showFinanceMenu(context),
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
                  _TransactionsSliver(categoryById: categoryById, currencyCode: currencyCode)
                else
                  _BudgetsSliver(),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // `_fabLabel` is the label that matches what `_handleFab` actually does:
        // with no accounts yet the button opens the *account* sheet, so an
        // inlined "New transaction" tooltip described the wrong action.
        tooltip: _fabLabel(ref),
        onPressed: () => _handleFab(context, ref),
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  void _showFinanceMenu(BuildContext context) {
    final hostContext = context;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.chartLine),
              title: const Text('Spend Analyzer'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(RoutePaths.spendAnalyzer);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trendingUp),
              title: const Text('Net worth'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(RoutePaths.netWorth);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.receipt),
              title: const Text('Bills'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(RoutePaths.bills);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.refreshCw),
              title: const Text('Recurring transactions'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(RoutePaths.recurringTransactions);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.arrowLeftRight),
              title: const Text('Transfer between accounts'),
              onTap: () {
                Navigator.of(context).pop();
                // Deferred so the sheet finishes closing before the dialog
                // opens. `hostContext` is this screen's context, not the
                // sheet's, and the `mounted` check below covers the gap — but
                // the lint only tracks `context` itself, so a captured context
                // can't be proven safe to it.
                Future.microtask(() {
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  _showTransferDialog(hostContext);
                });
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.clipboardList),
              title: const Text('Reports'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(RoutePaths.reports);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransferDialog(BuildContext context) async {
    final accounts = ref.read(transactableAccountsProvider);
    if (accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least two active accounts to transfer money.')));
      return;
    }
    final amountController = TextEditingController();
    String fromId = accounts.first.id;
    String toId = accounts[1].id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setState) {
        final valid = fromId != toId && (double.tryParse(amountController.text.trim()) ?? 0) > 0;
        return AlertDialog(
          title: const Text('Transfer money'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(initialValue: fromId, decoration: const InputDecoration(labelText: 'From account'), items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))], onChanged: (v) => setState(() => fromId = v!)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: toId, decoration: const InputDecoration(labelText: 'To account'), items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))], onChanged: (v) => setState(() => toId = v!)),
            const SizedBox(height: 12),
            TextField(controller: amountController, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: valid ? () => Navigator.pop(dialogContext, true) : null, child: const Text('Transfer'))],
        );
      }),
    );
    final amount = ((double.tryParse(amountController.text.trim()) ?? 0) * 100).round();
    // The dialog route is still animating out when showDialog completes. Keep
    // the controller alive until that transition has finished; disposing it
    // immediately causes TextField to rebuild against a dead controller.
    Future<void>.delayed(const Duration(milliseconds: 400), amountController.dispose);
    if (confirmed != true || amount <= 0) return;
    await ref.read(financeControllerProvider).transfer(fromAccountId: fromId, toAccountId: toId, amountMinor: amount, date: DateTime.now());
  }

  String _fabLabel(WidgetRef ref) {
    final accounts = ref.read(activeAccountsProvider);
    if (accounts.isEmpty) return 'New account';
    return _section == _FinanceSection.transactions ? 'New transaction' : 'New budget';
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final accountTypes = ref.read(accountTypesProvider).value ?? const [];
    final result = await showQuickAddAccountSheet(
      context,
      accountTypes: accountTypes,
      currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
    );
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
      final transactableAccounts = ref.read(transactableAccountsProvider);
      if (transactableAccounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add a non-investment account first to record transactions.'),
          ),
        );
        return;
      }
      final categories = ref.read(categoriesProvider).value ?? const [];
      final result = await showQuickAddTransactionSheet(
        context,
        accounts: transactableAccounts,
        categories: categories,
        currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
      );
      if (result == null) return;
      await ref.read(financeControllerProvider).addTransaction(
        accountId: result.accountId,
        categoryId: result.categoryId,
        merchant: result.merchant,
        amountMinor: result.amountMinor,
        date: result.date,
        paymentMode: result.paymentMode,
      );
    } else {
      final categories = ref.read(categoriesProvider).value ?? const [];
      final result = await showQuickAddBudgetSheet(
        context,
        categories: categories,
        currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
      );
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

class _MonthAmount extends StatelessWidget {
  const _MonthAmount({required this.label, required this.value, required this.color, required this.currencyCode});

  final String label;
  final int value;
  final Color color;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          formatMinor(value, currencyCode: currencyCode, showDecimals: false),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Delay before a swiped-away transaction/budget is actually deleted from the
/// database, giving the snackbar's Undo button a window to cancel it.
const _undoWindow = Duration(seconds: 4);

class _DateHeader extends StatelessWidget {
  const _DateHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _TransactionsSliver extends ConsumerStatefulWidget {
  const _TransactionsSliver({required this.categoryById, required this.currencyCode, this.history = false, this.range, this.categoryIds = const {}});

  final Map<String, Category> categoryById;
  final String currencyCode;
  final bool history;
  final DateTimeRange? range;
  final Set<String> categoryIds;

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
    final range = widget.history ? widget.range : _lastThirtyDays();
    final transactions = _filterTransactions(
        ref.watch(transactionsProvider).value ?? const <Transaction>[],
        range, widget.categoryIds)
        .where((t) => !_pendingDeleteIds.contains(t.id))
        .toList();
    final entries = <Object>[];
    DateTime? previous;
    for (final transaction in transactions) {
      final day = dateOnly(transaction.date);
      if (previous == null || day != previous) {
        entries.add(_DateHeader(_dateLabel(day)));
        previous = day;
      }
      entries.add(transaction);
    }
    if (transactions.isEmpty) {
      entries.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text('No transactions in this range. Try another date range or category.'),
      ));
    }
    if (!widget.history) {
      entries.add(Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 24),
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
            builder: (_) => const TransactionHistoryScreen(),
          )),
          icon: const Icon(LucideIcons.arrowRight),
          label: const Text('See all transactions'),
        ),
      ));
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final entry = entries[index];
          if (entry is Widget) return entry;
          final t = entry as Transaction;
          return Dismissible(
            key: ValueKey(t.id),
            direction: DismissDirection.endToStart,
            background: const _SwipeDeleteBackground(),
            onDismissed: (_) => _scheduleDelete(t),
            child: TransactionTile(
              transaction: t,
              category: widget.categoryById[t.categoryId],
              currencyCode: widget.currencyCode,
              onEdit: () => _editTransaction(t),
            ),
          );
        }, childCount: entries.length),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return 'Today';
    if (isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _editTransaction(Transaction t) async {
    final transactableAccounts = ref.read(transactableAccountsProvider);
    // Keep the transaction's current account selectable even if it's an
    // investment account (or otherwise no longer transactable) — it was
    // valid when the transaction was recorded, and dropping it from the
    // list here would silently reassign the transaction on save.
    final currentAccount = ref
        .read(accountsProvider)
        .value
        ?.where((a) => a.id == t.accountId)
        .firstOrNull;
    final accounts = [
      ...transactableAccounts,
      if (currentAccount != null && !transactableAccounts.any((a) => a.id == currentAccount.id))
        currentAccount,
    ];
    final categories = ref.read(categoriesProvider).value ?? const [];
    final result = await showQuickAddTransactionSheet(
      context,
      accounts: accounts,
      categories: categories,
      currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
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
      paymentMode: result.paymentMode,
    );
  }

  void _scheduleDelete(Transaction t) {
    setState(() => _pendingDeleteIds.add(t.id));
    final messenger = ScaffoldMessenger.of(context);
    _timers[t.id] = Timer(_undoWindow, () async {
      _timers.remove(t.id);
      // Dismissed explicitly here rather than left to the SnackBar's own
      // `duration` timer: that timer is Ticker-driven, so it silently stalls
      // if this route is offstage (e.g. the user switched bottom-nav tabs)
      // — leaving the bar stuck on screen well past the undo window. Our
      // own wall-clock Timer isn't affected, so tying dismissal to it keeps
      // "hidden" and "actually deleted" in sync regardless of tab state.
      messenger.hideCurrentSnackBar();
      await ref.read(financeControllerProvider).deleteTransaction(t.id);
      if (mounted) setState(() => _pendingDeleteIds.remove(t.id));
    });

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${t.merchant}"'),
          duration: _undoWindow,
          behavior: SnackBarBehavior.floating,
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
    final currencyCode = ref.watch(settingsProvider).currencyCode;

    if (progress.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          icon: LucideIcons.pieChart,
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
              child: BudgetBar(progress: p, currencyCode: currencyCode, onEdit: () => _editBudget(p)),
            ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BudgetProgress p) async {
    final categories = ref.read(categoriesProvider).value ?? const [];
    final result = await showQuickAddBudgetSheet(
      context,
      categories: categories,
      currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
      initial: p.budget,
    );
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
    final messenger = ScaffoldMessenger.of(context);
    _timers[p.budget.id] = Timer(_undoWindow, () async {
      _timers.remove(p.budget.id);
      messenger.hideCurrentSnackBar();
      await ref.read(financeControllerProvider).deleteBudget(p.budget.id);
      if (mounted) setState(() => _pendingDeleteIds.remove(p.budget.id));
    });

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${p.category.name}" budget'),
        duration: _undoWindow,
        behavior: SnackBarBehavior.floating,
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
      child: Icon(LucideIcons.trash2, color: Theme.of(context).colorScheme.onError),
    );
  }
}

class _EmptyAccountsState extends StatelessWidget {
  const _EmptyAccountsState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: LucideIcons.wallet,
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
