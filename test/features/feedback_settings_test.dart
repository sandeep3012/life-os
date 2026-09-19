import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/settings/data/settings_repository.dart';

void main() {
  test(
    'v21 migration preserves settings; feedback preferences persist independently',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feedback_settings_',
      );
      final file = File('${directory.path}/settings.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await SettingsRepository(db).setCurrencyCode('USD');
        await db.customStatement(
          'ALTER TABLE app_settings DROP COLUMN haptics_enabled',
        );
        await db.customStatement(
          'ALTER TABLE app_settings DROP COLUMN save_animations_enabled',
        );
        await db.customStatement('PRAGMA user_version = 21');
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        var row = await db.select(db.appSettings).getSingle();
        expect(row.currencyCode, 'USD');
        expect(row.hapticsEnabled, isTrue);
        expect(row.saveAnimationsEnabled, isTrue);
        final repository = SettingsRepository(db);
        await repository.setHapticsEnabled(false);
        row = await db.select(db.appSettings).getSingle();
        expect(row.hapticsEnabled, isFalse);
        expect(row.saveAnimationsEnabled, isTrue);
        await repository.setSaveAnimationsEnabled(false);
        await repository.setHapticsEnabled(true);
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        row = await db.select(db.appSettings).getSingle();
        expect(row.hapticsEnabled, isTrue);
        expect(row.saveAnimationsEnabled, isFalse);
        expect(row.currencyCode, 'USD');
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
