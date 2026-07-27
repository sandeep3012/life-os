/// Truncates a [DateTime] to just its date (midnight local time) — used
/// wherever a table stores "one row per day" (e.g. [HabitLogs]) so lookups
/// aren't thrown off by a stray time-of-day component.
DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Monday of the week containing [dt] (date-only).
DateTime startOfWeek(DateTime dt) {
  final d = dateOnly(dt);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
