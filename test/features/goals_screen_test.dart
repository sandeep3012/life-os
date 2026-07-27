import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/goals/presentation/screens/goals_screen.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light(), home: const GoalsScreen()),
    );
  }

  testWidgets('creating a goal linked to a habit shows it with a 0% ring, and progress can be bumped', (
    tester,
  ) async {
    await HabitsRepository(db).createHabit('Morning workout');

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('No goals yet — add one to start tracking progress.'), findsOneWidget);

    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Run a 10K');
    await tester.pump();
    await tester.tap(find.text('Habit'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '40');
    await tester.pump();
    await tester.tap(find.text('Morning workout'));
    await tester.pump();
    await tester.tap(find.text('Add goal'));
    await tester.pumpAndSettle();

    expect(find.text('Run a 10K'), findsOneWidget);
    expect(find.text('0 / 40'), findsOneWidget);
    expect(find.text('Morning workout'), findsOneWidget);

    await tester.tap(find.text('Run a 10K'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('1 / 40'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
