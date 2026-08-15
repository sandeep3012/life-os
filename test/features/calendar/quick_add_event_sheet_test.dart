import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/calendar/presentation/widgets/quick_add_event_sheet.dart';

Event _event({
  String id = 'evt-1',
  String title = 'Team sync',
  DateTime? startTime,
  DateTime? endTime,
  String frequency = 'none',
  String? recurrenceId,
  bool reminderEnabled = false,
}) {
  final start = startTime ?? DateTime(2026, 3, 10, 9, 0);
  return Event(
    id: id,
    title: title,
    startTime: start,
    endTime: endTime,
    sourceType: 'manual',
    frequency: frequency,
    recurrenceId: recurrenceId,
    reminderEnabled: reminderEnabled,
    reminderMode: 'notification',
    reminderMinutesBefore: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<QuickAddEventResult?> _openSheet(
  WidgetTester tester, {
  required DateTime initialDate,
  Event? initial,
}) async {
  QuickAddEventResult? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showQuickAddEventSheet(
              context,
              initialDate: initialDate,
              initial: initial,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  final today = DateTime(2026, 3, 10);

  testWidgets('create mode starts with an empty title and disabled submit', (tester) async {
    await _openSheet(tester, initialDate: today);

    expect(find.text('New event'), findsOneWidget);
    final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add event'));
    expect(submit.onPressed, isNull);
    // Frequency picker is editable (create mode, not part of a series).
    expect(find.widgetWithText(ChoiceChip, 'Does not repeat'), findsOneWidget);
  });

  testWidgets('edit mode prefills fields from the given event', (tester) async {
    final event = _event(title: 'Standup', startTime: DateTime(2026, 3, 10, 9, 30));
    await _openSheet(tester, initialDate: today, initial: event);

    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('Standup'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsOneWidget);
  });

  testWidgets('frequency picker is read-only text when the event is part of a series', (
    tester,
  ) async {
    final event = _event(frequency: 'weekly', recurrenceId: 'series-1');
    await _openSheet(tester, initialDate: today, initial: event);

    expect(find.textContaining('Repeats: Weekly'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('submit is disabled until a title is entered', (tester) async {
    await _openSheet(tester, initialDate: today);

    var submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add event'));
    expect(submit.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Dentist');
    await tester.pump();

    submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add event'));
    expect(submit.onPressed, isNotNull);
  });

  testWidgets('delete affordance appears in edit mode and invokes onDelete', (tester) async {
    var deleted = false;
    final event = _event();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showQuickAddEventSheet(
              context,
              initialDate: today,
              initial: event,
              onDelete: () => deleted = true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete event'), findsOneWidget);
    await tester.tap(find.text('Delete event'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}
