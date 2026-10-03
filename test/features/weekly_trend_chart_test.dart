import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/application/finance_providers.dart'
    show transactionsProvider;
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/spend_analyzer/application/spend_analyzer_providers.dart';
import 'package:life_manager/features/spend_analyzer/presentation/widgets/weekly_trend_chart.dart';

void main() {
  // The axis used to step by 0.5 and truncate each position to a week number,
  // so every label but the last was drawn twice (W1 W1 W2 W2 ...).
  for (final weeks in [4, 5, 6]) {
    testWidgets('$weeks weeks: each week label is drawn exactly once', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: WeeklyTrendChart(
                weeklyTotalsMinor: [
                  for (var i = 0; i < weeks; i++) 100000 + i * 20000,
                ],
                color: Colors.green,
                currencyCode: 'INR',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 1; i <= weeks; i++) {
        expect(find.text('W$i'), findsOneWidget, reason: 'W$i drawn twice');
      }
      expect(find.text('W${weeks + 1}'), findsNothing);
    });
  }

  testWidgets('each week shows what was spent in it, under its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: WeeklyTrendChart(
              // ₹3,200, ₹0, ₹12,500, ₹47,000, ₹850
              weeklyTotalsMinor: const [320000, 0, 1250000, 4700000, 85000],
              color: Colors.green,
              currencyCode: 'INR',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final amount in ['₹3.2k', '₹0', '₹13k', '₹47k', '₹850']) {
      expect(find.text(amount), findsOneWidget, reason: '$amount missing');
    }
    // Below its week label, not beside it.
    expect(
      tester.getCenter(find.text('₹47k')).dy,
      greaterThan(tester.getCenter(find.text('W4')).dy),
    );
  });

  testWidgets('the horizontal guide lines are dashed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: WeeklyTrendChart(
              weeklyTotalsMinor: const [100000, 200000, 150000, 300000],
              color: Colors.green,
              currencyCode: 'INR',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final line = chart.data.gridData.getDrawingHorizontalLine(1);
    expect(line.dashArray, isNotNull, reason: 'guide lines are solid');
    expect(line.dashArray, isNotEmpty);
  });

  group('weekly points vs the month total', () {
    late AppDatabase db;
    late FinanceRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = FinanceRepository(db, FileStorageService());
    });

    tearDown(() => db.close());

    test('a transfer is not counted as spending in the weekly line', () async {
      final now = DateTime.now();
      await repo.createAccount(name: 'Cash', type: 'Cash');
      final account = (await db.select(db.accounts).get()).single;
      final day = DateTime(now.year, now.month, 1, 12);
      await repo.createTransaction(
        accountId: account.id,
        merchant: 'Shop',
        amountMinor: -10000,
        date: day,
        paymentMode: 'upi',
      );
      await repo.createTransaction(
        accountId: account.id,
        merchant: 'To savings',
        amountMinor: -50000,
        date: day,
        paymentMode: 'transfer',
      );

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      // Hold the stream open: an unlistened StreamProvider is torn down before
      // its first value arrives.
      container.listen(transactionsProvider, (_, _) {});
      await container.read(transactionsProvider.future);

      final total = container.read(monthExpenseTotalMinorProvider);
      final weekly = container.read(weeklyTrendProvider);

      expect(total, 10000);
      expect(
        weekly.fold<int>(0, (a, b) => a + b),
        total,
        reason: 'the weeks add up to more than "Total spent"',
      );
    });
  });
}
