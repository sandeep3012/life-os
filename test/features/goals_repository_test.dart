import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/goals/data/goals_repository.dart';

void main() {
  late AppDatabase db;
  late GoalsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = GoalsRepository(db);
  });

  tearDown(() => db.close());

  test('getGoal returns null for a missing id', () async {
    expect(await repo.getGoal('does-not-exist'), isNull);
  });

  test('updateGoal changes title/type/targetDate/targetValue/reminder fields, not currentValue', () async {
    final id = await repo.createGoal(title: 'Save for trip', targetValue: 1000, currentValue: 250);
    final deadline = DateTime(2026, 12, 1);

    await repo.updateGoal(
      id: id,
      title: 'Save for Japan trip',
      type: 'financial',
      targetValue: 2000,
      targetDate: deadline,
      reminderEnabled: true,
      reminderMode: 'alarm',
      reminderDaysBefore: 7,
    );

    final updated = await repo.getGoal(id);
    expect(updated!.title, 'Save for Japan trip');
    expect(updated.type, 'financial');
    expect(updated.targetValue, 2000);
    expect(updated.targetDate, deadline);
    expect(updated.reminderEnabled, isTrue);
    expect(updated.reminderMode, 'alarm');
    expect(updated.reminderDaysBefore, 7);
    // updateGoal must never touch progress.
    expect(updated.currentValue, 250);
  });

  test('createMilestone appends with increasing sortOrder', () async {
    final goalId = await repo.createGoal(title: 'Read 12 books');
    final first = await repo.createMilestone(goalId: goalId, title: 'Book 1');
    final second = await repo.createMilestone(goalId: goalId, title: 'Book 2');

    final milestones = await repo.watchMilestonesForGoal(goalId).first;
    expect(milestones.map((m) => m.id), [first, second]);
    expect(milestones[0].sortOrder, 0);
    expect(milestones[1].sortOrder, 1);
  });

  test('watchMilestonesForGoal scopes to one goal', () async {
    final goalA = await repo.createGoal(title: 'Goal A');
    final goalB = await repo.createGoal(title: 'Goal B');
    await repo.createMilestone(goalId: goalA, title: 'A1');
    await repo.createMilestone(goalId: goalB, title: 'B1');

    final forA = await repo.watchMilestonesForGoal(goalA).first;
    expect(forA, hasLength(1));
    expect(forA.single.title, 'A1');
  });

  test('setMilestoneCompleted toggles completed', () async {
    final goalId = await repo.createGoal(title: 'Learn guitar');
    final milestoneId = await repo.createMilestone(goalId: goalId, title: 'Learn 3 chords');

    await repo.setMilestoneCompleted(milestoneId, true);
    var milestones = await repo.watchMilestonesForGoal(goalId).first;
    expect(milestones.single.completed, isTrue);

    await repo.setMilestoneCompleted(milestoneId, false);
    milestones = await repo.watchMilestonesForGoal(goalId).first;
    expect(milestones.single.completed, isFalse);
  });

  test('deleteMilestone removes it from watchMilestonesForGoal', () async {
    final goalId = await repo.createGoal(title: 'Declutter');
    final milestoneId = await repo.createMilestone(goalId: goalId, title: 'Closet');

    await repo.deleteMilestone(milestoneId);

    final milestones = await repo.watchMilestonesForGoal(goalId).first;
    expect(milestones, isEmpty);
  });

  test('deleteGoal cascades to milestones and links', () async {
    final goalId = await repo.createGoal(title: 'Move house');
    await repo.createMilestone(goalId: goalId, title: 'Find place');
    await repo.addLink(goalId: goalId, linkedType: 'account', linkedId: 'acc-1');

    await repo.deleteGoal(goalId);

    final milestones = await repo.watchMilestonesForGoal(goalId).first;
    expect(milestones, isEmpty);
    final links = await repo.watchAllLinks().first;
    expect(links.where((l) => l.goalId == goalId), isEmpty);
    expect(await repo.getGoal(goalId), isNull);
  });
}
