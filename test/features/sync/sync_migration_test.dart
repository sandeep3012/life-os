import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';

void main() {
  test('upgrading to v34 keeps every balance and works out the opening', () async {
    final dir = await Directory.systemTemp.createTemp('lifeos_sync_');
    final file = File('${dir.path}/sync.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: const Value('acc'),
              name: 'Bank',
              type: 'savings',
              balanceMinor: const Value(10000),
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: 'acc',
              merchant: 'Rent',
              amountMinor: -2500,
              date: DateTime(2026, 9, 1),
            ),
          );
      await db.customStatement(
        'ALTER TABLE accounts DROP COLUMN opening_balance_minor',
      );
      for (final table in ['sync_outbox', 'sync_state', 'sync_held']) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('PRAGMA user_version = 33');
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      final account = await db.select(db.accounts).getSingle();
      expect(account.balanceMinor, 10000);
      expect(account.openingBalanceMinor, 12500);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
      expect(await db.select(db.syncState).get(), isEmpty);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
}
