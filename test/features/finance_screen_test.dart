import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/finance/presentation/screens/finance_home_screen.dart';
import 'package:life_manager/features/spend_analyzer/presentation/screens/spend_analyzer_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await FinanceRepository(db).ensureDefaultCategories();
  });

  tearDown(() => db.close());

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/finance',
      routes: [
        GoRoute(
          path: '/finance',
          builder: (context, state) => const FinanceHomeScreen(),
          routes: [
            GoRoute(
              path: 'analyzer',
              builder: (context, state) => const SpendAnalyzerScreen(),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets(
    'adding an account then a transaction updates the balance and shows up in the Spend Analyzer',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Add your first account to start tracking finances.'), findsOneWidget);

      await tester.tap(find.text('New account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Checking');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '1000');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(find.text('Checking'), findsOneWidget);
      expect(find.textContaining('1,000.00'), findsWidgets);

      await tester.tap(find.text('New transaction'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Swiggy');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '250');
      await tester.pump();
      await tester.tap(find.text('Add transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Swiggy'), findsOneWidget);
      // 1000 - 250 = 750, both the account card and header should reflect it.
      expect(find.textContaining('750.00'), findsWidgets);

      await tester.tap(find.byTooltip('Spend Analyzer'));
      await tester.pumpAndSettle();

      expect(find.text('Total spent'), findsOneWidget);
      expect(find.textContaining('₹250'), findsWidgets);

      await _disposeCleanly(tester);
    },
  );
}

Future<void> _disposeCleanly(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}
