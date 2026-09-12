import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/motion.dart';
import '../../../../app/router/app_sidebar.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/donut_chart.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../../../core/widgets/tappable.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../spend_analyzer/application/spend_analyzer_providers.dart';
import '../../application/finance_overview_providers.dart';
import '../../application/finance_providers.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../widgets/finance_cards.dart';

/// The Finance screen from the design comp: a `NET SAVED` headline over three stat
/// pills, a segmented Overview/Income/Spending control, the "Where it went" donut,
/// a 6-month spending chart, a horizontal run of account cards, recurring rows,
/// and the transaction list.
///
/// Everything is driven by the app's existing local providers; the month follows
/// [selectedAnalyzerMonthProvider] so this and the Spend Analyser never disagree.
class FinanceOverviewScreen extends ConsumerStatefulWidget {
  const FinanceOverviewScreen({super.key});

  @override
  ConsumerState<FinanceOverviewScreen> createState() =>
      _FinanceOverviewScreenState();
}

enum _FinanceTab { overview, income, spending }

class _FinanceOverviewScreenState extends ConsumerState<FinanceOverviewScreen> {
  _FinanceTab _tab = _FinanceTab.overview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final currency = ref.watch(settingsProvider).currencyCode;
    final month = ref.watch(selectedAnalyzerMonthProvider);

    final income = ref.watch(monthIncomeMinorProvider);
    final outgoing = ref.watch(monthOutgoingMinorProvider);
    final netSaved = ref.watch(monthNetSavedMinorProvider);
    final delta = ref.watch(netSavedDeltaProvider);

