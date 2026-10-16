import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/sync/application/sync_providers.dart';
import 'package:life_manager/features/sync/data/local_sync_store.dart';
import 'package:life_manager/features/sync/domain/sync_crypto.dart';

import 'sync_fakes.dart';

class Device {
  Device(FakeSyncServer server)
    : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncSessionProvider.overrideWithValue(session),
        syncBackendProvider.overrideWithValue(server.client()),
        syncKeyStoreProvider.overrideWithValue(keys),
      ],
    );
  }

  final AppDatabase db;
  final session = FakeSession();
  final keys = MemoryKeyStore();
  late final ProviderContainer container;

  SyncStatus get status => container.read(syncControllerProvider);
  SyncController get controller =>
      container.read(syncControllerProvider.notifier);

  /// Lets the controller's background work (a sync round it started)
  /// finish.
  Future<void> settle(bool Function(SyncStatus) until) async {
    for (var i = 0; i < 200 && !until(status); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(until(status), isTrue, reason: 'stuck at ${status.phase}');
  }

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

bool _synced(SyncStatus s) =>
    s.phase == SyncPhase.ready && !s.syncing && s.lastSyncedAt != null;

void main() {
  late FakeSyncServer server;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() => server = FakeSyncServer());

  test('first phone sets up; a second unlocks with the recovery key', () async {
    final first = Device(server);
    addTearDown(first.dispose);
    expect(first.status.phase, SyncPhase.signedOut);
    await first.controller.start();

    await FinanceRepository(
      first.db,
      FileStorageService(),
    ).createAccount(name: 'Bank', type: 'savings', balanceMinor: 5000);

    first.session.signIn('user-1');
    await first.settle((s) => s.phase == SyncPhase.needsSetup);

    final pending = first.controller.newAccountKeys();
    expect(pending.recoveryKey, startsWith('LOS-'));
    // Nothing is stored before the recovery key has been kept.
    expect(server.wrappedKey, isNull);
    await first.controller.saveRecoveryKey(pending);
    await first.settle(_synced);
    expect(server.wrappedKey, isNotNull);
    expect(first.keys.keys, contains('user-1'));
    expect(server.records, isNotEmpty);

    final second = Device(server);
    addTearDown(second.dispose);
    await second.controller.start();
    second.session.signIn('user-1');
    await second.settle((s) => s.phase == SyncPhase.needsRecoveryKey);

    await expectLater(
      second.controller.unlock(SyncCrypto().newRecoveryKey()),
      throwsA(isA<SyncCryptoException>()),
    );
    expect(second.status.phase, SyncPhase.needsRecoveryKey);

    await second.controller.unlock(pending.recoveryKey.toLowerCase());
    await second.settle(_synced);
    final accounts = await second.db.select(second.db.accounts).get();
    expect(accounts.single.balanceMinor, 5000);

    // Signing out stops sync but keeps the data.
    await second.controller.signOut();
    expect(second.status.phase, SyncPhase.signedOut);
    expect(second.keys.keys, isEmpty);
    expect(await LocalSyncStore(second.db).triggersInstalled(), isFalse);
    expect(await second.db.select(second.db.accounts).get(), hasLength(1));
  });

  test('a replaced recovery key works and the old one stops', () async {
    final phone = Device(server);
    addTearDown(phone.dispose);
    await phone.controller.start();
    phone.session.signIn('user-2');
    await phone.settle((s) => s.phase == SyncPhase.needsSetup);
    final original = phone.controller.newAccountKeys();
    await phone.controller.saveRecoveryKey(original);
    await phone.settle(_synced);

    final replacement = phone.controller.replacementRecoveryKey();
    await phone.controller.saveRecoveryKey(replacement);

    final crypto = SyncCrypto();
    final wrapped = server.wrappedKey!.wrapped;
    await expectLater(
      crypto.unwrapDataKey(wrapped, original.recoveryKey, 'user-2'),
      throwsA(isA<SyncCryptoException>()),
    );
    expect(
      await crypto.unwrapDataKey(wrapped, replacement.recoveryKey, 'user-2'),
      phone.keys.keys['user-2'],
    );
  });

  test('a build without sync keys says so', () {
    final container = ProviderContainer(
      overrides: [
        syncSessionProvider.overrideWithValue(null),
        syncBackendProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(syncControllerProvider).phase,
      SyncPhase.unavailable,
    );
  });
}
