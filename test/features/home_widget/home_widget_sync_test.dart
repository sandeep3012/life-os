import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/scheduling/repeat_schedule.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/home_widget/application/home_widget_sync.dart';
import 'package:life_manager/features/home_widget/domain/today_widget_snapshot.dart';

class _RecordingBridge implements HomeWidgetBridge {
  final pushes = <Map<String, Object>>[];

  @override
  Future<void> push(Map<String, Object> data) async => pushes.add(data);
}

/// What the Android "Today" widget is told: today's to-dos, habits done and
/// this month's spend — and less of it when the app is meant to be private.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _RecordingBridge bridge;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bridge = _RecordingBridge();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        homeWidgetBridgeProvider.overrideWithValue(bridge),
      ],
    );

    final today = dateOnly(DateTime.now());
    for (final (title, done) in [
      ('Pay rent', false),
      ('Call plumber', false),
      ('Gym', true),
    ]) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: title,
              dueDate: Value(today.add(const Duration(hours: 18))),
              status: Value(done ? 'done' : 'todo'),
            ),
          );
    }
    final habits = HabitsRepository(db);
    final read = await habits.createHabit(
      'Read',
      schedule: RepeatSchedule(start: today, frequency: 'daily'),
    );
    await habits.createHabit(
      'Walk',
      schedule: RepeatSchedule(start: today, frequency: 'daily'),
    );
    await habits.setCompletedForDate(read, today, true);

    final account = await db
        .into(db.accounts)
        .insertReturning(
          AccountsCompanion.insert(name: 'Wallet', type: 'cash'),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account.id,
            merchant: 'Groceries',
            amountMinor: -125000,
            date: today,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> settings({bool visible = true, bool locked = false}) => db
      .into(db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion(
          id: const Value(0),
          balancesVisible: Value(visible),
          appLockEnabled: Value(locked),
        ),
      );

  /// Starts the sync and waits out its debounce once the data has loaded.
  Future<Map<String, Object>> firstPush() async {
    container.read(homeWidgetSyncProvider).start();
    for (var i = 0; i < 40 && bridge.pushes.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    // Let a settled value replace any push made before every stream loaded.
    await Future<void>.delayed(
      HomeWidgetSync.debounce + const Duration(milliseconds: 300),
    );
    expect(bridge.pushes, isNotEmpty);
    return bridge.pushes.last;
  }

  test("shows today's to-dos, habits and this month's spend", () async {
    await settings();
    final data = await firstPush();

    expect(data['today_day'], TodayWidgetSnapshot.dayKey(DateTime.now()));
    expect(data['today_tasks_left'], 2);
    expect(data['today_tasks_total'], 3);
    expect(data['today_task_1'], 'Pay rent');
    expect(data['today_task_2'], 'Call plumber');
    expect(data['today_task_3'], ''); // done tasks aren't listed
    expect(data['today_habits_done'], 1);
    expect(data['today_habits_total'], 2);
    expect(data['today_spend'], '₹1,250');
    expect(data['today_locked'], 0);
  });

  test('hidden balances mask the amount', () async {
    await settings(visible: false);
    final data = await firstPush();
    expect(data['today_spend'], isNot(contains('1,250')));
    expect(data['today_task_1'], 'Pay rent');
  });

  test('app lock leaves only the counts', () async {
    await settings(locked: true);
    final data = await firstPush();
    expect(data['today_locked'], 1);
    expect(data['today_spend'], '');
    expect(data['today_task_1'], '');
    expect(data['today_tasks_left'], 2);
    expect(data['today_habits_done'], 1);
  });

  test('nothing is re-sent when nothing changed', () async {
    await settings();
    await firstPush();
    final count = bridge.pushes.length;
    container.read(homeWidgetSyncProvider).refreshNow();
    expect(bridge.pushes, hasLength(count));
  });
}
