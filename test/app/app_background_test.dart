import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_color_theme.dart';
import 'package:life_manager/app/theme/app_theme.dart';

void main() {
  test('five themes remain, and a removed one falls back to Forest', () {
    expect(AppColorTheme.values.map((t) => t.label), [
      'Forest',
      'OLED Midnight',
      'Ocean',
      'Indigo',
      'Plum',
    ]);
    for (final gone in [
      'nordicSlate',
      'matchaSand',
      'warmSandstone',
      'terracotta',
    ]) {
      expect(appColorThemeFromStorage(gone), AppColorTheme.forest);
    }
  });

  test('every theme offers distinct backgrounds, Cream among them', () {
    for (final theme in AppColorTheme.values) {
      final colors = [
        for (final b in theme.backgrounds) theme.lightBackground(b),
      ];
      expect(colors.toSet(), hasLength(colors.length), reason: theme.label);
      expect(colors, contains(const Color(0xFFF5F1E9)), reason: theme.label);
      expect(theme.backgrounds.length, greaterThanOrEqualTo(3));
    }
    // Forest's recommended background is cream, so it's listed once.
    expect(
      AppColorTheme.forest.backgrounds,
      isNot(contains(AppBackground.recommended)),
    );
    expect(
      AppColorTheme.forest.shown(AppBackground.recommended),
      AppBackground.cream,
    );
    expect(
      AppColorTheme.forest.saved(AppBackground.cream),
      AppBackground.recommended,
    );
    expect(AppColorTheme.ocean.saved(AppBackground.cream), AppBackground.cream);
  });

  test('the chosen background is the page colour in light mode only', () {
    final stone = AppColorTheme.ocean.lightBackground(AppBackground.stone);
    expect(
      AppTheme.light(
        AppColorTheme.ocean,
        AppBackground.stone,
      ).scaffoldBackgroundColor,
      stone,
    );
    expect(
      AppTheme.light(AppColorTheme.ocean).scaffoldBackgroundColor,
      const Color(0xFFF8EFE3),
      reason: "Ocean's recommended pairing",
    );
    expect(
      AppTheme.dark(AppColorTheme.ocean).scaffoldBackgroundColor,
      const Color(0xFF161412),
    );
  });

  test('cards stand out from every offered background', () {
    for (final theme in AppColorTheme.values) {
      for (final background in theme.backgrounds) {
        if (background == AppBackground.softWhite) continue;
        final page = theme.lightBackground(background).computeLuminance();
        final ratio = (1.0 + 0.05) / (page + 0.05);
        expect(
          ratio,
          greaterThan(1.1),
          reason: '${theme.label} on ${background.label}',
        );
      }
    }
  });

  test('an unknown stored background means Recommended', () {
    expect(AppBackground.fromStorage('stone'), AppBackground.stone);
    expect(AppBackground.fromStorage('nope'), AppBackground.recommended);
    expect(AppBackground.fromStorage(null), AppBackground.recommended);
  });
}
