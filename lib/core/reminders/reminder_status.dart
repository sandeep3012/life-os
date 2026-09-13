class QueuedReminder {
  const QueuedReminder(this.title, this.time);
  final String title;
  final DateTime time;

  static QueuedReminder? fromPayload(String? payload, String? title) {
    if (payload == null) return null;
    final match = RegExp(
      r'^lifeos\.schedule:.+:(\d{4}-\d{2}-\d{2}T[^ ]+):(notification|alarm)$',
    ).firstMatch(payload);
    if (match == null) return null;
    final time = DateTime.tryParse(match.group(1)!);
    return time == null ? null : QueuedReminder(title ?? 'Reminder', time);
  }
}

class ReminderStatus {
  const ReminderStatus({
    required this.enabled,
    required this.exactAlarms,
    required this.pendingCount,
    required this.scheduled,
  });
  final bool? enabled;
  final bool? exactAlarms;
  final int pendingCount;
  final List<QueuedReminder> scheduled;
}
