import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_font_style.dart';
import 'package:life_manager/app/theme/app_fonts.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';

double _width(String family) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'Hamburgefonstiv 12345',
      style: TextStyle(fontFamily: family, fontSize: 40),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  test('every style has its files, licence and pubspec entry', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final style in AppFontStyle.values) {
      for (final (family, asset) in [
        (style.headingFamily, style.headingAsset),
        (style.bodyFamily, style.bodyAsset),
      ]) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
        expect(pubspec, contains('family: $family'), reason: family);
        expect(pubspec, contains('- asset: $asset'), reason: asset);
        expect(
          File('assets/fonts/OFL-${family.toLowerCase()}.txt').existsSync(),
          isTrue,
          reason: 'the licence ships with $family',
        );
      }
    }
  });

  test('an unknown stored value falls back to Classic', () {
    expect(AppFontStyle.fromStorage('easy_read'), AppFontStyle.easyRead);
    expect(AppFontStyle.fromStorage('gone'), AppFontStyle.classic);
    expect(AppFontStyle.fromStorage(null), AppFontStyle.classic);
    expect({
      for (final s in AppFontStyle.values) s.storageValue,
    }, hasLength(AppFontStyle.values.length));
  });

  test('the app font names follow the chosen style', () {
    addTearDown(() => AppFonts.use(AppFontStyle.classic));
    expect(AppFonts.serif, 'Newsreader');
    expect(AppFonts.sans, 'Manrope');

    AppFonts.use(AppFontStyle.elegant);
    expect(AppFonts.serif, 'PlayfairDisplay');
    expect(AppFonts.sans, 'DMSans');
    expect(AppFonts.numeric, 'DMSans', reason: 'figures match body text');
    expect(AppFonts.mono, 'JetBrainsMono', reason: 'code stays monospace');
  });

  test('the chosen style is saved and read back', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final sub = container.listen(settingsProvider, (_, _) {});
    expect(container.read(settingsProvider).fontStyle, AppFontStyle.classic);

    await container
        .read(settingsControllerProvider)
        .setFontStyle(AppFontStyle.friendly);
    for (var i = 0; i < 50; i++) {
      if (container.read(settingsProvider).fontStyle != AppFontStyle.classic) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(settingsProvider).fontStyle, AppFontStyle.friendly);
    sub.close();
  });

  testWidgets('each bundled font really is a different face', (tester) async {
    final widths = <String, double>{};
    for (final style in AppFontStyle.values) {
      for (final (family, asset) in [
        (style.headingFamily, style.headingAsset),
        (style.bodyFamily, style.bodyAsset),
      ]) {
        if (widths.containsKey(family)) continue;
        await tester.runAsync(
          () => (FontLoader(family)..addFont(rootBundle.load(asset))).load(),
        );
        widths[family] = _width(family);
      }
    }
    expect(widths.values.toSet(), hasLength(widths.length), reason: '$widths');
  });
}
