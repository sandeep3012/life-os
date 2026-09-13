import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/ai_analyser/domain/task_momentum.dart';

Task task(String id, DateTime completed, {String status = 'done'}) => Task(
  id: id,
  title: id,
  status: status,
  priority: 'med',
  reminderEnabled: false,
  reminderMode: 'notification',
  createdAt: DateTime(2026),
  completedAt: completed,
);

void main() {
  test(
    'compares equal local week-to-date windows and excludes future or reopened tasks',
    () {
      final now = DateTime(2026, 9, 9, 12);
      final counts = taskMomentumCounts([
        task('current', DateTime(2026, 9, 7)),
        task('previous', DateTime(2026, 8, 31)),
        task('later-last-week', DateTime(2026, 9, 4)),
        task('future', DateTime(2026, 9, 10)),
        task('boundary', DateTime(2026, 9, 2, 12)),
        task('reopened', DateTime(2026, 9, 8), status: 'open'),
      ], now);
      expect(counts, (thisWeek: 1, lastWeek: 1));
    },
  );
  test('Monday midnight has empty windows', () {
    expect(
      taskMomentumCounts([
        task('past', DateTime(2026, 9, 1)),
      ], DateTime(2026, 9, 7)),
      (thisWeek: 0, lastWeek: 0),
    );
  });
}
