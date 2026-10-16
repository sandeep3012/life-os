import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/sync/application/sync_engine.dart';
import 'package:life_manager/features/sync/data/local_sync_store.dart';
import 'package:life_manager/features/sync/domain/sync_crypto.dart';

import 'sync_fakes.dart';

final _crypto = SyncCrypto();
final _dataKey = _crypto.newDataKey();

/// One phone: its own database, signed in to the shared fake server.
class Phone {
  Phone(this.server)
    : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    store = LocalSyncStore(db);
    finance = FinanceRepository(db, FileStorageService());
  }

  final FakeSyncServer server;
  final AppDatabase db;
  late final LocalSyncStore store;
  late final FinanceRepository finance;

  Future<void> enable() async {
    await store.installTriggers();
    await store.queueAll();
  }

  Future<SyncRoundResult> sync({int? schemaVersion}) async => SyncEngine(
    store: store,
    backend: server.client(),
    crypto: _crypto,
    dataKey: _dataKey,
    deviceId: await store.deviceId(),
    schemaVersion: schemaVersion ?? db.schemaVersion,
  ).run();

  Future<Account> account(String name) => (db.select(
    db.accounts,
  )..where((a) => a.name.equals(name))).getSingle();

  Future<String> addAccount(String name, int balance) async {
    await finance.createAccount(
      name: name,
      type: 'savings',
      balanceMinor: balance,
    );
    return (await account(name)).id;
  }

  Future<void> spend(String accountId, int amount, String merchant) =>
      finance.createTransaction(
        accountId: accountId,
        merchant: merchant,
        amountMinor: -amount,
        date: DateTime(2026, 10, 1),
      );
}

