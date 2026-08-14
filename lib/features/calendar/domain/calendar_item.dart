enum CalendarItemType { task, habit, event, bill }

/// A unified item shown on the Calendar screen. Tasks and habit completions
/// are read directly from their own tables (never duplicated into [Events])
/// — only standalone entries actually live in [Events]. This class is the
/// merge point where all three become one list for the agenda/markers.
class CalendarItem {
  const CalendarItem({
    required this.type,
    required this.title,
    required this.date,
    required this.subtitle,
    this.time,
    this.sourceId,
  });

  final CalendarItemType type;
  final String title;

  /// Date-only, used for grouping into a day.
  final DateTime date;
  final DateTime? time;
  final String subtitle;
  final String? sourceId;
}
