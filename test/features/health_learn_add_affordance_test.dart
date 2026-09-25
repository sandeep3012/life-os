import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/widgets/app_top_bar.dart';
import 'package:life_manager/core/widgets/inline_add_button.dart';
import 'package:life_manager/features/health/presentation/screens/health_screen.dart';
import 'package:life_manager/features/learn/presentation/screens/learn_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Health and Learn used to offer a single grey dashed row at the end of the
/// list and nothing else — no FAB, so once it scrolled away there was no way to
/// add anything. The Planner's contract is one accent-tinted affordance at a
/// time: the inline row while it is on screen, the FAB once it is not. These
/// assert both screens now follow it.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// The comp's phone size. The default 800x600 test surface is shorter than
  /// any phone, which changes what does and doesn't fit on screen — the whole
  /// subject of these tests.
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

  final fab = find.byType(FloatingActionButton);

  /// `scrollUntilVisible` is no good here: these lists are non-lazy, so every
  /// child is already in the tree and the finder matches while the row is
  /// still far below the fold. Drive the scroll position instead. The outer
  /// ListView's Scrollable is the first in tree order — Learn's horizontal
  /// notebook strip is nested inside it.
  Future<void> scrollTo(WidgetTester tester, {required bool end}) async {
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    if (!end) {
      state.position.jumpTo(0);
      await tester.pumpAndSettle();
      return;
    }
    // Learn's list is lazy, so maxScrollExtent is only an estimate from the
    // children built so far and grows as we approach the end. One jump lands
    // short; repeat until the extent stops moving.
    var previous = -1.0;
    while (state.position.maxScrollExtent != previous) {
      previous = state.position.maxScrollExtent;
      state.position.jumpTo(previous);
      await tester.pumpAndSettle();
    }
  }

  /// Enough rows that the inline row at the end sits below the fold.
  Future<void> seedMedications(int count) async {
    for (var i = 0; i < count; i++) {
      await db
          .into(db.medications)
          .insert(
            MedicationsCompanion.insert(
              name: 'Medication $i',
              dosageNote: Value('1 capsule · dose $i'),
              stockLeft: const Value(10),
            ),
          );
    }
  }

  testWidgets('health swaps the inline row for a FAB as it scrolls away', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await seedMedications(14);
    await tester.pumpWidget(host(const HealthScreen()));
    await tester.pumpAndSettle();

    // The row is the accent-tinted shared one, not a bare dashed button.
    expect(find.byType(InlineAddButton), findsOneWidget);

    // Off the bottom of a long list, so the FAB is the only way in.
    expect(fab, findsOneWidget);

    // Scrolling to the row hands the affordance back to it.
    await scrollTo(tester, end: true);
    expect(
      fab,
      findsNothing,
      reason: 'the FAB should stand down while the inline row is on screen',
    );

    await disposeCleanly(tester);
  });

  testWidgets('health shows no FAB when the whole list already fits', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await seedMedications(1);
    await tester.pumpWidget(host(const HealthScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(InlineAddButton), findsOneWidget);
    expect(fab, findsNothing);

    await disposeCleanly(tester);
  });

  testWidgets('the gym tab carries its own inline row and FAB', (tester) async {
    usePhoneViewport(tester);
    await seedMedications(1);
    await tester.pumpWidget(host(const HealthScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();

    // The empty gym state offers the session row; with nothing else on the
    // tab it fits, so the FAB stays down.
    expect(find.text('Add a training session'), findsOneWidget);
    expect(find.byType(InlineAddButton), findsOneWidget);
    expect(fab, findsNothing);
    expect(tester.takeException(), isNull);

    await disposeCleanly(tester);
  });

  testWidgets('learn drops the header plus for an inline row and FAB', (
    tester,
  ) async {
    usePhoneViewport(tester);
    for (var i = 0; i < 14; i++) {
      final bookId = await db
          .into(db.learnBooks)
          .insertReturning(LearnBooksCompanion.insert(name: 'Book $i'));
      await db
          .into(db.learnNotes)
          .insert(
            LearnNotesCompanion.insert(
              bookId: bookId.id,
              title: 'Note $i',
              excerpt: Value('Excerpt $i'),
            ),
          );
    }
    await tester.pumpWidget(host(const LearnScreen()));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppTopBar),
        matching: find.byIcon(LucideIcons.plus),
      ),
      findsNothing,
      reason: 'the header plus should be gone, leaving only the FAB',
    );

    // Learn spreads each note as its own list child, so unlike Health — which
    // nests a whole tab inside one Column child — the trailing row is lazily
    // unmounted this far up the list. That is exactly the case the FAB exists
    // to cover, so it must be showing.
    expect(find.byType(InlineAddButton), findsNothing);
    expect(fab, findsOneWidget);

    await scrollTo(tester, end: true);
    expect(find.byType(InlineAddButton), findsOneWidget);
    expect(
      fab,
      findsNothing,
      reason: 'the FAB should stand down once the row is back on screen',
    );

    await disposeCleanly(tester);
  });
}