/// Phone clocks tick in milliseconds; edits in the same one would tie.
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late FakeSyncServer server;
  late Phone a;
  late Phone b;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    server = FakeSyncServer();
    a = Phone(server);
    b = Phone(server);
    await a.enable();
    await b.enable();
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  test('an account and its transactions reach the other phone', () async {
    final id = await a.addAccount('Bank', 100000);
    await a.spend(id, 2500, 'Coffee');
    final up = await a.sync();
    expect(up.uploaded, greaterThan(0));
    expect(await a.store.pendingCount(), 0);

    final down = await b.sync();
    expect(down.downloaded, greaterThan(0));
    final bank = await b.account('Bank');
    expect(bank.balanceMinor, 97500);
    final txns = await b.db.select(b.db.transactions).get();
    expect(txns.single.merchant, 'Coffee');

    // What arrived didn't queue itself to go straight back up.
    expect(await b.store.pendingCount(), 0);
  });

  test('the server only ever holds ciphertext', () async {
    final id = await a.addAccount('Secret savings', 4200000);
    await a.spend(id, 1234, 'Pharmacy on Elm St');
    await a.sync();
    for (final record in server.records.values) {
      final text = latin1.decode(record.payload);
      expect(text, isNot(contains('Pharmacy')));
      expect(text, isNot(contains('Secret')));
    }
  });

  test('spending on both phones at once keeps both in the balance', () async {
    final id = await a.addAccount('Wallet', 10000);
    await a.sync();
    await b.sync();

    await a.spend(id, 1000, 'Lunch');
    await b.spend(id, 300, 'Bus');
    await a.sync();
    await b.sync();
    await a.sync();

    expect((await a.account('Wallet')).balanceMinor, 8700);
    expect((await b.account('Wallet')).balanceMinor, 8700);
    expect(await a.db.select(a.db.transactions).get(), hasLength(2));
  });

  test('a balance corrected on one phone survives spending on another', () async {
    final id = await a.addAccount('Card', 50000);
    await a.sync();
    await b.sync();

    await a.finance.updateAccount(
      id: id,
      name: 'Card',
      type: 'savings',
      balanceMinor: 60000,
    );
    await tick();
    await b.spend(id, 500, 'Snacks');
    await b.sync();
    await a.sync();
    await b.sync();

    expect((await a.account('Card')).balanceMinor, 59500);
    expect((await b.account('Card')).balanceMinor, 59500);
  });

  test('the later of two edits to the same row wins on both phones', () async {
    final id = await a.addAccount('Old name', 0);
    await a.sync();
    await b.sync();

    await a.finance.updateAccount(
      id: id,
      name: 'From A',
      type: 'savings',
      balanceMinor: 0,
    );
    await tick();
    await b.finance.updateAccount(
      id: id,
      name: 'From B',
      type: 'savings',
      balanceMinor: 0,
    );
    // B uploads first; A's older edit then loses at the server.
    await b.sync();
    await a.sync();
    await b.sync();

    final names = [
      for (final phone in [a, b])
        (await phone.db.select(phone.db.accounts).getSingle()).name,
    ];
    expect(names, ['From B', 'From B']);
  });

  test('deletes reach the other phone', () async {
    final id = await a.addAccount('Bank', 0);
    await a.spend(id, 100, 'Tea');
    await a.sync();
    await b.sync();
    final txn = (await b.db.select(b.db.transactions).get()).single;

    await b.finance.deleteTransaction(txn.id);
    await b.sync();
    await a.sync();

    expect(await a.db.select(a.db.transactions).get(), isEmpty);
    expect((await a.account('Bank')).balanceMinor, 0);
  });

  test('sample data stays on its own phone', () async {
    await a.db
        .into(a.db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value('demo-account-1'),
            name: 'Demo bank',
            type: 'savings',
          ),
        );
    await a.sync();
    await b.sync();
    expect(await b.db.select(b.db.accounts).get(), isEmpty);
  });

  test('without a subscription nothing uploads but nothing is lost', () async {
    server.entitled = false;
    await a.addAccount('Bank', 0);
    final result = await a.sync();
    expect(result.uploadsRefused, isTrue);
    expect(server.records, isEmpty);
    expect(await a.store.pendingCount(), greaterThan(0));

    server.entitled = true;
    await a.sync();
    await b.sync();
    expect((await b.account('Bank')).name, 'Bank');
  });

  test('a failed round leaves everything to retry', () async {
    await a.addAccount('Bank', 0);
    final waiting = await a.store.pendingCount();
    server.offline = true;
    await expectLater(a.sync(), throwsA(anything));
    expect(await a.store.pendingCount(), waiting);

    server.offline = false;
    await a.sync();
    await b.sync();
    expect((await b.account('Bank')).name, 'Bank');
  });

  test('a phone that joins later gets everything, and keeps its own', () async {
    final newcomer = Phone(server);
    addTearDown(newcomer.db.close);
    await newcomer.addAccount('Cash on the new phone', 2000);

    final id = await a.addAccount('Bank', 0);
    await a.spend(id, 100, 'Tea');
    await a.sync();

    await newcomer.enable();
    await newcomer.sync();
    await a.sync();
    final names = {
      for (final x in await newcomer.db.select(newcomer.db.accounts).get()) x.name,
    };
    expect(names, {'Bank', 'Cash on the new phone'});
    expect((await a.account('Cash on the new phone')).balanceMinor, 2000);
  });

  test('defaults created separately on two phones merge into one', () async {
    Future<String> dining(Phone phone, String id) async {
      await phone.db
          .into(phone.db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: Value(id),
              name: 'Dining',
              colorHex: '#E0475A',
            ),
          );
      return id;
    }

    await dining(a, 'aaaa-dining');
    final bDining = await dining(b, 'bbbb-dining');
    final bank = await b.addAccount('Bank', 0);
    await b.finance.createTransaction(
      accountId: bank,
      categoryId: bDining,
      merchant: 'Dinner',
      amountMinor: -900,
      date: DateTime(2026, 10, 1),
    );

    await a.sync();
    await b.sync();
    await a.sync();
    await b.sync();

    for (final phone in [a, b]) {
      final categories = await (phone.db.select(
        phone.db.categories,
      )..where((c) => c.name.equals('Dining'))).get();
      expect(categories.single.id, 'aaaa-dining');
      final txn = (await phone.db.select(phone.db.transactions).get()).single;
      expect(txn.categoryId, 'aaaa-dining');
    }
  });

  test('a record from a newer app version waits for an update', () async {
    await a.addAccount('From the future', 0);
    await a.sync(schemaVersion: 999);

    await b.sync();
    expect(await b.db.select(b.db.accounts).get(), isEmpty);

    // After "updating" the app, the held record is applied.
    await b.sync(schemaVersion: 999);
    expect((await b.account('From the future')).name, 'From the future');
  });

  test('a damaged record is skipped without blocking the rest', () async {
    await a.addAccount('One', 0);
    await a.addAccount('Two', 0);
    await a.sync();
    final victim = server.records.values.first;
    final payload = [...victim.payload]..[40] ^= 0xff;
    server.records[victim.id] = RemoteRecordCopy.withPayload(victim, payload);

    final result = await b.sync();
    expect(result.skipped, 1);
    expect(await b.db.select(b.db.accounts).get(), hasLength(1));
  });
}
