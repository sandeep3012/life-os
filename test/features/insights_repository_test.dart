import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/ai_analyser/data/insights_repository.dart';
import 'package:life_manager/features/ai_analyser/domain/insight_draft.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = InsightsRepository(db);
  });

  tearDown(() => db.close());

  test('reconcile inserts a new draft', () async {
    await repo.reconcile(const [
      InsightDraft(type: 'goal_milestone_gap', severity: 'warning', title: '9 days', relatedEntityId: 'g1'),
    ]);

    final rows = await db.select(db.insights).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, '9 days');
  });

  test(
    'reconcile updates title/severity in place when the dedupe key persists but content changes',
    () async {
      await repo.reconcile(const [
        InsightDraft(type: 'goal_milestone_gap', severity: 'warning', title: '9 days', relatedEntityId: 'g1'),
      ]);

      // Same dedupe key (type:g1), but the deadline moved closer — title and
      // severity both change. This is the exact scenario that was previously
      // stuck showing stale text after editing a goal's deadline.
      await repo.reconcile(const [
        InsightDraft(type: 'goal_milestone_gap', severity: 'critical', title: '3 days', relatedEntityId: 'g1'),
      ]);

      final rows = await db.select(db.insights).get();
      expect(rows, hasLength(1));
      expect(rows.single.title, '3 days');
      expect(rows.single.severity, 'critical');
    },
  );

  test('reconcile does not resurrect or update a dismissed insight', () async {
    await repo.reconcile(const [
      InsightDraft(type: 'goal_milestone_gap', severity: 'warning', title: '9 days', relatedEntityId: 'g1'),
    ]);
    final inserted = (await db.select(db.insights).get()).single;
    await repo.dismiss(inserted.id);

    await repo.reconcile(const [
      InsightDraft(type: 'goal_milestone_gap', severity: 'critical', title: '3 days', relatedEntityId: 'g1'),
    ]);

    final rows = await db.select(db.insights).get();
    expect(rows, hasLength(1));
    expect(rows.single.dismissed, isTrue);
    expect(rows.single.title, '9 days'); // untouched while dismissed
  });

  test('reconcile deletes a non-dismissed row whose condition no longer holds', () async {
    await repo.reconcile(const [
      InsightDraft(type: 'overspend', severity: 'warning', title: 'over budget', relatedEntityId: 'b1'),
    ]);

    await repo.reconcile(const []);

    final rows = await db.select(db.insights).get();
    expect(rows, isEmpty);
  });
}
