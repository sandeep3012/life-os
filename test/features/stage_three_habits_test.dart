import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/scheduling/repeat_schedule.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/habits/domain/habit_schedule.dart';

void main() {
  late AppDatabase db;
  late HabitsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HabitsRepository(db);
  });
  tearDown(() => db.close());

  test(
    'pause makes an inclusive range unscheduled and resume restores schedule',
    () async {
      final id = await repo.createHabit(
        'Read',
        schedule: RepeatSchedule(
          start: DateTime(2026, 9, 1),
          frequency: 'daily',
        ),
      );
      await repo.pauseHabit(id, DateTime.now().add(const Duration(days: 3)));
      final paused = (await repo.getHabit(id))!;
      expect(paused.isPaused, isTrue);
      expect(paused.scheduledOn(DateTime.now()), isFalse);
      expect(
        paused.scheduledOn(DateTime.now().add(const Duration(days: 3))),
        isFalse,
      );
      await repo.resumeHabit(id);
      final resumed = (await repo.getHabit(id))!;
      expect(resumed.isPaused, isFalse);
      expect(resumed.scheduledOn(DateTime.now()), isTrue);
      expect(resumed.pauseStartedAt, isNull);
      expect(resumed.pausedUntil, isNull);
    },
  );

  test(
    'quantity logs become complete only when the target is reached',
    () async {
      final id = await repo.createHabit(
        'Read',
        targetAmount: 20,
        targetUnit: 'pages',
      );
      final today = DateTime.now();
      await repo.setCompletedForDate(id, today, true, amount: 12);
      var log = (await repo.watchLogsForHabit(id).first).single;
      expect(log.amount, 12);
      expect(log.completed, isFalse);
      await repo.setCompletedForDate(id, today, true, amount: 20);
      log = (await repo.watchLogsForHabit(id).first).single;
      expect(log.amount, 20);
      expect(log.completed, isTrue);
    },
  );

  test('quantity target and unit persist through update', () async {
    final id = await repo.createHabit('Run');
    await repo.updateHabit(
      id: id,
      name: 'Run',
      targetAmount: 5,
      targetUnit: 'km',
    );
    final habit = await repo.getHabit(id);
    expect(habit!.targetAmount, 5);
    expect(habit.targetUnit, 'km');
  });

  test(
    'quantity habits still support binary completion through the controller path',
    () async {
      final id = await repo.createHabit(
        'Drink',
        targetAmount: 2,
        targetUnit: 'litres',
      );
      await repo.setCompletedForDate(id, DateTime.now(), true);
      final log = (await repo.watchLogsForHabit(id).first).single;
      expect(log.amount, 2);
      expect(log.completed, isTrue);
    },
  );
}
