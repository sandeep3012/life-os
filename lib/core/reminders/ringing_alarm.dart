import 'dart:convert';

/// An alarm-mode reminder that has gone off: what the ringing screen shows,
/// and what's needed to snooze it — carried in the notification's payload,
/// since Snooze can be pressed while the app isn't running.
class RingingAlarm {
  const RingingAlarm({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.kind,
  });

  final int notificationId;
  final String title;
  final String body;

  /// task | habit | medication | event | bill | goal — picks the channel a
  /// snoozed alarm rings on again.
  final String kind;

  /// The payload's second line. The first is whatever identifies the
  /// reminder for rescheduling (see `NotificationService._payloadFor`).
  static String detailsLine({
    required String title,
    required String body,
    required String kind,
  }) => jsonEncode({'alarm': 1, 'title': title, 'body': body, 'kind': kind});

  /// Null for anything that isn't an alarm.
  static RingingAlarm? fromPayload(int notificationId, String? payload) {
    if (payload == null) return null;
    final newline = payload.indexOf('\n');
    if (newline < 0) return null;
    try {
      final json = jsonDecode(payload.substring(newline + 1));
      if (json is! Map || json['alarm'] != 1) return null;
      return RingingAlarm(
        notificationId: notificationId,
        title: json['title'] as String? ?? 'Reminder',
        body: json['body'] as String? ?? '',
        kind: json['kind'] as String? ?? 'task',
      );
    } on FormatException {
      return null;
    }
  }

  /// The id a snoozed copy of this alarm is scheduled under — distinct from
  /// every reminder's own id, and the same for repeated snoozes, so a second
  /// snooze replaces the first rather than stacking.
  int get snoozeId {
    var hash = 2166136261;
    for (final unit in 'lifeos.snooze:$notificationId'.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  /// A snoozed alarm's payload: first line marks it as not one of the
  /// schedule's own reminders, so the next reconcile pass leaves it be.
  String get snoozePayload =>
      'lifeos.snooze:$notificationId\n'
      '${detailsLine(title: title, body: body, kind: kind)}';
}
