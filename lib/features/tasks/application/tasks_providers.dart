import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/services/notification_service.dart';
import '../../settings/application/settings_providers.dart';
import '../data/tasks_repository.dart';
import '../domain/task_priority.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(appDatabaseProvider));
});

final allTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchAllTasks();
});

/// Orchestrates a DB write plus the notification side-effect that goes with
/// it (schedule on create, cancel on completion) — the repository itself
/// stays a pure data layer with no knowledge of notifications.
class TasksController {
  TasksController(this._repo, this._notifications, this._remindersEnabled);

  final TasksRepository _repo;
  final NotificationService _notifications;

  /// Read at call time rather than captured, so toggling the setting takes
  /// effect for the next task without rebuilding this controller.
  final bool Function() _remindersEnabled;

  Future<void> addTask({
    required String title,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
    bool reminderEnabled = true,
    ReminderMode reminderMode = ReminderMode.notification,
  }) async {
    final id = await _repo.createTask(
      title: title,
      dueDate: dueDate,
      priority: priority.value,
      reminderEnabled: reminderEnabled,
      reminderMode: reminderMode.storageValue,
    );
    if (dueDate != null && reminderEnabled && _remindersEnabled()) {
      await _notifications.scheduleTaskReminder(
        taskId: id,
        title: title,
        dueDate: dueDate,
        mode: reminderMode,
      );
    }
  }

  Future<void> toggleDone(Task task) async {
    final done = task.status != 'done';
    await _repo.setTaskDone(task.id, done);
    if (done) {
      await _notifications.cancelTaskReminder(task.id);
    }
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
