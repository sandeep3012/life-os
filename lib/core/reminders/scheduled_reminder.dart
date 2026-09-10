import 'reminder_mode.dart';

class ScheduledReminder {
  const ScheduledReminder({required this.key, required this.title,
    required this.time, required this.kind, required this.mode});
  final String key;
  final String title;
  final DateTime time;
  final String kind;
  final ReminderMode mode;

  /// Stable across app restarts, unlike a runtime object's identity.
  int get id {
    var hash = 2166136261;
    for (final unit in 'lifeos.schedule:$key'.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}
