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

/// Advances [date] by one occurrence of a recurrence [frequency]
/// (`daily`/`weekly`/`monthly`/`yearly`), used by recurring transactions and
/// any future recurring-schedule feature. Month/year arithmetic goes through
/// `DateTime(y, m, d)` rather than adding a fixed `Duration` so it lands on
/// the same day-of-month next time (e.g. the 31st rolls forward correctly
/// instead of drifting through shorter months) — `DateTime` itself
/// normalizes an out-of-range day (e.g. Feb 31) into the correct next month.
DateTime addRecurrenceInterval(DateTime date, String frequency) {
  switch (frequency) {
    case 'daily':
      return date.add(const Duration(days: 1));
    case 'weekly':
      return date.add(const Duration(days: 7));
    case 'yearly':
      return DateTime(date.year + 1, date.month, date.day, date.hour, date.minute);
    case 'monthly':
    default:
      return DateTime(date.year, date.month + 1, date.day, date.hour, date.minute);
  }
}
