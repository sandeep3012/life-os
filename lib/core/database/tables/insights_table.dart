import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Persisted output of the AI Analyser's rule engine (Phase 7). Both the v1
/// rule-based engine and any future LLM-backed engine only need to write
/// rows here — this table is the extensibility seam between them, and the
/// UI (severity stripe + dismiss) never needs to know which produced a row.
class Insights extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  /// overspend | streak_risk | goal_behind | task_momentum | ...
  TextColumn get type => text()();

  /// critical | warning | info | good
  TextColumn get severity => text()();
  TextColumn get title => text()();

  /// finance | habits | tasks | goals — shown as the small tag on the card.
  TextColumn get relatedModule => text().nullable()();
  TextColumn get relatedEntityId => text().nullable()();

  DateTimeColumn get generatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
}
