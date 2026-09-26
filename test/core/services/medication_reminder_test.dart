import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/reminders/scheduled_reminder.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/services/schedule_coordinator.dart';
import 'package:life_manager/core/utils/date_utils.dart';

/// Captures what the coordinator decided to schedule, without touching the
/// platform plugin.
class _CapturingNotifications extends NotificationService {
  final List<ScheduledReminder> captured = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> replaceScheduledReminders(
    List<ScheduledReminder> reminders, {
    required Set<int> legacyIds,
  }) async {
    captured
      ..clear()
      ..addAll(reminders);
  }
}

/// A medication's "Remind me" switch used to be inert — it stored a flag and
/// nothing ever read it, so no dose reminder could arrive. These cover the
/// scheduling that now backs it.
void main() {
  late AppDatabase db;
  late _CapturingNotifications notifications;
  late ScheduleCoordinator coordinator;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _CapturingNotifications();
    coordinator = ScheduleCoordinator(db, notifications);
    // `_refresh` bails without a settings row.
    await db
        .into(db.appSettings)
        .insert(const AppSettingsCompanion(id: Value(0)));
  });

  tearDown(() {
    coordinator.dispose();
    return db.close();
  });

  /// Drives one refresh past the coordinator's 300ms debounce.
  Future<void> refresh() async {
    coordinator.requestRefresh();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<String> addMedication({
    String name = 'Thyroid',
    bool reminderEnabled = true,
    String reminderMode = 'notification',
    String timesCsv = '06:30,22:30',
    String frequency = 'daily',
    String daysCsv = '1,2,3,4,5,6,7',
    bool active = true,
  }) async {
    final row = await db
        .into(db.medications)
        .insertReturning(
          MedicationsCompanion.insert(
            name: name,
            reminderEnabled: Value(reminderEnabled),
            reminderMode: Value(reminderMode),
            timesCsv: Value(timesCsv),
            frequency: Value(frequency),
            daysCsv: Value(daysCsv),
            active: Value(active),
          ),
        );
    return row.id;
  }

  List<ScheduledReminder> doses() =>
      notifications.captured.where((r) => r.kind == 'medication').toList();

  test('a daily medication is scheduled at each of its dose times', () async {
    await addMedication();
    await refresh();

    expect(doses(), isNotEmpty);
    // Both dose times appear, not just the first.
    final minutes = doses()
        .map((r) => '${r.time.hour}:${r.time.minute}')
        .toSet();
    expect(minutes, containsAll(<String>['6:30', '22:30']));
    expect(doses().every((r) => r.title == 'Thyroid'), isTrue);
    // Never in the past — a reminder for a time already gone is noise.
    expect(doses().every((r) => r.time.isAfter(DateTime.now())), isTrue);
  });

  test('the alarm mode reaches the scheduler', () async {
    await addMedication(reminderMode: 'alarm');
    await refresh();

    expect(doses(), isNotEmpty);
    expect(doses().every((r) => r.mode == ReminderMode.alarm), isTrue);
  });

  test(
    'nothing is scheduled when the switch is off or it is discontinued',
    () async {
      await addMedication(name: 'Off', reminderEnabled: false);
      await addMedication(name: 'Discontinued', active: false);
      await refresh();

      expect(doses(), isEmpty);
    },
  );

  test('a weekly medication is only scheduled on its own days', () async {
    // Monday and Thursday only.
    await addMedication(frequency: 'weekly', daysCsv: '1,4', timesCsv: '09:00');
    await refresh();

    expect(doses(), isNotEmpty);
    expect(
      doses().every(
        (r) =>
            r.time.weekday == DateTime.monday ||
            r.time.weekday == DateTime.thursday,
      ),
      isTrue,
      reason: 'a weekly dose should not be scheduled on other weekdays',
    );
  });

  test("today's remaining doses stop once the dose is logged", () async {
    // A time late enough that it is still ahead of "now" during the test.
    final id = await addMedication(timesCsv: '23:59');
    await refresh();
    final before = doses().where(
      (r) => dateOnly(r.time) == dateOnly(DateTime.now()),
    );
    expect(
      before,
      isNotEmpty,
      reason: 'today should be scheduled to begin with',
    );

    await db
        .into(db.medicationLogs)
        .insert(
          MedicationLogsCompanion.insert(
            medicationId: id,
            date: dateOnly(DateTime.now()),
            taken: const Value(true),
          ),
        );
    await refresh();

    final after = doses().where(
      (r) => dateOnly(r.time) == dateOnly(DateTime.now()),
    );
    expect(after, isEmpty, reason: 'a logged dose should silence that day');
    // Future days are untouched.
    expect(doses(), isNotEmpty);
  });

  test('a malformed dose time is skipped, not thrown on', () async {
    await addMedication(name: 'Broken', timesCsv: 'not-a-time,25:00,10:15');
    await refresh();

    expect(doses(), isNotEmpty);
    expect(
      doses().every((r) => r.time.hour == 10 && r.time.minute == 15),
      isTrue,
    );
  });
}
