import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/finance_providers.dart';
import '../widgets/net_worth_trend_chart.dart';

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final points = ref.watch(netWorthTrendProvider);
    final latest = points.isEmpty ? null : points.last;
    final currencyCode = ref.watch(settingsProvider).currencyCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Net worth')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Net worth', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              formatMinor(latest?.netWorthMinor ?? 0, currencyCode: currencyCode),
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Assets',
                    valueMinor: latest?.assetsMinor ?? 0,
                    color: colors.good,
                    currencyCode: currencyCode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Liabilities',
                    valueMinor: latest?.liabilitiesMinor ?? 0,
                    color: colors.critical,
                    currencyCode: currencyCode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title plus both legend labels exceed a phone's width — this
                    // overflowed by ~95px at 392pt. Wrap keeps them on one line
                    // when they fit and stacks them when they don't.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text('Last 6 months', style: theme.textTheme.titleSmall),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _LegendDot(color: colors.good, label: 'Assets'),
                            _LegendDot(color: colors.critical, label: 'Liabilities'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    NetWorthTrendChart(
                      points: points,
                      assetColor: colors.good,
                      liabilityColor: colors.critical,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Liability = credit-type accounts with a negative balance. Past points are '
              'reconstructed from your transaction history, not stored separately.',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.valueMinor,
    required this.color,
    required this.currencyCode,
  });

  final String label;
  final int valueMinor;
  final Color color;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              formatMinor(valueMinor, currencyCode: currencyCode),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
