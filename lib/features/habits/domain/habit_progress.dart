import '../../../core/database/app_database.dart';

/// Derived view of a [Habit]: current streak and this-week completion, both
/// computed from [HabitLogs] rather than stored, so they can never drift out
/// of sync with the logged history.
class HabitProgress {
  const HabitProgress({
    required this.habit,
    required this.streakDays,
    required this.weekCompletion,
  });

  final Habit habit;
  final int streakDays;

  /// Keyed by [DateTime.weekday] (1 = Monday .. 7 = Sunday).
  final Map<int, bool> weekCompletion;

  /// A habit with an active streak that hasn't been logged yet today —
  /// mirrors the "at risk" flag shown on the prototype's habit check-in cards.
  bool get isAtRisk =>
      streakDays > 0 && !(weekCompletion[DateTime.now().weekday] ?? false);
}
