import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import 'habits_providers.dart';

/// Week-level consistency for the Habits screen's headline.
///
/// Derived at read time from the same 60-day log window the streak calculation
/// uses, so "this week" and "last week" are both real history rather than a
/// stored counter that could drift.
class HabitConsistency {
  const HabitConsistency({
    required this.completedThisWeek,
    required this.targetThisWeek,
    required this.completedLastWeek,
    required this.targetLastWeek,
    required this.dayCounts,
  });

  final int completedThisWeek;
  final int targetThisWeek;
  final int completedLastWeek;
  final int targetLastWeek;

  /// Completions per weekday, keyed 1 = Monday … 7 = Sunday, for the week strip.
  final Map<int, int> dayCounts;

  double get ratio =>
      targetThisWeek == 0 ? 0 : completedThisWeek / targetThisWeek;

  double get _lastRatio =>
      targetLastWeek == 0 ? 0 : completedLastWeek / targetLastWeek;

  /// Change against last week in percentage points, or null when last week has
  /// no baseline to compare against — the comp shows a delta chip, and an
  /// invented one would be worse than none.
  double? get deltaPoints {
    if (targetLastWeek == 0) return null;
    return (ratio - _lastRatio) * 100;
  }
}

final habitConsistencyProvider = Provider<HabitConsistency>((ref) {
  final habits = ref.watch(habitsListProvider).value ?? const [];
  final logs = ref.watch(habitLogsProvider).value ?? const [];

  final thisWeekStart = startOfWeek(DateTime.now());
  final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
  final nextWeekStart = thisWeekStart.add(const Duration(days: 7));

  final active = habits.map((h) => h.id).toSet();
  final weeklyTarget = habits.fold<int>(0, (sum, h) => sum + h.targetPerWeek);

  var thisWeek = 0;
  var lastWeek = 0;
  final dayCounts = <int, int>{for (var d = 1; d <= 7; d++) d: 0};

  for (final log in logs) {
    if (!log.completed || !active.contains(log.habitId)) continue;
    final day = dateOnly(log.date);
    if (!day.isBefore(thisWeekStart) && day.isBefore(nextWeekStart)) {
      thisWeek++;
      dayCounts[day.weekday] = (dayCounts[day.weekday] ?? 0) + 1;
    } else if (!day.isBefore(lastWeekStart) && day.isBefore(thisWeekStart)) {
      lastWeek++;
    }
  }

  return HabitConsistency(
    completedThisWeek: thisWeek,
    targetThisWeek: weeklyTarget,
    completedLastWeek: lastWeek,
    targetLastWeek: weeklyTarget,
    dayCounts: dayCounts,
  );
});
