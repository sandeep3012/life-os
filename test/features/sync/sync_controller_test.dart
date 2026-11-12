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
  /// Pass the same [backup] to two devices for one Apple / Google account.
  Device(FakeSyncServer server, {MemoryKeyBackup? backup})
    : db = AppDatabase.forTesting(NativeDatabase.memory()),
      backup = backup ?? MemoryKeyBackup() {
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncSessionProvider.overrideWithValue(session),
        syncBackendProvider.overrideWithValue(server.client()),
        syncKeyStoreProvider.overrideWithValue(keys),
        syncKeyBackupProvider.overrideWithValue(this.backup),
      ],
    );
  }

  final AppDatabase db;
  final session = FakeSession();
  final keys = MemoryKeyStore();
  final MemoryKeyBackup backup;
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

/// A first phone on [user] with one account uploaded.
Future<Device> _setUp(FakeSyncServer server, String user) async {
  final phone = Device(server);
  addTearDown(phone.dispose);
  await phone.controller.start();
  await FinanceRepository(
    phone.db,
    FileStorageService(),
  ).createAccount(name: 'Bank', type: 'savings', balanceMinor: 5000);
  phone.session.signIn(user);
  await phone.settle((s) => s.phase == SyncPhase.needsSetup);
  await phone.controller.saveRecoveryKey(phone.controller.newAccountKeys());
  await phone.settle(_synced);
  return phone;
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

  group('platform key backup', () {
    Future<Device> setUpFirst(String user, MemoryKeyBackup cloud) async {
      final phone = Device(server, backup: cloud);
      addTearDown(phone.dispose);
      await phone.controller.start();
      await FinanceRepository(
        phone.db,
        FileStorageService(),
      ).createAccount(name: 'Bank', type: 'savings', balanceMinor: 5000);
      phone.session.signIn(user);
      await phone.settle((s) => s.phase == SyncPhase.needsSetup);
      await phone.controller.saveRecoveryKey(
        phone.controller.newAccountKeys(),
      );
      await phone.settle(
        (s) => _synced(s) && s.keyBackedUpTo == 'your Google account',
      );
      return phone;
    }

    test('a new phone on the same account unlocks without the key', () async {
      final cloud = MemoryKeyBackup();
      final first = await setUpFirst('user-b1', cloud);
      expect(cloud.keys['user-b1'], first.keys.keys['user-b1']);

      final second = Device(server, backup: cloud);
      addTearDown(second.dispose);
      await second.controller.start();
      second.session.signIn('user-b1');
      await second.settle(_synced);
      expect(second.keys.keys['user-b1'], first.keys.keys['user-b1']);
      final accounts = await second.db.select(second.db.accounts).get();
      expect(accounts.single.balanceMinor, 5000);
    });

    test('a different Google account still needs the recovery key', () async {
      await setUpFirst('user-b2', MemoryKeyBackup());
      final second = Device(server);
      addTearDown(second.dispose);
      await second.controller.start();
      second.session.signIn('user-b2');
      await second.settle((s) => s.phase == SyncPhase.needsRecoveryKey);
    });

    test('a key that opens nothing is ignored and removed', () async {
      final cloud = MemoryKeyBackup();
      await setUpFirst('user-b3', cloud);
      cloud.keys['user-b3'] = SyncCrypto().newDataKey();

      final second = Device(server, backup: cloud);
      addTearDown(second.dispose);
      await second.controller.start();
      second.session.signIn('user-b3');
      await second.settle((s) => s.phase == SyncPhase.needsRecoveryKey);
      expect(cloud.keys, isNot(contains('user-b3')));
    });

    test('kept only on the phone: no claim it is backed up', () async {
      final cloud = MemoryKeyBackup()..offPhone = false;
      final phone = Device(server, backup: cloud);
      addTearDown(phone.dispose);
      await phone.controller.start();
      phone.session.signIn('user-b4');
      await phone.settle((s) => s.phase == SyncPhase.needsSetup);
      await phone.controller.saveRecoveryKey(
        phone.controller.newAccountKeys(),
      );
      await phone.settle(_synced);
      expect(phone.status.keyBackedUpTo, isNull);
    });

    test('sign-out keeps the backup; deleting the account removes it',
        () async {
      final cloud = MemoryKeyBackup();
      final phone = await setUpFirst('user-b5', cloud);
      await phone.controller.signOut();
      expect(cloud.keys, contains('user-b5'));

      phone.session.signIn('user-b5');
      await phone.settle(_synced);
      await phone.controller.deleteAccount();
      expect(cloud.keys, isNot(contains('user-b5')));
    });
  });

  group('approve from another phone', () {
    test('a syncing phone hands its key to the one showing the code',
        () async {
      final first = await _setUp(server, 'user-l1');
      final second = Device(server);
      addTearDown(second.dispose);
      await second.controller.start();
      second.session.signIn('user-l1');
      await second.settle((s) => s.phase == SyncPhase.needsRecoveryKey);

      final request = await second.controller.startLink();
      expect(await second.controller.collectLink(request), isFalse);

      await first.controller.approveLink(request.code);
      expect(await second.controller.collectLink(request), isTrue);
      await second.settle(_synced);
      expect(second.keys.keys['user-l1'], first.keys.keys['user-l1']);
      expect(server.transfers, isEmpty, reason: 'collected, then removed');
      final accounts = await second.db.select(second.db.accounts).get();
      expect(accounts.single.balanceMinor, 5000);
    });

    test('a scanned code that is not LifeOS changes nothing', () async {
      final first = await _setUp(server, 'user-l2');
      await expectLater(
        first.controller.approveLink('https://example.com'),
        throwsA(isA<SyncCryptoException>()),
      );
      expect(server.transfers, isEmpty);
    });
  });

  test('checking a recovery key changes nothing', () async {
    final phone = Device(server);
    addTearDown(phone.dispose);
    await phone.controller.start();
    phone.session.signIn('user-c1');
    await phone.settle((s) => s.phase == SyncPhase.needsSetup);
    final pending = phone.controller.newAccountKeys();
    await phone.controller.saveRecoveryKey(pending);
    await phone.settle(_synced);
    final stored = server.wrappedKey;

    expect(await phone.controller.checkRecoveryKey(pending.recoveryKey), isTrue);
    expect(
      await phone.controller.checkRecoveryKey(SyncCrypto().newRecoveryKey()),
      isFalse,
    );
    expect(await phone.controller.checkRecoveryKey('not a key'), isFalse);
    expect(server.wrappedKey, same(stored));
  });

  group('Standard recovery', () {
    Future<Device> standardPhone(String user) async {
      final phone = Device(server);
      addTearDown(phone.dispose);
      await phone.controller.start();
      await FinanceRepository(
        phone.db,
        FileStorageService(),
      ).createAccount(name: 'Bank', type: 'savings', balanceMinor: 5000);
      phone.session.signIn(user);
      await phone.settle((s) => s.phase == SyncPhase.needsSetup);
      await phone.controller.saveRecoveryKey(
        phone.controller.newAccountKeys(),
        serverRecovery: true,
      );
      await phone.settle(_synced);
      return phone;
    }

    test('signing in on a new phone is enough', () async {
      final first = await standardPhone('user-s1');
      expect(first.status.serverRecovery, isTrue);
      expect(server.escrow, first.keys.keys['user-s1']);

      // A different Google account and no other phone: only the server's
      // copy can unlock it.
      final second = Device(server);
      addTearDown(second.dispose);
      await second.controller.start();
      second.session.signIn('user-s1');
      await second.settle(_synced);
      expect(second.status.serverRecovery, isTrue);
      final accounts = await second.db.select(second.db.accounts).get();
      expect(accounts.single.balanceMinor, 5000);
    });

    test('Maximum privacy keeps no copy on the server', () async {
      final phone = await _setUp(server, 'user-s2');
      expect(server.escrow, isNull);
      await phone.settle((s) => s.serverRecovery == false);
    });

    test('it can be switched either way', () async {
      final phone = await _setUp(server, 'user-s3');
      await phone.settle((s) => s.serverRecovery == false);
      await phone.controller.setServerRecovery(true);
      expect(server.escrow, phone.keys.keys['user-s3']);
      expect(phone.status.serverRecovery, isTrue);

      await phone.controller.setServerRecovery(false);
      expect(server.escrow, isNull);
      expect(phone.status.serverRecovery, isFalse);
    });

    test("a server copy that doesn't open the data is ignored", () async {
      await standardPhone('user-s4');
      server.escrow = SyncCrypto().newDataKey();
      final second = Device(server);
      addTearDown(second.dispose);
      await second.controller.start();
      second.session.signIn('user-s4');
      await second.settle((s) => s.phase == SyncPhase.needsRecoveryKey);
    });

    test('deleting the account removes the copy', () async {
      final phone = await standardPhone('user-s5');
      await phone.controller.deleteAccount();
      expect(server.escrow, isNull);
    });
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
