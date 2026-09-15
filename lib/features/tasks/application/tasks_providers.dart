import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/services/notification_service.dart';
import '../../settings/application/settings_providers.dart';
import '../../../core/scheduling/repeat_schedule.dart';
import '../data/tasks_repository.dart';
import '../domain/task_priority.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(appDatabaseProvider));
});

final allTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchAllTasks();
});

final taskCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(tasksRepositoryProvider).watchCategories(),
);

/// Writes task changes. ScheduleCoordinator refreshes all managed reminders.
class TasksController {
  TasksController(
    this._repo,
    this._notifications,
    bool Function() remindersEnabled,
  );

  final TasksRepository _repo;
  final NotificationService _notifications;

  Future<void> addTask({
    required String title,
    String? description,
    String? categoryId,
    RepeatSchedule? schedule,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
    bool reminderEnabled = true,
    ReminderMode reminderMode = ReminderMode.notification,
  }) async {
    await _repo.createTask(
      title: title,
      description: description,
      categoryId: categoryId,
      schedule: schedule,
      dueDate: dueDate,
      priority: priority.value,
      reminderEnabled: reminderEnabled,
      reminderMode: reminderMode.storageValue,
    );
    // The app's schedule coordinator reconciles reminders after this write.
  }

  Future<void> toggleDone(Task task) async {
    final done = task.status != 'done';
    await _repo.setTaskDone(task.id, done);
    if (done) {
      await _notifications.cancelTaskReminder(task.id);
    }
  }

  Future<void> updateTask({
    required Task task,
    required String title,
    String? description,
    String? categoryId,
    required DateTime? dueDate,
    required TaskPriority priority,
    required bool reminderEnabled,
    required ReminderMode reminderMode,
  }) async {
    await _notifications.cancelTaskReminder(task.id);
    await _repo.updateTask(
      id: task.id,
      title: title,
      description: description,
      categoryId: categoryId,
      dueDate: dueDate,
      priority: priority.value,
      reminderEnabled: reminderEnabled,
      reminderMode: reminderMode.storageValue,
    );
  }

  Future<void> deleteTask(Task task) async {
    await _notifications.cancelTaskReminder(task.id);
    await _repo.deleteTask(task.id);
  }
}

final tasksControllerProvider = Provider<TasksController>((ref) {
  return TasksController(
    ref.watch(tasksRepositoryProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(settingsProvider).taskReminders,
  );
});
