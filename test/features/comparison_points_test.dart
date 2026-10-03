import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/spend_analyzer/domain/comparison_points.dart';

void main() {
  var n = 0;
  Transaction tx(DateTime date, int rupees, {String? mode}) => Transaction(
    id: 't${n++}',
    accountId: 'a',
    merchant: 'm',
    amountMinor: rupees * 100,
    date: date,
    paymentMode: mode,
    createdAt: date,
  );

  // Thu 15 Oct 2026. Weeks run Mon-Sun: this one is Mon 12 Oct.
  final now = DateTime(2026, 10, 15, 10);
  final october = DateTime(2026, 10);

  List<ComparisonPoint> compute(
    ComparisonPeriod period,
    List<Transaction> txns, {
    DateTime? month,
  }) => computeComparisonPoints(
    period: period,
    transactions: txns,
    selectedMonth: month ?? october,
    now: now,
  );

  group('monthly', () {
    test('six months ending at the selected one, oldest first', () {
      final points = compute(ComparisonPeriod.monthly, const []);

      expect(points.map((p) => p.start), [
        DateTime(2026, 5),
        DateTime(2026, 6),
        DateTime(2026, 7),
        DateTime(2026, 8),
        DateTime(2026, 9),
        DateTime(2026, 10),
      ]);
    });

    test('spent is expenses, saved is income less spent', () {
      final points = compute(ComparisonPeriod.monthly, [
        tx(DateTime(2026, 9, 3), 50000), // salary
        tx(DateTime(2026, 9, 5), -12000),
        tx(DateTime(2026, 9, 20), -8000),
      ]);

      final sep = points[4];
      expect(sep.spentMinor, 2000000);
      expect(sep.savedMinor, 3000000);
    });

    test('an overspent month is negative savings, not zero', () {
      final points = compute(ComparisonPeriod.monthly, [
        tx(DateTime(2026, 10, 1), 10000),
        tx(DateTime(2026, 10, 2), -25000),
      ]);

      expect(points.last.savedMinor, -1500000);
    });

    test('a transfer is neither spending nor income', () {
      final points = compute(ComparisonPeriod.monthly, [
        tx(DateTime(2026, 10, 2), -9900, mode: 'transfer'),
        tx(DateTime(2026, 10, 2), 9900, mode: 'transfer'),
        tx(DateTime(2026, 10, 3), -100),
      ]);

      expect(points.last.spentMinor, 10000);
      expect(points.last.savedMinor, -10000);
    });

    test(
      'a month with nothing in it is a zero, so bars line up with labels',
      () {
        final points = compute(ComparisonPeriod.monthly, const []);

        expect(
          points.every((p) => p.spentMinor == 0 && p.savedMinor == 0),
          isTrue,
        );
      },
    );

    test('the current month is partial, earlier ones are not', () {
      final points = compute(ComparisonPeriod.monthly, const []);

      expect(points.last.partial, isTrue);
      expect(points.first.partial, isFalse);
    });

    test('follows the selected month, not today', () {
      final points = compute(
        ComparisonPeriod.monthly,
        const [],
        month: DateTime(2026, 3),
      );

      expect(points.last.start, DateTime(2026, 3));
      expect(points.last.partial, isFalse);
    });
  });

  group('yearly', () {
    test('drops years before the first recorded one', () {
      final points = compute(ComparisonPeriod.yearly, [
        tx(DateTime(2025, 6, 1), -100),
      ]);

      expect(points.map((p) => p.start.year), [2025, 2026]);
    });

    test('at most three years, ending at the selected one', () {
      final points = compute(ComparisonPeriod.yearly, [
        tx(DateTime(2019, 1, 1), -100),
      ]);

      expect(points.map((p) => p.start.year), [2024, 2025, 2026]);
    });

    test('with no history there is just the selected year', () {
      final points = compute(ComparisonPeriod.yearly, const []);

      expect(points.map((p) => p.start.year), [2026]);
    });

    test('totals the whole calendar year, and only this year is partial', () {
      final points = compute(ComparisonPeriod.yearly, [
        tx(DateTime(2025, 1, 5), -1000),
        tx(DateTime(2025, 12, 28), -2000),
        tx(DateTime(2025, 4, 1), 9000),
        tx(DateTime(2026, 2, 1), -500),
      ]);

      expect(points[0].spentMinor, 300000);
      expect(points[0].savedMinor, 600000);
      expect(points[0].partial, isFalse);
      expect(points[1].spentMinor, 50000);
      expect(points[1].partial, isTrue);
    });
  });

  group('weekly', () {
    test('the last four Mon-Sun weeks, ending with this one', () {
      final points = compute(ComparisonPeriod.weekly, const []);

      expect(points.map((p) => p.start), [
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 12),
      ]);
    });

    test('spending only — income is lumpy, so no savings per week', () {
      final points = compute(ComparisonPeriod.weekly, [
        tx(DateTime(2026, 10, 1), 90000), // salary
        tx(DateTime(2026, 10, 13), -400),
      ]);

      expect(points.every((p) => p.savedMinor == null), isTrue);
      expect(points.last.spentMinor, 40000);
    });

    test('a week spans month ends', () {
      final points = compute(ComparisonPeriod.weekly, [
        tx(DateTime(2026, 9, 30), -100),
        tx(DateTime(2026, 10, 2), -200),
      ]);

      // Mon 28 Sep - Sun 4 Oct holds both.
      expect(points[1].spentMinor, 30000);
    });

    test('only the current week is partial', () {
      final points = compute(ComparisonPeriod.weekly, const []);

      expect(points.map((p) => p.partial), [false, false, false, true]);
    });

    test('browsing a past month ends at that month\'s last week', () {
      final points = compute(
        ComparisonPeriod.weekly,
        const [],
        month: DateTime(2026, 8),
      );

      // 31 Aug 2026 is a Monday.
      expect(points.last.start, DateTime(2026, 8, 31));
      expect(points.last.partial, isFalse);
    });
  });
}
