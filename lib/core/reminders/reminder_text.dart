import 'package:intl/intl.dart';

/// The body line of each kind of reminder notification — what the item is
/// about and *when*, measured from the moment the notification fires, not
/// from when it was scheduled. A bill reminded three days early says "due in
/// 3 days", not "due".
///
/// Pure functions of their inputs, so the wording is testable without a
/// notification plugin.
abstract final class ReminderText {
  /// "Due now", plus the priority when it's high — the only level worth the
  /// extra words on a lock screen.
  static String task({required String priority}) =>
      priority == 'high' ? 'Due now · High priority' : 'Due now';

  /// "Starts at 4:00 PM, in 15 min", or "Starting now" for an on-time
  /// reminder.
  static String event({required DateTime start, required int minutesBefore}) {
    if (minutesBefore <= 0) return 'Starting now';
    return 'Starts at ${_time(start)}, in ${_lead(minutesBefore)}';
  }

  /// "Time to check in", with the day's target when the habit has one.
  static String habit({double? targetAmount, String? targetUnit}) {
    if (targetAmount == null || targetAmount <= 0) return 'Time to check in';
    final amount = targetAmount == targetAmount.roundToDouble()
        ? targetAmount.toInt().toString()
        : targetAmount.toString();
    final unit = (targetUnit ?? '').trim();
    return 'Time to check in · $amount${unit.isEmpty ? '' : ' $unit'} today';
  }

  /// "8:00 AM dose", with the dosage note when there is one.
  static String medication({
    required int hour,
    required int minute,
    String dosageNote = '',
  }) {
    final dose = '${_time(DateTime(2000, 1, 1, hour, minute))} dose';
    final note = dosageNote.trim();
    return note.isEmpty ? dose : '$dose · $note';
  }

  /// "₹1,250 due in 3 days (Fri, 10 Oct)", "… due tomorrow (…)" or
  /// "… due today". [amount] arrives already formatted in the user's
  /// currency.
  static String bill({
    required String amount,
    required DateTime dueDate,
    required DateTime firesAt,
  }) => '$amount due ${_when(dueDate, firesAt)}';

  /// "Deadline in 2 days (Sun, 12 Oct)", "Deadline tomorrow (…)" or
  /// "Deadline today".
  static String goal({required DateTime deadline, required DateTime firesAt}) {
    final when = _when(deadline, firesAt);
    return 'Deadline $when';
  }

  static String _when(DateTime date, DateTime firesAt) {
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(firesAt.year, firesAt.month, firesAt.day)).inDays;
    if (days <= 0) return 'today';
    final on = DateFormat('EEE, d MMM').format(date);
    return days == 1 ? 'tomorrow ($on)' : 'in $days days ($on)';
  }

  static String _lead(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final h = hours == 1 ? '1 hour' : '$hours hours';
    return rest == 0 ? h : '$h $rest min';
  }

  static String _time(DateTime t) => DateFormat.jm().format(t);
}
