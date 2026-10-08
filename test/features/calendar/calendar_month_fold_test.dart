import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:table_calendar/table_calendar.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}
}

/// Month view: the grid folds to one week while the day's list is scrolled,
/// so a busy day gets the screen, and unfolds when the list is pulled down.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {int tasks = 20}) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final today = dateOnly(DateTime.now());
    for (var i = 0; i < tasks; i++) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'Task $i',
              dueDate: Value(today.add(Duration(hours: 8, minutes: i))),
            ),
          );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CalendarFormat format(WidgetTester tester) =>
      (tester.widget(find.byWidgetPredicate((w) => w is TableCalendar))
              as TableCalendar)
          .calendarFormat;

  Finder dayList() => find.byType(ListView).last;

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('scrolling the day up folds the month to its week', (
    tester,
  ) async {
    await pump(tester);
    expect(format(tester), CalendarFormat.month);
    final listTop = tester.getTopLeft(dayList()).dy;

    await tester.drag(dayList(), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(format(tester), CalendarFormat.week);
    // The list moved up into the space the month gave back.
    expect(tester.getTopLeft(dayList()).dy, lessThan(listTop - 100));
    expect(tester.takeException(), isNull);
    await disposeCleanly(tester);
  });

  testWidgets('pulling down from the top unfolds the month again', (
    tester,
  ) async {
    await pump(tester);
    await tester.drag(dayList(), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(format(tester), CalendarFormat.week);

    // Back to the top, then past it.
    await tester.drag(dayList(), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(format(tester), CalendarFormat.month);
    await disposeCleanly(tester);
  });

  testWidgets('tapping the month name toggles, even on an empty day', (
    tester,
  ) async {
    await pump(tester, tasks: 0);
    expect(find.text('Nothing scheduled for this day.'), findsOneWidget);

    final title = find.text(DateFormat.yMMMM().format(DateTime.now()));
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(format(tester), CalendarFormat.week);

    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(format(tester), CalendarFormat.month);
    await disposeCleanly(tester);
  });
}
