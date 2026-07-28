import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'tables/calendar_tables.dart';
import 'tables/categories_table.dart';
import 'tables/documents_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/folders_table.dart';
import 'tables/goals_tables.dart';
import 'tables/habits_tables.dart';
import 'tables/insights_table.dart';
import 'tables/notes_tables.dart';
import 'tables/settings_table.dart';
import 'tables/tasks_tables.dart';

part 'app_database.g.dart';

/// Single on-device SQLite database backing every module. Cross-module
/// screens (Calendar, AI Analyser) rely on being able to join across these
/// tables directly, which is the main reason this app uses one relational
/// database instead of a per-feature store.
@DriftDatabase(
  tables: [
    Categories,
    Tags,
    EntityTags,
    Accounts,
    Transactions,
    Budgets,
    Habits,
    HabitLogs,
    Tasks,
    Subtasks,
    Goals,
    GoalLinks,
    Events,
    Folders,
    Notes,
    Documents,
    Insights,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // v1 -> v2: every table gained an explicit `PRIMARY KEY` on `id` (it was
    // previously just a plain unique-by-convention text column, which is why
    // `insertOnConflictUpdate` — used by the backup/restore feature — failed
    // with "Table has no primary key"). No app has shipped with v1 data yet,
    // so the simplest correct migration is a full recreate rather than a
    // per-table `CREATE TABLE ... AS SELECT` rebuild.
    onUpgrade: (m, from, to) async {
      for (final table in allTables) {
        await m.deleteTable(table.actualTableName);
      }
      await m.createAll();
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'life_manager');
}
