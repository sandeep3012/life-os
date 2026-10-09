import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/alarm_tone.dart';
import 'package:life_manager/core/reminders/alarm_tone_sync.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/reminders/scheduled_reminder.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/goals/data/goals_repository.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';

class _RecordingNotifications extends NotificationService {
  final events = <String>[];

  @override
  Future<void> init() async {}

  @override
  void useAlarmTone(AlarmTone tone) {
    super.useAlarmTone(tone);
    events.add('tone:${tone.name}');
  }

  @override
  Future<void> replaceScheduledReminders(
    List<ScheduledReminder> reminders, {
    required Set<int> legacyIds,
  }) async => events.add('queue');

  @override
  Future<void> scheduleBillReminder({
    required String billId,
    required String title,
    String body = 'Bill due',
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async => events.add('bill:$title:${alarmTone.name}');

  @override
  Future<void> scheduleGoalReminder({
    required String goalId,
    required String title,
    String body = 'Goal deadline',
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async => events.add('goal:$title:${alarmTone.name}');

  @override
  Future<void> deleteUnusedAlarmChannels() async => events.add('tidy');
}

/// Changing the alarm tone moves every queued alarm onto the new tone before
/// the old tone's channels go.
void main() {
  late AppDatabase db;
  late _RecordingNotifications notifications;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _RecordingNotifications();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    await db
        .into(db.appSettings)
        .insert(
          const AppSettingsCompanion(
            id: Value(0),
            taskReminders: Value(true),
            alarmTone: Value('gentle'),
          ),
        );
    final soon = DateTime.now().add(const Duration(days: 5));
    await db
        .into(db.bills)
        .insert(
          BillsCompanion.insert(
            name: 'Rent',
            amountMinor: 1500000,
            dueDate: soon,
            reminderMode: const Value('alarm'),
          ),
        );
    await db
        .into(db.bills)
        .insert(
          BillsCompanion.insert(
            name: 'Phone',
            amountMinor: 49900,
            dueDate: soon,
          ),
        );
    await GoalsRepository(db).createGoal(
      title: 'Trip fund',
      targetDate: soon,
      reminderEnabled: true,
      reminderMode: 'alarm',
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('starting uses the saved tone', () async {
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          const AppSettingsCompanion(id: Value(0), alarmTone: Value('marimba')),
        );
    // Let the settings stream deliver the row before starting.
    final sub = container.listen(settingsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    container.read(alarmToneSyncProvider).start();
    expect(notifications.alarmTone, AlarmTone.marimba);
    sub.close();
  });

  test('a new tone re-schedules alarms, then tidies old channels', () async {
    await container.read(alarmToneSyncProvider).apply(AlarmTone.tapTapBell);

    expect(notifications.events.first, 'tone:tapTapBell');
    // Only alarm-mode bills and goals move; the notification-mode bill
    // doesn't depend on the tone.
    expect(
      notifications.events,
      containsAll([
        'queue',
        'bill:Rent:tapTapBell',
        'goal:Trip fund:tapTapBell',
      ]),
    );
    expect(
      notifications.events.any((e) => e.startsWith('bill:Phone')),
      isFalse,
    );
    expect(notifications.events.last, 'tidy');
  });

  test('choosing a tone in settings applies it', () async {
    final sub = container.listen(settingsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    container.read(alarmToneSyncProvider).start();
    notifications.events.clear();

    await container
        .read(settingsControllerProvider)
        .setAlarmTone(AlarmTone.marimba);
    for (var i = 0; i < 40 && !notifications.events.contains('tidy'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    expect(notifications.events.first, 'tone:marimba');
    expect(notifications.events.last, 'tidy');
    sub.close();
  });
}
