import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../settings/application/settings_providers.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_item.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(appDatabaseProvider));
});

final _tasksWithDueDateProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchTasksWithDueDate();
});

final _habitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchHabits();
});

final _completedHabitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchCompletedHabitLogs();
});

final manualEventsProvider = StreamProvider<List<Event>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchManualEvents();
});

final _unpaidBillsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchUnpaidBills();
});

class SelectedCalendarDay extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) => state = dateOnly(day);
}

final selectedCalendarDayProvider =
    NotifierProvider<SelectedCalendarDay, DateTime>(SelectedCalendarDay.new);

/// Every task-due, habit-completion, and standalone event merged into one
/// list — the single source both the month markers and the day's agenda
/// derive from, so they can never disagree with each other.
final allCalendarItemsProvider = Provider<List<CalendarItem>>((ref) {
  final tasks = ref.watch(_tasksWithDueDateProvider).value ?? const [];
  final habits = ref.watch(_habitsProvider).value ?? const [];
  final habitsById = {for (final h in habits) h.id: h};
  final habitLogs = ref.watch(_completedHabitLogsProvider).value ?? const [];
  final events = ref.watch(manualEventsProvider).value ?? const [];
  final bills = ref.watch(_unpaidBillsProvider).value ?? const [];

  return [
    for (final t in tasks)
      CalendarItem(
        type: CalendarItemType.task,
        title: t.title,
        date: dateOnly(t.dueDate!),
        time: t.dueDate,
        subtitle: 'Task · ${t.priority[0].toUpperCase()}${t.priority.substring(1)} priority',
        sourceId: t.id,
      ),
    for (final log in habitLogs)
      if (habitsById[log.habitId] case final habit?)
        CalendarItem(
          type: CalendarItemType.habit,
          title: habit.name,
          date: dateOnly(log.date),
          subtitle: 'Habit · completed',
          sourceId: habit.id,
        ),
    for (final e in events)
      CalendarItem(
        type: CalendarItemType.event,
        title: e.title,
        date: dateOnly(e.startTime),
        time: e.startTime,
        endTime: e.endTime,
        subtitle: 'Event',
        sourceId: e.id,
        reminderEnabled: e.reminderEnabled,
        recurrenceId: e.recurrenceId,
      ),
    for (final b in bills)
      CalendarItem(
        type: CalendarItemType.bill,
        title: b.name,
        date: dateOnly(b.dueDate),
        subtitle: 'Bill · due',
        sourceId: b.id,
      ),
  ];
});

/// Date -> distinct item types that day, for the month grid's dot markers.
final calendarMarkersByDayProvider = Provider<Map<DateTime, Set<CalendarItemType>>>((ref) {
  final items = ref.watch(allCalendarItemsProvider);
  final map = <DateTime, Set<CalendarItemType>>{};
  for (final item in items) {
    map.putIfAbsent(item.date, () => {}).add(item.type);
  }
  return map;
});

final selectedDayItemsProvider = Provider<List<CalendarItem>>((ref) {
  final selected = ref.watch(selectedCalendarDayProvider);
  final items = ref.watch(allCalendarItemsProvider).where((i) => i.date == selected).toList()
    ..sort((a, b) {
      if (a.time == null && b.time == null) return 0;
      if (a.time == null) return 1;
      if (b.time == null) return -1;
      return a.time!.compareTo(b.time!);
    });
  return items;
});

class CalendarController {
  CalendarController(this._repo, this._notifications, this._remindersEnabled);

  final CalendarRepository _repo;
  final NotificationService _notifications;
  final bool Function() _remindersEnabled;

  Future<void> addEvent({
    required String title,
    required DateTime startTime,
    DateTime? endTime,
    String frequency = 'none',
    DateTime? recurrenceEndDate,
    bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderMinutesBefore = 0,
  }) async {
    final event = await _repo.createEvent(
      title: title,
      startTime: startTime,
      endTime: endTime,
      frequency: frequency,
      recurrenceEndDate: recurrenceEndDate,
      reminderEnabled: reminderEnabled,
      reminderMode: reminderMode,
      reminderMinutesBefore: reminderMinutesBefore,
    );
    await _scheduleEventReminder(event, reminderMode);
  }

  Future<void> updateEvent({
    required String id,
    required String title,
    required DateTime startTime,
    DateTime? endTime,
    bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderMinutesBefore = 0,
  }) async {
    await _notifications.cancelEventReminder(id);
    await _repo.updateEvent(
      id: id,
      title: title,
      startTime: startTime,
      endTime: endTime,
      reminderEnabled: reminderEnabled,
      reminderMode: reminderMode,
      reminderMinutesBefore: reminderMinutesBefore,
    );
    if (reminderEnabled && _remindersEnabled()) {
      await _notifications.scheduleEventReminder(
        eventId: id,
        title: title,
        reminderTime: startTime.subtract(Duration(minutes: reminderMinutesBefore)),
        mode: reminderMode,
      );
    }
  }

  Future<void> deleteEvent(String id) async {
    await _notifications.cancelEventReminder(id);
    await _repo.deleteEvent(id);
  }

  /// Cancels every event's reminder in the series before the bulk delete —
  /// a SQL delete doesn't touch the OS notification queue, so each id needs
  /// its own cancel call.
  Future<void> deleteEventSeries(String recurrenceId) async {
    final events = await _repo.getEventsInSeries(recurrenceId);
    for (final e in events) {
      await _notifications.cancelEventReminder(e.id);
    }
    await _repo.deleteEventSeries(recurrenceId);
  }

  Future<void> extendRecurringEvents() => _repo.extendRecurringEvents();

  Future<void> _scheduleEventReminder(Event event, ReminderMode mode) async {
    if (!event.reminderEnabled || !_remindersEnabled()) return;
    final reminderTime = event.startTime.subtract(Duration(minutes: event.reminderMinutesBefore));
    await _notifications.scheduleEventReminder(
      eventId: event.id,
      title: event.title,
      reminderTime: reminderTime,
      mode: mode,
    );
  }
}

final calendarControllerProvider = Provider<CalendarController>((ref) {
  return CalendarController(
    ref.watch(calendarRepositoryProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(settingsProvider).taskReminders,
  );
});
