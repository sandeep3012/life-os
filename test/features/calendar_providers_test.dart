import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/calendar/application/calendar_providers.dart';
import 'package:life_manager/features/calendar/domain/calendar_item.dart';
import 'package:life_manager/features/calendar/data/calendar_repository.dart';
import 'package:life_manager/core/utils/date_utils.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test(
    'merges tasks due today, completed habit logs, manual events, and unpaid bills into one list',
    () async {
      final today = dateOnly(DateTime.now());

      // Keep the merged provider (and everything it watches) subscribed from
      // the start, since a fresh `read()` would otherwise race the underlying
      // Drift streams' first (asynchronous) emission.
      container.listen(selectedDayItemsProvider, (_, _) {});
      await Future.delayed(const Duration(milliseconds: 50));

      final task = await db
          .into(db.tasks)
          .insertReturning(
            TasksCompanion.insert(
              title: 'Call plumber',
              dueDate: Value(today.add(const Duration(hours: 11))),
            ),
          );
      final habit = await db
          .into(db.habits)
          .insertReturning(HabitsCompanion.insert(name: 'Evening run'));
      await db
          .into(db.habitLogs)
          .insert(HabitLogsCompanion.insert(habitId: habit.id, date: today));
      await CalendarRepository(db).createEvent(
        title: 'Dinner',
        startTime: today.add(const Duration(hours: 19, minutes: 30)),
      );
      final account = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(name: 'Checking', type: 'checking'),
          );
      await db
          .into(db.bills)
          .insert(
            BillsCompanion.insert(
              name: 'Electricity',
              accountId: Value(account.id),
              amountMinor: 150000,
              dueDate: today,
            ),
          );

      await Future.delayed(const Duration(milliseconds: 100));
      container.read(selectedCalendarDayProvider.notifier).select(today);

      final items = container.read(selectedDayItemsProvider);
      expect(items, hasLength(4));
      expect(items.map((i) => i.type), containsAll(CalendarItemType.values));
      expect(items.first.title, isNotEmpty);
      expect(task.title, 'Call plumber');
    },
  );

  test('createEvent with frequency none creates exactly one row', () async {
    final repo = CalendarRepository(db);
    final today = dateOnly(DateTime.now());
    await repo.createEvent(title: 'One-off', startTime: today.add(const Duration(hours: 9)));

    final all = await db.select(db.events).get();
    expect(all, hasLength(1));
    expect(all.single.frequency, 'none');
    expect(all.single.recurrenceId, isNull);
  });

  test('createEvent with daily frequency and an end date generates occurrences', () async {
    final repo = CalendarRepository(db);
    final start = dateOnly(DateTime.now()).add(const Duration(hours: 9));
    final head = await repo.createEvent(
      title: 'Standup',
      startTime: start,
      frequency: 'daily',
      recurrenceEndDate: start.add(const Duration(days: 4)),
    );

    final all = await db.select(db.events).get();
    // Head + 4 daily occurrences within the 4-day end date.
    expect(all, hasLength(5));
    expect(all.every((e) => e.recurrenceId == head.id), isTrue);
    expect(
      all.where((e) => e.id != head.id).every((e) => e.frequency == 'none'),
      isTrue,
    );
  });

  test('createEvent with monthly frequency and no end date stops at the horizon', () async {
    final repo = CalendarRepository(db);
    final start = DateTime.now();
    final head = await repo.createEvent(
      title: 'Rent review',
      startTime: start,
      frequency: 'monthly',
    );

    final all = await db.select(db.events).get();
    final occurrences = all.where((e) => e.id != head.id).toList();
    expect(occurrences, isNotEmpty);
    final horizonEnd = DateTime.now().add(const Duration(days: 365));
    for (final e in occurrences) {
      expect(e.startTime.isAfter(horizonEnd), isFalse);
    }
  });

  test('extendRecurringEvents tops up a stale series and is idempotent', () async {
    final repo = CalendarRepository(db);
    final start = DateTime.now();
    final head = await repo.createEvent(title: 'Weekly sync', startTime: start, frequency: 'weekly');

    // Simulate the app not having been opened in a while: roll the
    // generated-up-to marker back so the horizon has a gap to fill.
    await (db.update(db.events)..where((e) => e.id.equals(head.id))).write(
      EventsCompanion(recurrenceNextGenerationDate: Value(start)),
    );
    final beforeExtend = await db.select(db.events).get();

    await repo.extendRecurringEvents();
    final afterFirstExtend = await db.select(db.events).get();
    expect(afterFirstExtend.length, greaterThan(beforeExtend.length));

    await repo.extendRecurringEvents();
    final afterSecondExtend = await db.select(db.events).get();
    expect(afterSecondExtend.length, afterFirstExtend.length);
  });

  test('updateEvent changes title/time/reminder but not recurrence columns', () async {
    final repo = CalendarRepository(db);
    final start = DateTime(2026, 3, 10, 9);
    final head = await repo.createEvent(
      title: 'Gym',
      startTime: start,
      frequency: 'weekly',
      recurrenceEndDate: start.add(const Duration(days: 30)),
    );

    final newStart = start.add(const Duration(hours: 2));
    await repo.updateEvent(
      id: head.id,
      title: 'Gym (updated)',
      startTime: newStart,
      reminderEnabled: true,
      reminderMinutesBefore: 15,
    );

    final updated = await repo.getEvent(head.id);
    expect(updated!.title, 'Gym (updated)');
    expect(updated.startTime, newStart);
    expect(updated.reminderEnabled, isTrue);
    expect(updated.reminderMinutesBefore, 15);
    expect(updated.frequency, 'weekly');
    expect(updated.recurrenceId, head.recurrenceId);
  });

  test('deleteEvent on a head row leaves already-generated occurrences intact', () async {
    final repo = CalendarRepository(db);
    final start = DateTime.now();
    final head = await repo.createEvent(
      title: 'Trash day',
      startTime: start,
      frequency: 'weekly',
      recurrenceEndDate: start.add(const Duration(days: 21)),
    );
    final beforeDelete = await db.select(db.events).get();

    await repo.deleteEvent(head.id);

    final afterDelete = await db.select(db.events).get();
    expect(afterDelete.length, beforeDelete.length - 1);
    expect(afterDelete.any((e) => e.id == head.id), isFalse);
  });

  test('getEvent returns null for a missing id', () async {
    final repo = CalendarRepository(db);
    expect(await repo.getEvent('does-not-exist'), isNull);
  });

  test('getEventsInSeries returns exactly the rows sharing a recurrenceId', () async {
    final repo = CalendarRepository(db);
    final start = DateTime(2026, 3, 10, 9);
    final head = await repo.createEvent(
      title: 'Yoga',
      startTime: start,
      frequency: 'weekly',
      recurrenceEndDate: start.add(const Duration(days: 21)),
    );
    await repo.createEvent(title: 'One-off', startTime: start.add(const Duration(days: 1)));

    final inSeries = await repo.getEventsInSeries(head.recurrenceId!);
    expect(inSeries.every((e) => e.recurrenceId == head.recurrenceId), isTrue);
    expect(inSeries.any((e) => e.id == head.id), isTrue);

    final all = await db.select(db.events).get();
    // Series rows + the one standalone event.
    expect(inSeries.length, all.length - 1);
  });

  test('deleteEventSeries removes every row in the series and leaves others untouched', () async {
    final repo = CalendarRepository(db);
    final start = DateTime(2026, 3, 10, 9);
    final head = await repo.createEvent(
      title: 'Yoga',
      startTime: start,
      frequency: 'weekly',
      recurrenceEndDate: start.add(const Duration(days: 21)),
    );
    final other = await repo.createEvent(
      title: 'One-off',
      startTime: start.add(const Duration(days: 1)),
    );

    await repo.deleteEventSeries(head.recurrenceId!);

    final remaining = await db.select(db.events).get();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, other.id);
  });
}
