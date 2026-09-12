import '../../../core/database/app_database.dart';
import '../../../core/scheduling/repeat_schedule.dart';

extension HabitSchedule on Habit {
  RepeatSchedule get repeatSchedule => RepeatSchedule.decode(schedule) ??
      RepeatSchedule(start: createdAt, frequency: frequency == 'weekly' ? 'weekly' : 'daily');

  bool scheduledOn(DateTime date) => repeatSchedule.includes(date);
}
