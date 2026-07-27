import 'package:drift/drift.dart';
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

  test('merges tasks due today, completed habit logs, and manual events into one list', () async {
    final today = dateOnly(DateTime.now());

    // Keep the merged provider (and everything it watches) subscribed from
    // the start, since a fresh `read()` would otherwise race the underlying
    // Drift streams' first (asynchronous) emission.
    container.listen(selectedDayItemsProvider, (_, _) {});
    await Future.delayed(const Duration(milliseconds: 50));

    final task = await db.into(db.tasks).insertReturning(
      TasksCompanion.insert(
        title: 'Call plumber',
        dueDate: Value(today.add(const Duration(hours: 11))),
      ),
    );
    final habit = await db.into(db.habits).insertReturning(HabitsCompanion.insert(name: 'Evening run'));
    await db.into(db.habitLogs).insert(HabitLogsCompanion.insert(habitId: habit.id, date: today));
    await CalendarRepository(db).createEvent(title: 'Dinner', startTime: today.add(const Duration(hours: 19, minutes: 30)));

    await Future.delayed(const Duration(milliseconds: 100));
    container.read(selectedCalendarDayProvider.notifier).select(today);

    final items = container.read(selectedDayItemsProvider);
    expect(items, hasLength(3));
    expect(items.map((i) => i.type), containsAll(CalendarItemType.values));
    expect(items.first.title, isNotEmpty);
    expect(task.title, 'Call plumber');
  });
}
