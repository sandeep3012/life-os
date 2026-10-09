import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/budget_alert_sound.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/services/sound_effects.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';
import 'package:life_manager/features/tasks/application/tasks_providers.dart';

class _RecordingPlayer implements SoundPlayer {
  final played = <String>[];

  @override
  Future<void> play(String asset) async => played.add(asset);
}

class _QuietNotifications extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> cancelTaskReminder(String taskId) async {}
}

void main() {
  late AppDatabase db;
  late _RecordingPlayer player;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    player = _RecordingPlayer();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        soundPlayerProvider.overrideWithValue(player),
        notificationServiceProvider.overrideWithValue(_QuietNotifications()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  Future<void> soundsSetting(bool enabled) async {
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            id: const Value(0),
            soundEffectsEnabled: Value(enabled),
          ),
        );
    final sub = container.listen(settingsProvider, (_, _) {});
    addTearDown(sub.close);
    await settle();
  }

  test('ticking a task off plays the task sound; unticking does not', () async {
    await soundsSetting(true);
    final id = await db
        .into(db.tasks)
        .insertReturning(TasksCompanion.insert(title: 'Pay rent'));
    final controller = container.read(tasksControllerProvider);

    await controller.toggleDone(id);
    expect(player.played, ['sounds/task_done_wood.mp3']);

    final done = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id.id))).getSingle();
    await controller.toggleDone(done);
    expect(player.played, hasLength(1));
  });

  test('Sounds off plays nothing', () async {
    await soundsSetting(false);
    container.read(soundEffectsProvider).play(SoundEffect.goalReached);
    expect(player.played, isEmpty);
  });

  test('crossing a budget sounds once; one already over stays quiet', () async {
    await soundsSetting(true);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final account = await db
        .into(db.accounts)
        .insertReturning(
          AccountsCompanion.insert(name: 'Wallet', type: 'cash'),
        );
    Future<Category> category(String name) => db
        .into(db.categories)
        .insertReturning(
          CategoriesCompanion.insert(name: name, colorHex: '#000000'),
        );
    final dining = await category('Dining');
    final rent = await category('Rent');
    for (final (cat, limit) in [(dining, 100000), (rent, 50000)]) {
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              categoryId: cat.id,
              limitMinor: limit,
              startDate: month,
              effectiveMonth: Value(month),
            ),
          );
    }
    Future<void> spend(Category cat, int minor) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account.id,
            categoryId: Value(cat.id),
            merchant: cat.name,
            amountMinor: -minor,
            date: now,
          ),
        );
    // Rent is already over before the app looks: that's the baseline.
    await spend(rent, 60000);
    await spend(dining, 40000);

    container.read(budgetAlertSoundProvider).start();
    await settle();
    expect(player.played, isEmpty);

    await spend(dining, 30000); // 70% — still under
    await settle();
    expect(player.played, isEmpty);

    await spend(dining, 40000); // 110% — crosses
    await settle();
    expect(player.played, ['sounds/budget_alert.mp3']);

    await spend(dining, 10000); // already over: no repeat
    await settle();
    expect(player.played, hasLength(1));
  });
}
