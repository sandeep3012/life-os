/// How a task/habit reminder should be delivered: a normal notification
/// (silenceable, respects Do Not Disturb) or an alarm-style one (loud,
/// bypasses silent mode, shows full-screen if the device is locked).
enum ReminderMode {
  notification,
  alarm;

  String get label => switch (this) {
    ReminderMode.notification => 'Notification',
    ReminderMode.alarm => 'Alarm',
  };

  String get storageValue => name;

  static ReminderMode fromStorage(String value) {
    return ReminderMode.values.firstWhere(
      (m) => m.storageValue == value,
      orElse: () => ReminderMode.notification,
    );
  }
}
