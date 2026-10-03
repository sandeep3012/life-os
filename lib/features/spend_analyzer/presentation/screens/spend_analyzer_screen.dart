import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/spend_analyzer_providers.dart';
import '../widgets/budget_bar.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/payment_mode_breakdown.dart';
import '../widgets/spend_comparison_card.dart';
import '../widgets/swipe_cards.dart';
import '../widgets/weekly_trend_chart.dart';
import '../../../../app/theme/app_fonts.dart';

/// How tall the swipe cards are. They used to be 304, which made them nearly
/// square; this keeps them the wide rectangles the cards always were.
const double _headerHeight = 236;

class SpendAnalyzerScreen extends ConsumerStatefulWidget {
  const SpendAnalyzerScreen({super.key});

  @override
  ConsumerState<SpendAnalyzerScreen> createState() =>
      _SpendAnalyzerScreenState();
}

class _SpendAnalyzerScreenState extends ConsumerState<SpendAnalyzerScreen> {
  bool _showAmounts = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final month = ref.watch(selectedAnalyzerMonthProvider);
    // "Oct 2026": the screen browses months, so nothing here can say "this
    // month" — it would be wrong for every month but the current one.
    final monthLabel = DateFormat.yMMM().format(month);
    final total = ref.watch(monthExpenseTotalMinorProvider);
    final previousTotal = ref.watch(previousMonthExpenseTotalMinorProvider);
    final breakdown = ref.watch(categoryBreakdownProvider);
    final weeklyTrend = ref.watch(weeklyTrendProvider);
    final budgetsProgress = ref.watch(monthBudgetsWithProgressProvider);
    final paymentModeBreakdown = ref.watch(paymentModeBreakdownProvider);
    final currencyCode = ref.watch(settingsProvider).currencyCode;

    final delta = previousTotal == 0
        ? 0.0
        : (total - previousTotal) / previousTotal;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(DateFormat.yMMMM().format(month)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => _shiftMonth(ref, -1),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(LucideIcons.chevronRight),
            onPressed: () => _shiftMonth(ref, 1),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Two cards to swipe between, side by side rather than stacked: this
          // week-by-week view of the month, and spending against savings over
          // time. The next card peeks in and the dots show where you are.
          SwipeCards(
            height: MediaQuery.textScalerOf(context).scale(_headerHeight),
            children: [
              SizedBox.expand(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total spent',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  formatMinor(
                                    total,
                                    currencyCode: currencyCode,
                                    showDecimals: false,
                                  ),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontFamily: AppFonts.serif),
                                ),
                              ],
                            ),
                            if (previousTotal > 0)
                              Row(
                                children: [
                                  Icon(
                                    delta >= 0
                                        ? LucideIcons.arrowUp
                                        : LucideIcons.arrowDown,
                                    size: 14,
                                    color: delta >= 0
                                        ? colors.critical
                                        : colors.good,
                                  ),
                                  Text(
                                    '${(delta.abs() * 100).toStringAsFixed(1)}% vs last month',
                                    style: TextStyle(
                                      fontFamily: AppFonts.numeric,
                                      fontFeatures: AppFonts.tabular,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: delta >= 0
                                          ? colors.critical
                                          : colors.good,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: WeeklyTrendChart(
                            weeklyTotalsMinor: weeklyTrend,
                            color: colors.spend,
                            currencyCode: currencyCode,
                            height: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SpendComparisonCard(currencyCode: currencyCode),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('By category', style: theme.textTheme.titleSmall),
              if (breakdown.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _showAmounts = !_showAmounts),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showAmounts ? 'Hide amounts' : 'Show amounts',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAmounts ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: breakdown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No spending logged for $monthLabel yet.'),
                    )
                  : CategoryDonutChart(
                      breakdown: breakdown,
                      totalMinor: total,
                      currencyCode: currencyCode,
                      monthLabel: monthLabel,
                      showAmounts: _showAmounts,
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Budget vs actual', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: budgetsProgress.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No budgets set yet.'),
                    )
                  : Column(
                      children: [
                        for (final progress in budgetsProgress)
                          BudgetBar(
                            progress: progress,
                            currencyCode: currencyCode,
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text('By payment mode', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: paymentModeBreakdown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No payment mode tagged for $monthLabel yet.',
                      ),
                    )
                  : PaymentModeBreakdown(
                      breakdown: paymentModeBreakdown,
                      currencyCode: currencyCode,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _shiftMonth(WidgetRef ref, int delta) =>
      ref.read(selectedAnalyzerMonthProvider.notifier).shiftBy(delta);
}
