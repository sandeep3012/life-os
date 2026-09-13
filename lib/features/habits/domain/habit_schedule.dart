import '../../../core/database/app_database.dart';
import '../../../core/scheduling/repeat_schedule.dart';

extension HabitSchedule on Habit {
  RepeatSchedule get repeatSchedule =>
      RepeatSchedule.decode(schedule) ??
      RepeatSchedule(
        start: createdAt,
        frequency: frequency == 'weekly' ? 'weekly' : 'daily',
      );

  bool scheduledOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final pausedFrom = pauseStartedAt == null
        ? null
        : DateTime(
            pauseStartedAt!.year,
            pauseStartedAt!.month,
            pauseStartedAt!.day,
          );
    final pausedTo = pausedUntil == null
        ? null
        : DateTime(pausedUntil!.year, pausedUntil!.month, pausedUntil!.day);
    if (pausedFrom != null &&
        pausedTo != null &&
        !day.isBefore(pausedFrom) &&
        !day.isAfter(pausedTo)) {
      return false;
    }
    return repeatSchedule.includes(day);
  }

  bool get isPaused {
    final today = DateTime.now();
    return pauseStartedAt != null &&
        pausedUntil != null &&
        !today.isBefore(pauseStartedAt!) &&
        !today.isAfter(pausedUntil!);
  }
}
