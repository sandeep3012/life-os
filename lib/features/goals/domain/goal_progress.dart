import '../../../core/database/app_database.dart';

class GoalLinkInfo {
  const GoalLinkInfo({required this.linkId, required this.type, required this.label});

  final String linkId;

  /// habit | account | task
  final String type;
  final String label;
}

/// A goal paired with its resolved links (habit/account/task names looked up
/// across modules — the cross-database join the single-DB design exists for)
/// and its progress ratio.
class GoalWithLinks {
  const GoalWithLinks({required this.goal, required this.links});

  final Goal goal;
  final List<GoalLinkInfo> links;

  double get ratio {
    final target = goal.targetValue;
    if (target == null || target == 0) return 0;
    return (goal.currentValue / target).clamp(0, 1);
  }
}
