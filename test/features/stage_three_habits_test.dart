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

  test('unrelated edits retain target and clearing it is explicit', () async {
    final id = await repo.createHabit(
      'Read',
      targetAmount: 20,
      targetUnit: 'pages',
    );
    await repo.updateHabit(id: id, name: 'Reading');
    expect((await repo.getHabit(id))!.targetAmount, 20);
    await repo.updateHabit(id: id, name: 'Reading', clearTarget: true);
    expect((await repo.getHabit(id))!.targetAmount, isNull);
  });

  test('logged target and unit survive subsequent habit edits', () async {
    final id = await repo.createHabit('Run', targetAmount: 5, targetUnit: 'km');
    await repo.setCompletedForDate(id, DateTime.now(), true, amount: 6);
    await repo.updateHabit(
      id: id,
      name: 'Run',
      targetAmount: 10,
      targetUnit: 'miles',
    );
    var log = (await repo.watchLogsForHabit(id).first).single;
    await repo.setCompletedForDate(id, log.date, log.completed, notes: 'Great');
    log = (await repo.watchLogsForHabit(id).first).single;
    expect(log.targetAmountSnapshot, 5);
    expect(log.targetUnitSnapshot, 'km');
    expect(log.completed, isTrue);
    expect(HabitLog.fromJson(log.toJson()).targetAmountSnapshot, 5);
  });

  test('resume and subsequent pauses preserve earlier excluded days', () async {
    final id = await repo.createHabit(
      'Read',
      schedule: RepeatSchedule(start: DateTime(2026, 1, 1), frequency: 'daily'),
    );
    await repo.pauseHabit(id, DateTime(2026, 1, 10), now: DateTime(2026, 1, 2));
    await repo.resumeHabit(id, now: DateTime(2026, 1, 5));
    var habit = (await repo.getHabit(id))!;
    expect(habit.scheduledOn(DateTime(2026, 1, 2)), isFalse);
    expect(habit.scheduledOn(DateTime(2026, 1, 4)), isFalse);
    expect(habit.scheduledOn(DateTime(2026, 1, 5)), isTrue);
    await repo.pauseHabit(id, DateTime(2026, 1, 9), now: DateTime(2026, 1, 7));
    await repo.pauseHabit(
      id,
      DateTime(2026, 1, 15),
      now: DateTime(2026, 1, 12),
    );
    habit = (await repo.getHabit(id))!;
    expect(habit.scheduledOn(DateTime(2026, 1, 4)), isFalse);
    expect(habit.scheduledOn(DateTime(2026, 1, 9)), isFalse);
    expect(habit.scheduledOn(DateTime(2026, 1, 10)), isTrue);
    expect(habit.scheduledOn(DateTime(2026, 1, 15, 23, 59)), isFalse);
    expect(habit.scheduledOn(DateTime(2026, 1, 16)), isTrue);
    final restored = Habit.fromJson(habit.toJson());
    expect(restored.scheduledOn(DateTime(2026, 1, 4)), isFalse);
  });

  test('pause remains active throughout its inclusive final day', () async {
    final id = await repo.createHabit('Read');
    await repo.pauseHabit(id, DateTime.now());
    final habit = (await repo.getHabit(id))!;
    expect(habit.isPaused, isTrue);
    final now = DateTime.now();
    expect(
      habit.pausedOn(DateTime(now.year, now.month, now.day, 23, 59)),
      isTrue,
    );
  });

  test('pausing preserves progress already recorded today', () async {
    final id = await repo.createHabit('Read', targetAmount: 20);
    await repo.setCompletedForDate(id, DateTime.now(), false, amount: 12);
    await repo.pauseHabit(id, DateTime.now().add(const Duration(days: 3)));
    final habit = (await repo.getHabit(id))!;
    expect(habit.scheduledOn(DateTime.now()), isTrue);
    expect(
      habit.scheduledOn(DateTime.now().add(const Duration(days: 1))),
      isFalse,
    );
    expect((await repo.watchLogsForHabit(id).first).single.amount, 12);
  });

  test(
    'note edits preserve partial and above-target amounts after target edits',
    () async {
      final id = await repo.createHabit('Read', targetAmount: 20);
      for (final amount in [12.0, 30.0]) {
        await repo.setCompletedForDate(
          id,
          DateTime.now(),
          true,
          amount: amount,
        );
        final before = (await repo.watchLogsForHabit(id).first).single;
        await repo.updateHabit(id: id, name: 'Read', targetAmount: 50);
        await repo.setCompletedForDate(
          id,
          DateTime.now(),
          before.completed,
          notes: 'Keep it',
        );
        final after = (await repo.watchLogsForHabit(id).first).single;
        expect(after.amount, before.amount);
        expect(after.completed, before.completed);
        expect(after.notes, 'Keep it');
        await repo.updateHabit(id: id, name: 'Read', targetAmount: 20);
      }
    },
  );

  test(
    'invalid targets and amounts are rejected without creating logs',
    () async {
      for (final value in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          repo.createHabit('Invalid', targetAmount: value),
          throwsArgumentError,
        );
      }
      final id = await repo.createHabit('Read', targetAmount: 20);
      for (final value in [-1.0, double.nan, double.infinity]) {
        await expectLater(
          repo.setCompletedForDate(id, DateTime.now(), true, amount: value),
          throwsArgumentError,
        );
      }
      expect(await repo.watchLogsForHabit(id).first, isEmpty);
    },
  );

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
