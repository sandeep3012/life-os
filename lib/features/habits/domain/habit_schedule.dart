import 'dart:convert';

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
    return !pausedOn(date) && repeatSchedule.includes(date);
  }

  List<List<DateTime>> get pastPauses => pauseHistory == null
      ? []
      : (jsonDecode(pauseHistory!) as List)
            .map(
              (range) => (range as List)
                  .map((date) => DateTime.parse(date as String))
                  .toList(),
            )
            .toList();

  bool pausedOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    for (final range in pastPauses) {
      if (!day.isBefore(range[0]) && !day.isAfter(range[1])) return true;
    }
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
      return true;
    }
    return false;
  }

  bool get isPaused {
    return pausedOn(DateTime.now());
  }

  bool get hasPendingPause {
    final now = DateTime.now();
    return pauseStartedAt != null &&
        pausedUntil != null &&
        !pausedUntil!.isBefore(DateTime(now.year, now.month, now.day));
  }
}
