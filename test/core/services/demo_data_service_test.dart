import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/demo_data_service.dart';

void main() {
  late AppDatabase db;
  late DemoDataService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = DemoDataService(db);
  });

  tearDown(() => db.close());

  test('generates and removes only prefixed demo records', () async {
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: const Value('real-account'),
        name: 'Personal account',
        type: 'Savings',
      ),
    );

    final summary = await service.generate(months: 2);

    expect(summary.transactions, 52);
    expect(summary.tasks, 16);
    expect(summary.events, 8);
    expect(summary.habitLogs, greaterThan(0));
    expect(await service.hasDemoData, isTrue);

    await expectLater(
      service.generate(months: 2),
      throwsA(isA<StateError>()),
    );

    await service.remove();

    expect(await service.hasDemoData, isFalse);
    expect(
      await (db.select(db.accounts)
            ..where((account) => account.id.equals('real-account')))
          .getSingleOrNull(),
      isNotNull,
    );
    expect(
      await (db.select(db.transactions)
            ..where((row) => row.id.like('demo-%')))
          .get(),
      isEmpty,
    );
  });
}