    final breakdown = ref.watch(categoryBreakdownProvider);
    final trend = ref.watch(monthlySpendTrendProvider);
    final accounts = ref.watch(activeAccountsProvider);
    final recurring = ref.watch(recurringTransactionsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final txns = ref.watch(monthTransactionsProvider);

    final palette = colors.spendCategoryPalette;
    Color categoryColor(String? categoryId) {
      if (categoryId == null) return colors.catOther;
      final index = categories.indexWhere((c) => c.id == categoryId);
      if (index < 0) return colors.catOther;
      return palette[index % palette.length];
    }

    String money(int minor, {bool decimals = false, bool sign = false}) {
      return formatMinor(
        minor,
        currencyCode: currency,
        showDecimals: decimals,
        showSign: sign,
      );
    }

    final visibleTxns = switch (_tab) {
      _FinanceTab.overview => txns,
      _FinanceTab.income => txns.where((t) => t.amountMinor > 0).toList(),
      _FinanceTab.spending => txns.where((t) => t.amountMinor < 0).toList(),
    };

    return Scaffold(
      drawer: const AppSidebar(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Builder(
                builder: (context) => AppTopBar(
                  centerText: 'Finance',
                  centerIsTitle: true,
                  onMenu: () => Scaffold.of(context).openDrawer(),
                  trailingIcon: LucideIcons.slidersHorizontal,
                  onTrailing: () => context.go(RoutePaths.spendAnalyzer),
                ),
              ),
            ),

            Overline(
              'Net saved · ${DateFormat.MMMM().format(month)}',
              color: colors.text3,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    money(netSaved),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 42,
                      height: 1.0,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                ),
                if (delta != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          delta >= 0
                              ? LucideIcons.arrowUp
                              : LucideIcons.arrowDown,
                          size: 14,
                          color: delta >= 0 ? colors.accentInk : colors.warm,
                        ),
                        Text(
                          '${(delta.abs() * 100).round()}%',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: delta >= 0 ? colors.accentInk : colors.warm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatPill(
                    label: 'Income',
                    value: money(income),
                    icon: LucideIcons.arrowDownLeft,
                    color: colors.finance,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: StatPill(
                    label: 'Outgoing',
                    value: money(outgoing),
                    icon: LucideIcons.arrowUpRight,
                    color: colors.spend,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: StatPill(
                    label: 'Balance',
                    value: money(ref.watch(totalBalanceMinorProvider)),
                    icon: LucideIcons.piggyBank,
                    color: colors.catEntertainment,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            AppTabRail<_FinanceTab>(
              value: _tab,
              labels: const {
                _FinanceTab.overview: 'Overview',
                _FinanceTab.income: 'Income',
                _FinanceTab.spending: 'Spending',
              },
              onChanged: (tab) => setState(() => _tab = tab),
            ),

            if (_tab != _FinanceTab.income) ...[
              const SizedBox(height: 16),
              SpendDonutCard(
                totalLabel: money(outgoing),
                segments: [
                  for (final entry in breakdown)
                    DonutSegment(
                      share: entry.share,
                      color: categoryColor(entry.category.id),
                    ),
                ],
                legend: [
                  for (final entry in breakdown.take(5))
                    DonutLegendEntry(
                      name: entry.category.name,
                      share: entry.share,
                      color: categoryColor(entry.category.id),
                    ),
                ],
              ),

              const SizedBox(height: 14),
              MonthlyBarsCard(
                bars: [
                  for (final point in trend)
                    MonthBar(
                      label: DateFormat.MMM().format(point.month),
                      topLabel: _compact(point.totalMinor, currency),
                      value: point.totalMinor,
                    ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            SectionHeader(
              title: 'Accounts',
              trailing: _LinkAction(
                label: '+ Add account',
                onTap: () => context.go(RoutePaths.finance),
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 11),
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return AccountMiniCard(
                    name: account.name,
                    kind: account.type,
                    balance: money(account.balanceMinor, decimals: true),
                    color: palette[index % palette.length],
                    negative: account.balanceMinor < 0,
                    onTap: () => context.go(RoutePaths.netWorth),
                  );
                },
              ),
            ),

            if (recurring.isNotEmpty) ...[
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Recurring & scheduled',
                trailing: _LinkAction(
                  label: '+ New',
                  onTap: () => context.go(RoutePaths.recurringTransactions),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Added to your ledger automatically on each due date.',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12.5,
                  height: 1.45,
                  color: colors.text3,
                ),
              ),
              const SizedBox(height: 11),
              for (final rule in recurring.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: RecurringRow(
                    name: rule.merchant,
                    subtitle: rule.frequency,
                    amount: money(rule.amountMinor.abs()),
                    nextRun: DateFormat('d MMM').format(rule.nextDueDate),
                    color: categoryColor(rule.categoryId),
                    tag: rule.active ? 'auto' : null,
                    onTap: () => context.go(RoutePaths.recurringTransactions),
                  ),
                ),
            ],

            const SizedBox(height: 22),
            SectionHeader(
              title: 'Transactions',
              trailing: _LinkAction(
                label: 'See all',
                onTap: () => context.go(RoutePaths.reports),
              ),
            ),
            const SizedBox(height: 11),
            if (visibleTxns.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Nothing logged this month yet',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      color: colors.text3,
                    ),
                  ),
                ),
              )
            else
              for (final txn in visibleTxns.take(10))
                TxnRow(
                  name: txn.merchant,
                  subtitle: _txnSubtitle(txn, categories),
                  amount: money(txn.amountMinor, decimals: true, sign: true),
                  color: categoryColor(txn.categoryId),
                  incoming: txn.amountMinor > 0,
                ),
          ],
        ).animate().fadeIn(duration: AppMotion.screenEnter).slideY(
              begin: 0.02,
              end: 0.0,
              duration: AppMotion.screenEnter,
              curve: AppMotion.standard,
            ),
      ),
    );
  }

  static String _txnSubtitle(Transaction txn, List<Category> categories) {
    final matches = categories.where((c) => c.id == txn.categoryId);
    final category = matches.isEmpty ? null : matches.first;
    final date = DateFormat('d MMM').format(txn.date);
    return category == null ? date : '${category.name} · $date';
  }

  /// Comp bar labels are abbreviated (`₹96k`) so six of them fit across a phone.
  static String _compact(int minor, String currencyCode) {
    final symbol = currencySymbolFor(currencyCode);
    final major = minor / 100;
    if (major >= 10000000) return '$symbol${(major / 10000000).toStringAsFixed(1)}cr';
    if (major >= 100000) return '$symbol${(major / 100000).toStringAsFixed(1)}L';
    if (major >= 1000) return '$symbol${(major / 1000).round()}k';
    return '$symbol${major.round()}';
  }
}

/// Comp: the small `accent-ink` text action beside a section heading.
class _LinkAction extends StatelessWidget {
  const _LinkAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: label,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: context.appColors.accentInk,
        ),
      ),
    );
  }
}
