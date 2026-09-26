import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/widgets/filter_pill.dart';
import 'package:life_manager/core/widgets/tab_rail.dart';
import 'package:life_manager/features/goals/presentation/screens/goals_screen.dart';
import 'package:life_manager/features/learn/data/learn_repository.dart';
import 'package:life_manager/features/learn/presentation/screens/learn_screen.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  void usePhoneViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(392 * 3, 844 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(Widget screen) => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(theme: AppTheme.light(), home: screen),
  );

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('goals filter', () {
    Future<void> seedGoals() async {
      Future<void> goal(
        String title,
        String type, {
        String status = 'active',
        String? progressMode,
      }) => db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              title: title,
              type: Value(type),
              status: Value(status),
              progressMode: Value(progressMode),
              targetValue: const Value(10),
            ),
          );
      await goal('Save money', 'financial');
      await goal('Journal daily', 'habit', progressMode: 'automatic');
      await goal('Read books', 'generic');
      await goal('Old course', 'generic', status: 'completed');
      await goal('Marathon', 'habit', status: 'abandoned');
    }

    Finder pill(String label) => find.widgetWithText(FilterPill, label);
    Finder status(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AppTabRail),
      matching: find.text(label),
    );

    Set<String> shown(WidgetTester tester) => {
      for (final t in [
        'Save money',
        'Journal daily',
        'Read books',
        'Old course',
        'Marathon',
      ])
        if (find.text(t).evaluate().isNotEmpty) t,
    };

    testWidgets('defaults to active goals and filters by type, tracking '
        'and status', (tester) async {
      usePhoneViewport(tester);
      await seedGoals();
      await tester.pumpWidget(host(const GoalsScreen()));
      await tester.pumpAndSettle();

      // Four status segments plus the chip row must fit a phone.
      expect(tester.takeException(), isNull);

      // Finished and dropped goals are out of the way by default.
      expect(shown(tester), {'Save money', 'Journal daily', 'Read books'});

      await tester.tap(pill('Habit'));
      await tester.pumpAndSettle();
      expect(shown(tester), {'Journal daily'});

      // Type and tracking combine; tapping the type again clears it.
      await tester.tap(pill('Auto-tracked'));
      await tester.pumpAndSettle();
      expect(shown(tester), {'Journal daily'});
      await tester.tap(pill('Habit'));
      await tester.pumpAndSettle();
      expect(shown(tester), {'Journal daily'}, reason: 'auto-tracked only');
      await tester.tap(pill('Auto-tracked'));
      await tester.pumpAndSettle();

      await tester.tap(status('Completed'));
      await tester.pumpAndSettle();
      expect(shown(tester), {'Old course'});

      await tester.tap(status('Abandoned'));
      await tester.pumpAndSettle();
      expect(shown(tester), {'Marathon'});

      await tester.tap(status('All'));
      await tester.pumpAndSettle();
      expect(shown(tester), hasLength(5));

      await disposeCleanly(tester);
    });

    testWidgets('a filter that matches nothing offers a way back', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await seedGoals();
      await tester.pumpWidget(host(const GoalsScreen()));
      await tester.pumpAndSettle();

      // No completed financial goal exists.
      await tester.tap(status('Completed'));
      await tester.tap(pill('Financial'));
      await tester.pumpAndSettle();
      expect(find.text('No goals match these filters.'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(shown(tester), {'Save money', 'Journal daily', 'Read books'});

      await disposeCleanly(tester);
    });

    testWidgets('no filter bar before there is anything to filter', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(host(const GoalsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(FilterPill), findsNothing);
      await disposeCleanly(tester);
    });
  });

  testWidgets('tapping a notebook narrows Learn to its notes', (tester) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
    final repo = LearnRepository(db);
    final physics = await repo.createBook(name: 'Physics');
    final history = await repo.createBook(name: 'History');
    await repo.createNote(bookId: physics, title: 'Newton laws');
    await repo.createNote(bookId: history, title: 'Roman empire');

    await tester.pumpWidget(host(const LearnScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Newton laws'), findsOneWidget);
    expect(find.text('Roman empire'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Show notes in Physics')));
    await tester.pumpAndSettle();
    expect(find.text('Newton laws'), findsOneWidget);
    expect(find.text('Roman empire'), findsNothing);

    // "Show all" replaces the count while filtered, and clears it.
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('Roman empire'), findsOneWidget);

    // Tapping the picked notebook again also clears it.
    await tester.tap(find.bySemanticsLabel(RegExp('^Show notes in History')));
    await tester.pumpAndSettle();
    expect(find.text('Newton laws'), findsNothing);
    await tester.tap(find.bySemanticsLabel(RegExp('^Show notes in History')));
    await tester.pumpAndSettle();
    expect(find.text('Newton laws'), findsOneWidget);
    expect(tester.takeException(), isNull);

    semantics.dispose();
    await disposeCleanly(tester);
  });
}
