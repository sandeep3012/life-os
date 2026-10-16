import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

/// Called as a reminder is switched on (or set to ring as an alarm): if the
/// phone has notifications or "Alarms & reminders" turned off for LifeOS,
/// says so and offers to turn them on — rather than the reminder silently
/// never firing. Does nothing when everything's already allowed.
Future<void> checkReminderPermissions(
  BuildContext context, {
  bool alarm = false,
}) async {
  final notifications = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(notificationServiceProvider);
  final missing = await notifications.missingReminderPermissions();
  if (!missing.notificationsOff && !missing.exactAlarmsOff) return;
  if (!context.mounted) return;

  final what = [
    if (missing.notificationsOff) 'notifications',
    if (missing.exactAlarmsOff) '"Alarms & reminders"',
  ].join(' and ');
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(alarm ? 'Allow alarms' : 'Allow reminders'),
      content: Text(
        'LifeOS has $what turned off on this phone, so this '
        '${alarm ? 'alarm won\'t ring' : 'reminder won\'t arrive'} on time. '
        'Turn ${missing.notificationsOff && missing.exactAlarmsOff ? 'them' : 'it'} on?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  if (allow != true) return;
  await notifications.fixReminderPermissions(
    notificationsOff: missing.notificationsOff,
    exactAlarmsOff: missing.exactAlarmsOff,
    alarm: alarm,
  );
}
