import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class GoalsRepository {
  GoalsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Goal>> watchGoals() {
    return (_db.select(
      _db.goals,
    )..orderBy([(g) => OrderingTerm.desc(g.createdAt)])).watch();
  }

  Stream<List<GoalLink>> watchAllLinks() => _db.select(_db.goalLinks).watch();

  Stream<List<GoalMilestone>> watchAllMilestones() => _db.select(_db.goalMilestones).watch();

  Future<Goal?> getGoal(String id) {
    return (_db.select(_db.goals)..where((g) => g.id.equals(id))).getSingleOrNull();
  }

  Future<String> createGoal({
    required String title,
    String type = 'generic',
    double? targetValue,
    double currentValue = 0,
    DateTime? targetDate,
    bool reminderEnabled = false,
    String reminderMode = 'notification',
    int reminderDaysBefore = 0,
  }) async {
    final row = await _db.into(_db.goals).insertReturning(
      GoalsCompanion.insert(
        title: title,
        type: Value(type),
        targetValue: Value(targetValue),
        currentValue: Value(currentValue),
        targetDate: Value(targetDate),
        reminderEnabled: Value(reminderEnabled),
        reminderMode: Value(reminderMode),
        reminderDaysBefore: Value(reminderDaysBefore),
      ),
    );
    return row.id;
  }

  /// Never touches `currentValue` — progress stays exclusively the +/-
  /// buttons' job via [updateProgress].
  Future<void> updateGoal({
    required String id,
    required String title,
    required String type,
    double? targetValue,
    DateTime? targetDate,
    bool reminderEnabled = false,
    String reminderMode = 'notification',
    int reminderDaysBefore = 0,
  }) {
    return (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(
        title: Value(title),
        type: Value(type),
        targetValue: Value(targetValue),
        targetDate: Value(targetDate),
        reminderEnabled: Value(reminderEnabled),
        reminderMode: Value(reminderMode),
        reminderDaysBefore: Value(reminderDaysBefore),
      ),
    );
  }

  Future<void> updateProgress(String goalId, double currentValue) {
    return (_db.update(_db.goals)..where((g) => g.id.equals(goalId))).write(
      GoalsCompanion(currentValue: Value(currentValue)),
    );
  }

  Future<void> addLink({
    required String goalId,
    required String linkedType,
    required String linkedId,
  }) {
    return _db.into(_db.goalLinks).insert(
      GoalLinksCompanion.insert(goalId: goalId, linkedType: linkedType, linkedId: linkedId),
    );
  }

  Future<void> removeLink(String linkId) {
    return (_db.delete(_db.goalLinks)..where((l) => l.id.equals(linkId))).go();
  }

  Future<void> deleteGoal(String id) async {
    await (_db.delete(_db.goalLinks)..where((l) => l.goalId.equals(id))).go();
    await (_db.delete(_db.goalMilestones)..where((m) => m.goalId.equals(id))).go();
    await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
  }

  Stream<List<GoalMilestone>> watchMilestonesForGoal(String goalId) {
    return (_db.select(_db.goalMilestones)
          ..where((m) => m.goalId.equals(goalId))
          ..orderBy([
            (m) => OrderingTerm.asc(m.sortOrder),
            (m) => OrderingTerm.asc(m.createdAt),
          ]))
        .watch();
  }

  Future<String> createMilestone({required String goalId, required String title}) async {
    final count = await (_db.select(
      _db.goalMilestones,
    )..where((m) => m.goalId.equals(goalId))).get().then((rows) => rows.length);
    final row = await _db.into(_db.goalMilestones).insertReturning(
      GoalMilestonesCompanion.insert(goalId: goalId, title: title, sortOrder: Value(count)),
    );
    return row.id;
  }

  Future<void> setMilestoneCompleted(String id, bool completed) {
    return (_db.update(_db.goalMilestones)..where((m) => m.id.equals(id))).write(
      GoalMilestonesCompanion(completed: Value(completed)),
    );
  }

  Future<void> deleteMilestone(String id) {
    return (_db.delete(_db.goalMilestones)..where((m) => m.id.equals(id))).go();
  }
}
