import '../../../core/database/app_database.dart';

/// The morning note "AI insight alerts" sends.
///
/// Insights are worked out only while the app is open — nothing runs in the
/// background — so an alert the moment one appears would always land while
/// the user is already looking at it on Home. Instead the app keeps one
/// notification scheduled for the next [hour]:00, covering what it found in
/// the day before that note: each insight is announced once, in a quiet
/// moment, and never again the following morning.
class InsightDigest {
  const InsightDigest({
    required this.at,
    required this.title,
    required this.body,
  });

  static const hour = 9;

  final DateTime at;
  final String title;
  final String body;

  /// The note for [active] insights, or null when nothing is new for the
  /// next morning.
  static InsightDigest? compose(List<Insight> active, {required DateTime now}) {
    final today = DateTime(now.year, now.month, now.day, hour);
    final at = now.isBefore(today)
        ? today
        : DateTime(now.year, now.month, now.day + 1, hour);
    // What the previous note (24 hours earlier) couldn't have included.
    final since = DateTime(at.year, at.month, at.day - 1, hour);
    final fresh =
        active
            .where((i) => !i.dismissed && i.generatedAt.isAfter(since))
            .toList()
          ..sort((a, b) => _rank(a.severity).compareTo(_rank(b.severity)));
    if (fresh.isEmpty) return null;
    final lead = fresh.first.title;
    final more = fresh.length - 1;
    return InsightDigest(
      at: at,
      title: fresh.length == 1
          ? 'Worth knowing'
          : '${fresh.length} things worth knowing',
      body: more == 0 ? lead : '$lead — and $more more in LifeOS.',
    );
  }

  /// The most pressing first: an overspend before a nudge.
  static int _rank(String severity) => switch (severity) {
    'critical' => 0,
    'warning' => 1,
    'info' => 2,
    _ => 3,
  };
}
