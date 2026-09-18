import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';

void main() {
  test('v17 migration preserves pauses and snapshots existing amounts', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY)');
          sqlite.execute('CREATE TABLE events (id TEXT PRIMARY KEY)');
          sqlite.execute('CREATE TABLE goals (id TEXT PRIMARY KEY)');
          sqlite.execute(
            'CREATE TABLE habits (id TEXT PRIMARY KEY, target_amount REAL, target_unit TEXT, pause_started_at INTEGER, paused_until INTEGER)',
          );
          sqlite.execute(
            'CREATE TABLE habit_logs (id TEXT PRIMARY KEY, habit_id TEXT, amount REAL, completed INTEGER)',
          );
          sqlite.execute(
            "INSERT INTO habits VALUES ('h', 20, 'pages', 100, 200)",
          );
          sqlite.execute("INSERT INTO habit_logs VALUES ('l', 'h', 12, 0)");
          sqlite.execute('PRAGMA user_version = 17');
        },
      ),
    );
    addTearDown(db.close);
    final log = await db.customSelect('SELECT * FROM habit_logs').getSingle();
    expect(log.read<double>('amount'), 12);
    expect(log.read<double>('target_amount_snapshot'), 20);
    expect(log.read<String>('target_unit_snapshot'), 'pages');
    final habit = await db.customSelect('SELECT * FROM habits').getSingle();
    expect(habit.read<int>('pause_started_at'), 100);
    expect(habit.read<int>('paused_until'), 200);
    expect(habit.readNullable<String>('pause_history'), isNull);
  });
  test('v14 schedules migrate additively without changing existing rows', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite.execute(
            'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL)',
          );
          sqlite.execute(
            'CREATE TABLE habits (id TEXT PRIMARY KEY, name TEXT NOT NULL)',
          );
          sqlite.execute(
            'CREATE TABLE events (id TEXT PRIMARY KEY, title TEXT NOT NULL)',
          );
          sqlite.execute(
            'CREATE TABLE goals (id TEXT PRIMARY KEY, title TEXT NOT NULL)',
          );
          sqlite.execute(
            'CREATE TABLE habit_logs (id TEXT PRIMARY KEY, habit_id TEXT NOT NULL, date INTEGER NOT NULL, completed INTEGER NOT NULL, notes TEXT)',
          );
          sqlite.execute("INSERT INTO tasks VALUES ('task-1', 'Keep task')");
          sqlite.execute("INSERT INTO habits VALUES ('habit-1', 'Keep habit')");
          sqlite.execute("INSERT INTO events VALUES ('event-1', 'Keep event')");
          sqlite.execute('PRAGMA user_version = 14');
        },
      ),
    );
    addTearDown(db.close);
    final task = await db
        .customSelect(
          'SELECT id, title, schedule, recurrence_id, recurrence_next_generation_date FROM tasks',
        )
        .getSingle();
    expect(task.read<String>('title'), 'Keep task');
    expect(task.readNullable<String>('schedule'), isNull);
    final habit = await db
        .customSelect('SELECT name, description, schedule FROM habits')
        .getSingle();
    expect(habit.read<String>('name'), 'Keep habit');
    expect(habit.readNullable<String>('description'), isNull);
    final event = await db
        .customSelect('SELECT title, description, schedule FROM events')
        .getSingle();
    expect(event.read<String>('title'), 'Keep event');
    expect(event.readNullable<String>('schedule'), isNull);
  });
}
