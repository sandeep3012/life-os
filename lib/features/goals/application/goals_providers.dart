import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../finance/application/finance_providers.dart';
import '../../habits/application/habits_providers.dart';
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
  GoalsController(this._repo);

  final GoalsRepository _repo;

  Future<String> createGoal({
    required String title,
    String type = 'generic',
    double? targetValue,
    double currentValue = 0,
    DateTime? targetDate,
  }) {
    return _repo.createGoal(
      title: title,
      type: type,
      targetValue: targetValue,
      currentValue: currentValue,
      targetDate: targetDate,
    );
  }

  Future<void> updateProgress(String goalId, double currentValue) {
    return _repo.updateProgress(goalId, currentValue);
  }

  Future<void> addLink({required String goalId, required String linkedType, required String linkedId}) {
    return _repo.addLink(goalId: goalId, linkedType: linkedType, linkedId: linkedId);
  }

  Future<void> removeLink(String linkId) => _repo.removeLink(linkId);

  Future<void> deleteGoal(String id) => _repo.deleteGoal(id);
}

final goalsControllerProvider = Provider<GoalsController>((ref) {
  return GoalsController(ref.watch(goalsRepositoryProvider));
});
