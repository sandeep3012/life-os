import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/spend_analyzer_providers.dart';
import '../widgets/budget_bar.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/payment_mode_breakdown.dart';
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
    final paymentModeBreakdown = ref.watch(paymentModeBreakdownProvider);
    final currencyCode = ref.watch(settingsProvider).currencyCode;

    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final delta = previousTotal == 0 ? 0.0 : (total - previousTotal) / previousTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Spend Analyzer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _shiftMonth(ref, -1),
              ),
              Text(
                monthLabel,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _shiftMonth(ref, 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                            formatMinor(total, currencyCode: currencyCode, showDecimals: false),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontFamily: 'Fraunces',
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 250.ms),
                        ],
                      ),
                      if (previousTotal > 0)
                        Row(
                          children: [
                            Icon(
                              delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 14,
                              color: delta >= 0 ? colors.critical : colors.good,
                            )
                                .animate()
                                .scale(
                                  begin: const Offset(1.2, 1.2),
                                  end: const Offset(1.0, 1.0),
                                  duration: 250.ms,
                                  curve: Curves.easeOutBack,
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
                  WeeklyTrendChart(weeklyTotalsMinor: weeklyTrend, color: colors.spend)
                      .animate()
                      .fadeIn(duration: 300.ms),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .slideY(begin: 0.05, end: 0, duration: 250.ms),
          const SizedBox(height: 20),
          Text('By category', style: theme.textTheme.titleSmall)
              .animate(delay: 50.ms)
              .fadeIn(duration: 250.ms),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: breakdown.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No spending logged for this month yet.'),
                    )
                  : CategoryDonutChart(breakdown: breakdown, totalMinor: total, currencyCode: currencyCode),
            ),
          )
              .animate(delay: 30.ms)
              .fadeIn(duration: 250.ms),
          const SizedBox(height: 20),
          Text('Budget vs actual', style: theme.textTheme.titleSmall)
              .animate(delay: 100.ms)
              .fadeIn(duration: 250.ms),
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
                        for (int idx = 0; idx < budgetsProgress.length; idx++)
                          BudgetBar(progress: budgetsProgress[idx], currencyCode: currencyCode)
                              .animate(delay: (100 + idx * 30).ms)
                              .fadeIn(duration: 200.ms)
                              .slideX(begin: 0.03, end: 0, duration: 200.ms),
                      ],
                    ),
            ),
          )
              .animate(delay: 80.ms)
              .fadeIn(duration: 250.ms),
          const SizedBox(height: 20),
          Text('By payment mode', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: paymentModeBreakdown.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No payment mode tagged for this month yet.'),
                    )
                  : PaymentModeBreakdown(breakdown: paymentModeBreakdown, currencyCode: currencyCode),
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
