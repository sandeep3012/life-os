import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/spend_analyzer/presentation/screens/spend_analyzer_screen.dart';

/// The Spend Analyzer browses months, so its captions can't say "this month":
/// that's wrong for every month but the current one.
void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db, FileStorageService());
  });

  tearDown(() => db.close());

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SpendAnalyzerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the donut is captioned with the selected month and follows the arrows', (
    tester,
  ) async {
    final now = DateTime.now();
    final thisMonth = DateFormat.yMMM().format(now);
    final lastMonth = DateFormat.yMMM().format(DateTime(now.year, now.month - 1));

    await repo.createAccount(name: 'Cash', type: 'Cash');
    final account = (await db.select(db.accounts).get()).single;
    await repo.createTransaction(
      accountId: account.id,
      merchant: 'Shop',
      amountMinor: -10000,
      date: DateTime(now.year, now.month, 1, 12),
    );
    await pump(tester);

    // This month has spending: the donut is captioned with the month, and the
    // old generic caption is gone.
    expect(find.text(thisMonth), findsOneWidget);
    expect(find.text('this month'), findsNothing);

    // Step back a month: nothing was logged then, and the message names it.
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('No spending logged for $lastMonth yet.'), findsOneWidget);
    expect(
      find.text('No payment mode tagged for $lastMonth yet.'),
      findsOneWidget,
    );
    expect(find.textContaining('this month yet'), findsNothing);

    // And forward again: back to the donut.
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text(thisMonth), findsOneWidget);
    await disposeCleanly(tester);
  });
}
