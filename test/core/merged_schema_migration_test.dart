import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';

void main() {
  for (final designBranch in [true, false]) {
    test(
      'upgrades ${designBranch ? "design v16" : "main v18"} without data loss',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'lifeos_merge_',
        );
        final file = File('${directory.path}/migration.sqlite');
        var db = AppDatabase.forTesting(NativeDatabase(file));
        try {
          await db
              .into(db.tasks)
              .insert(
                TasksCompanion.insert(id: const Value('t'), title: 'Keep task'),
              );
          await db
              .into(db.habits)
              .insert(
                HabitsCompanion.insert(
                  id: const Value('h'),
                  name: 'Keep habit',
                  targetAmount: const Value(8),
                  targetUnit: const Value('glasses'),
                ),
              );
          await db
              .into(db.habitLogs)
              .insert(
                HabitLogsCompanion.insert(
                  habitId: 'h',
                  date: DateTime(2026, 9, 14),
                  amount: const Value(4),
                  targetAmountSnapshot: const Value(10),
                  targetUnitSnapshot: const Value('old unit'),
                ),
              );
          await db
              .into(db.medications)
              .insert(MedicationsCompanion.insert(name: 'Keep medicine'));
          await db
              .into(db.learnBooks)
              .insert(LearnBooksCompanion.insert(name: 'Keep book'));
          if (designBranch) {
            const additions = {
              'tasks': [
                'schedule',
                'recurrence_id',
                'recurrence_next_generation_date',
              ],
              'habits': [
                'schedule',
                'description',
                'target_amount',
                'target_unit',
                'pause_started_at',
                'paused_until',
                'pause_history',
              ],
              'habit_logs': [
                'amount',
                'target_amount_snapshot',
                'target_unit_snapshot',
              ],
              'events': ['schedule', 'description'],
              'goals': ['progress_mode'],
            };
            for (final entry in additions.entries) {
              for (final column in entry.value) {
                await db.customStatement(
                  'ALTER TABLE ${entry.key} DROP COLUMN $column',
                );
              }
            }
          } else {
            for (final table in [
              'medication_logs',
              'medications',
              'exercise_set_logs',
              'workout_logs',
              'exercises',
              'workout_days',
              'learn_notes',
              'learn_books',
            ]) {
              await db.customStatement('DROP TABLE $table');
            }
          }
          await db.customStatement(
            'PRAGMA user_version = ${designBranch ? 16 : 18}',
          );
          await db.close();
          db = AppDatabase.forTesting(NativeDatabase(file));
          expect((await db.select(db.tasks).getSingle()).title, 'Keep task');
          expect((await db.select(db.habits).getSingle()).name, 'Keep habit');
          if (designBranch) {
            expect(
              (await db.select(db.medications).getSingle()).name,
              'Keep medicine',
            );
            expect(
              (await db.select(db.learnBooks).getSingle()).name,
              'Keep book',
            );
            expect(
              (await db.select(db.habits).getSingle()).targetAmount,
              isNull,
            );
          } else {
            expect(await db.select(db.medications).get(), isEmpty);
            expect(await db.select(db.learnBooks).get(), isEmpty);
            final log = await db.select(db.habitLogs).getSingle();
            expect(log.targetAmountSnapshot, 10);
            expect(log.targetUnitSnapshot, 'old unit');
          }
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            19,
          );
        } finally {
          await db.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
