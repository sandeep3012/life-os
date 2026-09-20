import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/features/calendar/application/calendar_view_providers.dart';
import 'package:life_manager/features/calendar/domain/calendar_item.dart';
import 'package:life_manager/features/calendar/presentation/widgets/calendar_agenda_view.dart';
import 'package:life_manager/features/calendar/presentation/widgets/calendar_item_tile.dart';

CalendarItem item(
  CalendarItemType type,
  DateTime day, {
  String? title,
  int? hour,
}) => CalendarItem(
  type: type,
  title: title ?? type.name,
  date: day,
  time: hour == null ? null : DateTime(day.year, day.month, day.day, hour),
  subtitle: type.name,
);

void main() {
  final initialDay = DateTime(2026, 9, 20);

  testWidgets(
    'Today action follows visible agenda content and returns to today',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(392, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var selected = DateTime(now.year, now.month, now.day - 14);
      final items = [
        for (var offset = -30; offset <= 30; offset++)
          item(
            CalendarItemType.event,
            DateTime(now.year, now.month, now.day + offset),
            title: 'Event $offset',
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () {},
                icon: const Icon(LucideIcons.plus),
                label: const Text('New event'),
              ),
              body: CalendarAgendaView(
                items: items,
                selectedDay: selected,
                onDayChanged: (day) => setState(() => selected = day),
                itemBuilder: (context, item) =>
                    CalendarItemTile(item: item, agenda: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('agenda-today-action'));
      expect(action, findsOneWidget);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: action, matching: find.byType(Icon)),
            )
            .icon,
        LucideIcons.arrowDown,
      );
      expect(
        tester.getBottomLeft(action).dy,
        tester.getBottomLeft(find.byType(FloatingActionButton)).dy,
      );
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Habit'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      final calendar = tester.widget<TableCalendar<CalendarItemType>>(
        find.byType(TableCalendar<CalendarItemType>),
      );
      expect(calendar.calendarBuilders.headerTitleBuilder, isNotNull);
      expect(tester.getTopLeft(find.widgetWithText(ChoiceChip, 'All')).dx, 20);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(selected, today);
      expect(action, findsNothing);
      final scroll = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      scroll.controller!.jumpTo(500);
      await tester.pumpAndSettle();
      expect(action, findsOneWidget);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: action, matching: find.byType(Icon)),
            )
            .icon,
        LucideIcons.arrowUp,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('all includes bills, and type chips exclude other types', () {
    final items = [
      for (final type in CalendarItemType.values) item(type, initialDay),
    ];
    expect(
      groupCalendarAgendaItems(items, CalendarAgendaFilter.all)[initialDay],
      hasLength(4),
    );
    for (final filter in CalendarAgendaFilter.values.skip(1)) {
      final filtered = groupCalendarAgendaItems(items, filter)[initialDay]!;
      expect(filtered, hasLength(1));
      expect(filtered.single.type, filter.type);
    }
  });

  test('groups date-only and orders timed items before all-day items', () {
    final groups = groupCalendarAgendaItems([
      item(CalendarItemType.habit, initialDay),
      item(CalendarItemType.event, DateTime(2026, 9, 20, 12), hour: 12),
      item(CalendarItemType.task, initialDay, hour: 9),
    ], CalendarAgendaFilter.all);
    expect(groups.keys, [initialDay]);
    expect(groups[initialDay]!.map((item) => item.type), [
      CalendarItemType.task,
      CalendarItemType.event,
      CalendarItemType.habit,
    ]);
  });

  test('calendar layout starts with existing month and can switch back', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(calendarLayoutProvider), CalendarLayout.month);
    container
        .read(calendarLayoutProvider.notifier)
        .select(CalendarLayout.agenda);
    expect(container.read(calendarLayoutProvider), CalendarLayout.agenda);
    container
        .read(calendarLayoutProvider.notifier)
        .select(CalendarLayout.month);
    expect(container.read(calendarLayoutProvider), CalendarLayout.month);
  });

  Future<void> phoneSize(WidgetTester tester, {double width = 392}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(List<CalendarItem> items, ValueChanged<DateTime> onChanged) {
    var selected = initialDay;
    return MaterialApp(
      theme: AppTheme.light(),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: CalendarAgendaView(
            items: items,
            selectedDay: selected,
            onDayChanged: (day) {
              setState(() => selected = day);
              onChanged(day);
            },
            itemBuilder: (context, item) =>
                CalendarItemTile(item: item, agenda: true),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'date taps select empty days, filters remain usable on small screens',
    (tester) async {
      await phoneSize(tester, width: 320);
      var selected = initialDay;
      await tester.pumpWidget(
        app([
          item(CalendarItemType.event, initialDay, title: 'Meeting'),
          item(CalendarItemType.habit, initialDay, title: 'Reading'),
        ], (day) => selected = day),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Habits'));
      await tester.pumpAndSettle();
      expect(find.text('Meeting'), findsNothing);
      expect(find.text('Reading'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(TableCalendar<CalendarItemType>),
          matching: find.text('19'),
        ),
      );
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 9, 19));
      expect(find.text('No habits for this day.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scrolling synchronizes the selected date across week boundaries',
    (tester) async {
      await phoneSize(tester);
      var selected = initialDay;
      await tester.pumpWidget(
        app([
          for (var day = 1; day <= 30; day++)
            item(
              CalendarItemType.event,
              DateTime(2026, 9, day),
              title: 'Event $day',
            ),
        ], (day) => selected = day),
      );
      await tester.pumpAndSettle();
      final scroll = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      scroll.controller!.jumpTo(450);
      await tester.pumpAndSettle();
      expect(selected.isAfter(initialDay), isTrue);
      final calendar = tester.widget<TableCalendar<CalendarItemType>>(
        find.byType(TableCalendar<CalendarItemType>),
      );
      expect(calendar.selectedDayPredicate!(selected), isTrue);
      expect(calendar.focusedDay, selected);
      scroll.controller!.jumpTo(-350);
      await tester.pumpAndSettle();
      expect(selected.isBefore(initialDay), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'week navigation can jump to a distant date and back without stale keys',
    (tester) async {
      await phoneSize(tester);
      var selected = initialDay;
      await tester.pumpWidget(
        app([
          item(CalendarItemType.event, initialDay, title: 'Today event'),
          item(
            CalendarItemType.event,
            DateTime(2027, 5, 4),
            title: 'Distant event',
          ),
        ], (day) => selected = day),
      );
      await tester.pumpAndSettle();
      var calendar = tester.widget<TableCalendar<CalendarItemType>>(
        find.byType(TableCalendar<CalendarItemType>),
      );
      calendar.onDaySelected!(DateTime(2027, 5, 4), DateTime(2027, 5, 4));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2027, 5, 4));
      expect(find.text('Distant event').hitTestable(), findsOneWidget);
      calendar = tester.widget<TableCalendar<CalendarItemType>>(
        find.byType(TableCalendar<CalendarItemType>),
      );
      calendar.onDaySelected!(initialDay, initialDay);
      await tester.pumpAndSettle();
      expect(selected, initialDay);
      expect(find.text('Today event').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
