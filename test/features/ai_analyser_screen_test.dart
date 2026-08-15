import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/features/ai_analyser/application/ai_analyser_providers.dart';
import 'package:life_manager/features/ai_analyser/presentation/screens/ai_analyser_screen.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Widget buildApp() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const AiAnalyserScreen()),
    );
  }

  testWidgets('refreshing surfaces an overspend insight, dismissing removes it', (tester) async {
    final financeRepo = FinanceRepository(db, FileStorageService());
    await financeRepo.ensureDefaultCategories();
    final categories = await db.select(db.categories).get();
    final diningCategory = categories.firstWhere((c) => c.name == 'Dining');

    await financeRepo.createAccount(name: 'Checking', type: 'checking', balanceMinor: 500000);
    final accountId = (await db.select(db.accounts).get()).first.id;

    await financeRepo.createBudget(categoryId: diningCategory.id, limitMinor: 10000);
    await financeRepo.createTransaction(
      accountId: accountId,
      categoryId: diningCategory.id,
      merchant: 'Overspent dinner',
      amountMinor: -15000,
      date: DateTime.now(),
    );

    // A habit with a live streak that hasn't been logged today should also
    // surface a "streak at risk" insight.
    final habitsRepo = HabitsRepository(db);
    await habitsRepo.createHabit('Meditate');
    final habit = (await db.select(db.habits).get()).first;
    await habitsRepo.setCompletedForDate(
      habit.id,
      dateOnly(DateTime.now()).subtract(const Duration(days: 1)),
      true,
    );

    await tester.pumpWidget(buildApp());
    await tester.pump();

    // Drive the refresh directly through the container instead of racing
    // the screen's own postFrameCallback-triggered refresh — this avoids
    // guessing how many pumps a real async DB round trip needs, and the
    // indeterminate refresh spinner would make pumpAndSettle hang anyway.
    await container.read(aiAnalyserControllerProvider).refresh();
    await tester.pump();

    expect(find.textContaining('Dining spend is'), findsOneWidget);
    expect(find.textContaining('Meditate streak at risk'), findsOneWidget);

    await tester.tap(find.text('Dismiss').first);
    await tester.pump();

    expect(find.textContaining('Dining spend is'), findsNothing);
    expect(find.textContaining('Meditate streak at risk'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('refreshing surfaces a bill-due-soon insight', (tester) async {
    final financeRepo = FinanceRepository(db, FileStorageService());
    await financeRepo.createBill(
      name: 'Electricity',
      amountMinor: 150000,
      dueDate: DateTime.now().add(const Duration(days: 2)),
    );

    await tester.pumpWidget(buildApp());
    await tester.pump();

    await container.read(aiAnalyserControllerProvider).refresh();
    await tester.pump();

    expect(find.textContaining('Electricity'), findsOneWidget);
    expect(find.textContaining('is due'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('refreshing surfaces a habit category rollup insight', (tester) async {
    // Regression test: habitCategoriesProvider must be explicitly kept
    // alive during refresh() (like every other upstream provider it reads)
    // or every habit resolves to category: null and this insight never
    // fires, even though the underlying habits are genuinely at risk.
    final habitsRepo = HabitsRepository(db);
    final category = await habitsRepo.createHabitCategory(
      name: 'Fitness',
      icon: 'fitness_center',
      colorHex: '#2E9E63',
    );
    for (final name in ['Run', 'Lift', 'Stretch']) {
      final id = await habitsRepo.createHabit(name, categoryId: category.id);
      // Give each a live streak (logged yesterday, not today) so isAtRisk is true.
      await habitsRepo.setCompletedForDate(
        id,
        dateOnly(DateTime.now()).subtract(const Duration(days: 1)),
        true,
      );
    }

    await tester.pumpWidget(buildApp());
    await tester.pump();

    await container.read(aiAnalyserControllerProvider).refresh();
    await tester.pump();

    expect(find.textContaining('"Fitness" habits are at risk today'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
