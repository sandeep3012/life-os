/// A candidate insight computed by the rule engine, before it's reconciled
/// against the persisted [Insights] table. Both this v1 rule engine and any
/// future LLM-backed engine only need to produce a list of these — the UI
/// and persistence layer never need to know which produced them.
class InsightDraft {
  const InsightDraft({
    required this.type,
    required this.severity,
    required this.title,
    this.relatedModule,
    this.relatedEntityId,
  });

  /// overspend | streak_risk | task_momentum | goal_behind | goal_on_track
  final String type;

  /// critical | warning | info | good
  final String severity;
  final String title;
  final String? relatedModule;
  final String? relatedEntityId;

  /// Identifies "the same underlying condition" across refreshes so a
  /// dismissed insight isn't silently recreated while it's still true.
  String get dedupeKey => '$type:${relatedEntityId ?? ''}';
}
