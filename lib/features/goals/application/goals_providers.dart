import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/services/notification_service.dart';
import '../../finance/application/finance_providers.dart';
import '../../habits/application/habits_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../data/goals_repository.dart';
import '../domain/goal_progress.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(ref.watch(appDatabaseProvider));
});

final goalsListProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalsRepositoryProvider).watchGoals();
});

final allGoalLinksProvider = StreamProvider<List<GoalLink>>((ref) {
  return ref.watch(goalsRepositoryProvider).watchAllLinks();
});

final goalMilestonesProvider = StreamProvider.family<List<GoalMilestone>, String>((ref, goalId) {
  return ref.watch(goalsRepositoryProvider).watchMilestonesForGoal(goalId);
});

/// Resolves each link's `linkedId` against whichever module owns it
/// (habits/accounts/tasks) — the cross-module lookup the single shared
/// database exists to make possible without a network of foreign services.
final goalsWithLinksProvider = Provider<List<GoalWithLinks>>((ref) {
  final goals = ref.watch(goalsListProvider).value ?? const [];
  final links = ref.watch(allGoalLinksProvider).value ?? const [];
  final habitById = {for (final h in ref.watch(habitsListProvider).value ?? const []) h.id: h};
  final accountById = {for (final a in ref.watch(accountsProvider).value ?? const []) a.id: a};
  final taskById = {for (final t in ref.watch(allTasksProvider).value ?? const []) t.id: t};

  String? labelFor(GoalLink link) {
    return switch (link.linkedType) {
      'habit' => habitById[link.linkedId]?.name,
      'account' => accountById[link.linkedId]?.name,
      'task' => taskById[link.linkedId]?.title,
      _ => null,
    };
  }

  return [
    for (final goal in goals)
      GoalWithLinks(
        goal: goal,
        links: [
          for (final link in links.where((l) => l.goalId == goal.id))
            if (labelFor(link) case final label?)
              GoalLinkInfo(linkId: link.id, type: link.linkedType, label: label),
        ],
      ),
  ];
});

class GoalsController {
  GoalsController(this._repo, this._notifications, this._remindersEnabled);

  final GoalsRepository _repo;
  final NotificationService _notifications;
  final bool Function() _remindersEnabled;

  Future<String> createGoal({
    required String title,
    String type = 'generic',
    double? targetValue,
    double currentValue = 0,
    DateTime? targetDate,
    bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderDaysBefore = 0,
  }) async {
    final id = await _repo.createGoal(
      title: title,
      type: type,
      targetValue: targetValue,
      currentValue: currentValue,
      targetDate: targetDate,
      reminderEnabled: reminderEnabled,
      reminderMode: reminderMode.storageValue,
      reminderDaysBefore: reminderDaysBefore,
    );
    await _scheduleGoalReminder(
      goalId: id,
      title: title,
      targetDate: targetDate,
      reminderEnabled: reminderEnabled,
      reminderDaysBefore: reminderDaysBefore,
      mode: reminderMode,
    );
    return id;
  }

  Future<void> updateGoal({
    required String id,
    required String title,
    required String type,
    double? targetValue,
    DateTime? targetDate,
    bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderDaysBefore = 0,
  }) async {
    await _notifications.cancelGoalReminder(id);
    await _repo.updateGoal(
      id: id,
      title: title,
      type: type,
      targetValue: targetValue,
      targetDate: targetDate,
      reminderEnabled: reminderEnabled,
      reminderMode: reminderMode.storageValue,
      reminderDaysBefore: reminderDaysBefore,
    );
    await _scheduleGoalReminder(
      goalId: id,
      title: title,
      targetDate: targetDate,
      reminderEnabled: reminderEnabled,
      reminderDaysBefore: reminderDaysBefore,
      mode: reminderMode,
    );
  }

  Future<void> updateProgress(String goalId, double currentValue) {
    return _repo.updateProgress(goalId, currentValue);
  }

  Future<void> addLink({required String goalId, required String linkedType, required String linkedId}) {
    return _repo.addLink(goalId: goalId, linkedType: linkedType, linkedId: linkedId);
  }

  Future<void> removeLink(String linkId) => _repo.removeLink(linkId);

  Future<void> deleteGoal(String id) async {
    await _notifications.cancelGoalReminder(id);
    await _repo.deleteGoal(id);
  }

  Future<String> createMilestone({required String goalId, required String title}) {
    return _repo.createMilestone(goalId: goalId, title: title);
  }

  Future<void> setMilestoneCompleted(String id, bool completed) {
    return _repo.setMilestoneCompleted(id, completed);
  }

  Future<void> deleteMilestone(String id) => _repo.deleteMilestone(id);

  Future<void> _scheduleGoalReminder({
    required String goalId,
    required String title,
    required DateTime? targetDate,
    required bool reminderEnabled,
    required int reminderDaysBefore,
    required ReminderMode mode,
  }) async {
    if (!reminderEnabled || targetDate == null || !_remindersEnabled()) return;
    final reminderTime = targetDate.subtract(Duration(days: reminderDaysBefore));
    await _notifications.scheduleGoalReminder(
      goalId: goalId,
      title: '$title due',
      reminderTime: reminderTime,
      mode: mode,
    );
  }
}

final goalsControllerProvider = Provider<GoalsController>((ref) {
  return GoalsController(
    ref.watch(goalsRepositoryProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(settingsProvider).taskReminders,
  );
});
