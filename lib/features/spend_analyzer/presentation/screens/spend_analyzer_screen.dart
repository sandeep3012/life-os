import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../application/spend_analyzer_providers.dart';
import '../widgets/budget_bar.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/weekly_trend_chart.dart';

class SpendAnalyzerScreen extends ConsumerWidget {
  const SpendAnalyzerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final month = ref.watch(selectedAnalyzerMonthProvider);
    final total = ref.watch(monthExpenseTotalMinorProvider);
    final previousTotal = ref.watch(previousMonthExpenseTotalMinorProvider);
    final breakdown = ref.watch(categoryBreakdownProvider);
    final weeklyTrend = ref.watch(weeklyTrendProvider);
    final budgetsProgress = ref.watch(monthBudgetsWithProgressProvider);

    final delta = previousTotal == 0 ? 0.0 : (total - previousTotal) / previousTotal;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => _shiftMonth(ref, -1),
        ),
        title: Text(DateFormat.yMMMM().format(month)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _shiftMonth(ref, 1),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
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
                            formatMinor(total, showDecimals: false),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontFamily: 'Fraunces',
                            ),
                          ),
                        ],
                      ),
                      if (previousTotal > 0)
                        Row(
                          children: [
                            Icon(
                              delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 14,
                              color: delta >= 0 ? colors.critical : colors.good,
                            ),
                            Text(
                              '${(delta.abs() * 100).toStringAsFixed(1)}% vs last month',
                              style: TextStyle(
                                fontFamily: 'PlexMono',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: delta >= 0 ? colors.critical : colors.good,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WeeklyTrendChart(weeklyTotalsMinor: weeklyTrend, color: colors.spend),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('By category', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: breakdown.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No spending logged for this month yet.'),
                    )
                  : CategoryDonutChart(breakdown: breakdown, totalMinor: total),
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
                          BudgetBar(progress: progress),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _shiftMonth(WidgetRef ref, int delta) {
    ref.read(selectedAnalyzerMonthProvider.notifier).shiftBy(delta);
  }
}
