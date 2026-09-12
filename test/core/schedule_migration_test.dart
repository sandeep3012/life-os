import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';

void main() {
  test('v14 schedules migrate additively without changing existing rows', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (sqlite) {
      sqlite.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL)');
      sqlite.execute('CREATE TABLE habits (id TEXT PRIMARY KEY, name TEXT NOT NULL)');
      sqlite.execute('CREATE TABLE events (id TEXT PRIMARY KEY, title TEXT NOT NULL)');
      sqlite.execute("INSERT INTO tasks VALUES ('task-1', 'Keep task')");
      sqlite.execute("INSERT INTO habits VALUES ('habit-1', 'Keep habit')");
      sqlite.execute("INSERT INTO events VALUES ('event-1', 'Keep event')");
      sqlite.execute('PRAGMA user_version = 14');
    }));
    addTearDown(db.close);
    final task = await db.customSelect('SELECT id, title, schedule, recurrence_id, recurrence_next_generation_date FROM tasks').getSingle();
    expect(task.read<String>('title'), 'Keep task');
    expect(task.readNullable<String>('schedule'), isNull);
    final habit = await db.customSelect('SELECT name, description, schedule FROM habits').getSingle();
    expect(habit.read<String>('name'), 'Keep habit');
    expect(habit.readNullable<String>('description'), isNull);
    final event = await db.customSelect('SELECT title, description, schedule FROM events').getSingle();
    expect(event.read<String>('title'), 'Keep event');
    expect(event.readNullable<String>('schedule'), isNull);
  });
}
