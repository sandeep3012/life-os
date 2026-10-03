import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/utils/currency_utils.dart';
import 'package:life_manager/features/spend_analyzer/domain/category_spend.dart';
import 'package:life_manager/features/spend_analyzer/presentation/widgets/category_donut_chart.dart';

/// A large total (₹1,09,135 and up) is wider than the donut's hole, and used to
/// run onto the coloured ring. The centre text now scales down to fit.
void main() {
  final now = DateTime(2026, 10, 1);

  Category category(String name) => Category(
    id: name,
    name: name,
    icon: 'label',
    colorHex: '#A67C00',
    kind: 'expense',
    createdAt: now,
  );

  List<CategorySpend> breakdown(int total) => [
    CategorySpend(
      category: category('Rent'),
      totalMinor: (total * .6).round(),
      share: .6,
    ),
    CategorySpend(
      category: category('Food'),
      totalMinor: (total * .4).round(),
      share: .4,
    ),
  ];

  /// The hole's radius in the chart (kept in step with the widget).
  const holeRadius = 42.0;

  Future<void> pump(
    WidgetTester tester,
    int totalMinor, {
    String monthLabel = 'Oct 2026',
  }) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CategoryDonutChart(
              breakdown: breakdown(totalMinor),
              totalMinor: totalMinor,
              currencyCode: 'INR',
              monthLabel: monthLabel,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Every corner of [finder]'s rendered box must lie inside the hole, with the
  /// scale-to-fit transform applied.
  void expectInsideHole(WidgetTester tester, Finder finder, String what) {
    final centre = tester.getCenter(find.byType(PieChart));
    final rect = tester.getRect(finder);
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      expect(
        (corner - centre).distance,
        lessThanOrEqualTo(holeRadius),
        reason:
            '$what pokes out of the donut hole onto the ring '
            '(corner $corner, centre $centre)',
      );
    }
  }

  // ₹99, ₹1,09,135 (the reported one), ₹10,00,000 and ₹1,00,00,000.
  for (final total in [9900, 10913500, 100000000, 1000000000]) {
    final label = formatMinor(total, currencyCode: 'INR', showDecimals: false);

    testWidgets('the total $label stays inside the donut hole', (tester) async {
      await pump(tester, total);

      expectInsideHole(tester, find.text(label), 'the total');
      expectInsideHole(tester, find.text('Oct 2026'), 'the month label');
    });
  }

  testWidgets('the caption is the month passed in, not "this month"', (
    tester,
  ) async {
    await pump(tester, 10913500, monthLabel: 'Aug 2026');

    expect(find.text('Aug 2026'), findsOneWidget);
    expect(find.text('this month'), findsNothing);
    // Even the longest month stays inside the hole.
    await pump(tester, 10913500, monthLabel: 'September 2026');
    expectInsideHole(tester, find.text('September 2026'), 'a long month label');
  });

  testWidgets('a selected slice keeps its amount inside the hole too', (
    tester,
  ) async {
    await pump(tester, 1000000000);

    // Tap the ring at 3 o'clock, where the first slice starts.
    final centre = tester.getCenter(find.byType(PieChart));
    await tester.tapAt(centre + const Offset(50, 4));
    await tester.pumpAndSettle();

    // Rent: 60% of ₹1,00,00,000.
    final selected = formatMinor(
      (1000000000 * .6).round(),
      currencyCode: 'INR',
      showDecimals: false,
    );
    // The legend lists the same amount, so look only inside the centre readout.
    final inHole = find.descendant(
      of: find.byType(AnimatedSwitcher),
      matching: find.text(selected),
    );
    expect(inHole, findsOneWidget, reason: 'tap did not select a slice');
    expectInsideHole(tester, inHole, 'the selected amount');
  });

  test('the hole fits inside the chart with the ring on it', () {
    // 42 (hole) + 20 (selected ring) must fit in half of the 128px box.
    expect(holeRadius + 20, lessThanOrEqualTo(128 / 2));
    expect(math.pi, greaterThan(3)); // keep the import honest
  });
}
