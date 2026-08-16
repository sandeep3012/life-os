import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../domain/category_spend.dart';

class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({
    super.key,
    required this.breakdown,
    required this.totalMinor,
    required this.currencyCode,
  });

  final List<CategorySpend> breakdown;
  final int totalMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  sections: [
                    for (final entry in breakdown)
                      PieChartSectionData(
                        value: entry.totalMinor.toDouble(),
                        color: Color(
                          int.parse(entry.category.colorHex.replaceFirst('#', '0xFF')),
                        ),
                        radius: 16,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMinor(totalMinor, currencyCode: currencyCode, showDecimals: false),
                    style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'Fraunces'),
                  ),
                  Text(
                    'this month',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in breakdown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(entry.category.colorHex.replaceFirst('#', '0xFF')),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.category.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${(entry.share * 100).round()}%',
                        style: const TextStyle(
                          fontFamily: 'PlexMono',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
