import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/habits/presentation/screens/habit_detail_screen.dart';
import 'package:life_manager/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:life_manager/features/search/presentation/screens/search_screen.dart';

Future<void> _disposeCleanly(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/more/search',
      routes: [
        GoRoute(path: '/more/search', builder: (context, state) => const SearchScreen()),
        GoRoute(
          path: '/finance',
          builder: (context, state) => const Scaffold(body: Text('Finance stub')),
        ),
        GoRoute(
          path: '/tasks-habits',
          builder: (context, state) => const Scaffold(body: Text('Tasks stub')),
          routes: [
            GoRoute(
              path: ':habitId',
              builder: (context, state) =>
                  HabitDetailScreen(habitId: state.pathParameters['habitId']!),
            ),
          ],
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const Scaffold(body: Text('Calendar stub')),
        ),
        GoRoute(
          path: '/more/documents',
          builder: (context, state) => const Scaffold(body: Text('Documents stub')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  Future<void> seedData() async {
    await HabitsRepository(db).createHabit('Morning Yoga');
    await db
        .into(db.notes)
        .insert(NotesCompanion.insert(title: 'Trip Ideas', body: const Value('Japan in spring')));

    final finance = FinanceRepository(db, FileStorageService());
    await finance.createAccount(name: 'Checking', type: 'checking', balanceMinor: 100000);
    final accountId = (await db.select(db.accounts).get()).first.id;
    await finance.createTransaction(
      accountId: accountId,
      merchant: 'Starbucks',
      amountMinor: -5000,
      date: DateTime.now(),
    );
  }

  testWidgets('filters results by query across modules', (tester) async {
    await seedData();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'yoga');
    await tester.pumpAndSettle();

    expect(find.text('Morning Yoga'), findsOneWidget);
    expect(find.text('Trip Ideas'), findsNothing);
    expect(find.text('Starbucks'), findsNothing);

    await _disposeCleanly(tester);
  });

  testWidgets('no query shows the placeholder, no match shows "No results"', (tester) async {
    await seedData();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Search tasks, notes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzznomatch');
    await tester.pumpAndSettle();

    expect(find.textContaining('No results for'), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('tapping a note result opens the note editor (Navigator.push)', (tester) async {
    await seedData();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'trip');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trip Ideas'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteEditorScreen), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('tapping a habit result opens the habit detail screen (go_router push)', (
    tester,
  ) async {
    await seedData();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'yoga');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning Yoga'));
    await tester.pumpAndSettle();

    expect(find.byType(HabitDetailScreen), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('tapping a transaction result switches to the Finance branch (context.go)', (
    tester,
  ) async {
    await seedData();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'starbucks');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starbucks'));
    await tester.pumpAndSettle();

    expect(find.text('Finance stub'), findsOneWidget);

    await _disposeCleanly(tester);
  });
}
