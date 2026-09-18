import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/motion.dart';
import 'package:life_manager/app/theme/app_colors.dart';
import 'package:life_manager/app/theme/app_spacing.dart';
import 'package:life_manager/app/theme/app_theme.dart';

/// Pins the rules `ui-kit/BRAND_AND_UI_KIT.md` calls non-negotiable.
///
/// These are the ones that fail silently: a semantic colour reused across themes
/// is invisible rather than wrong-looking, and a missing brand asset only shows
/// up at `flutter build` time.
void main() {
  group('semantic colours are per-theme pairs', () {
    // Kit §2: "a semantic ink that works on cream is invisible on near-black.
    // Every status colour therefore has two values."
    const pairs = <String, (Color, Color)>{
      'critical/danger': (Color(0xFFA62F2F), Color(0xFFF87171)),
      'warning/warn': (Color(0xFF8A6410), Color(0xFFE3B341)),
      'warm': (Color(0xFF8C4C22), Color(0xFFE09A6B)),
      'info/cool': (Color(0xFF35618A), Color(0xFF8FBBE0)),
      'deep': (Color(0xFF5E4FA8), Color(0xFFB4A7EC)),
    };

    test('each status ink differs between light and dark', () {
      final light = AppColors.light;
      final dark = AppColors.dark;
      final actual = <String, (Color, Color)>{
        'critical/danger': (light.critical, dark.critical),
        'warning/warn': (light.warning, dark.warning),
        'warm': (light.warm, dark.warm),
        'info/cool': (light.info, dark.info),
        'deep': (light.deep, dark.deep),
      };

      for (final entry in pairs.entries) {
        final got = actual[entry.key]!;
        expect(got.$1, entry.value.$1, reason: '${entry.key} light');
        expect(got.$2, entry.value.$2, reason: '${entry.key} dark');
        expect(
          got.$1,
          isNot(got.$2),
          reason: '${entry.key} must not reuse one hex across both themes',
        );
      }
    });

    test('success is the accent — there is no second green', () {
      expect(AppColors.light.good, AppColors.light.catDining);
      expect(AppColors.light.good, const Color(0xFF0E9F6E));
      expect(AppColors.dark.good, const Color(0xFF34D399));
    });

    test('category hues identify things, so they do not change with theme', () {
      // Kit §2: "Category hues — identity only, never state."
      expect(AppColors.light.spendCategoryPalette,
          AppColors.dark.spendCategoryPalette);
      expect(AppColors.light.modulePalette, AppColors.dark.modulePalette);
    });

    test('every token lerps — none is dropped from lerp()', () {
      // A field missing from lerp() silently snaps instead of animating.
      final mid = AppColors.light.lerp(AppColors.dark, 1.0);
      expect(mid.critical, AppColors.dark.critical);
      expect(mid.codeBg, AppColors.dark.codeBg);
      expect(mid.warmSoft, AppColors.dark.warmSoft);
      expect(mid.dangerBd, AppColors.dark.dangerBd);
    });
  });

  group('metrics', () {
    test('radii follow the kit ladder and step down by 4', () {
      expect(AppSpacing.cardRadius, 22);
      expect(AppSpacing.tileRadius, 16);
      expect(AppSpacing.chipRadius, 12);
      expect(AppSpacing.swatchRadius, 8);
      expect(AppSpacing.tileRadius - AppSpacing.chipRadius, 4);
      expect(AppSpacing.chipRadius - AppSpacing.swatchRadius, 4);
    });

    test('buttons and touch targets match the kit', () {
      expect(AppSpacing.primaryButtonHeight, 48);
      expect(AppSpacing.primaryButtonRadius, 14);
      expect(AppSpacing.controlHeight, 48);
      expect(AppSpacing.fabSize, 56);
      expect(AppSpacing.fabRadius, 19);
      expect(AppSpacing.minTouchTarget, 44);
    });

    test('the themed primary button never demands infinite width', () {
      // Regression: Size.fromHeight() is Size(double.infinity, h), which crashes
      // any button outside a width-bounded parent.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final size = theme.filledButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{});
        expect(size, isNotNull);
        expect(size!.width.isFinite, isTrue);
        expect(size.height, AppSpacing.primaryButtonHeight);
      }
    });
  });

  group('motion', () {
    testWidgets('reduced motion collapses every duration to 160ms', (
      tester,
    ) async {
      late BuildContext reduced;
      late BuildContext normal;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (context) {
            reduced = context;
            return const SizedBox();
          }),
        ),
      );
      expect(AppMotion.of(reduced, AppMotion.sheetOpen), AppMotion.reduced);
      expect(AppMotion.of(reduced, AppMotion.screenEnter), AppMotion.reduced);
      // And the press scale flattens rather than bouncing.
      expect(AppMotion.pressScaleOf(reduced), 1);
      expect(AppMotion.curveOf(reduced, AppMotion.sheetIn), Curves.linear);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(builder: (context) {
            normal = context;
            return const SizedBox();
          }),
        ),
      );
      expect(AppMotion.of(normal, AppMotion.sheetOpen), AppMotion.sheetOpen);
      expect(AppMotion.pressScaleOf(normal), AppMotion.pressedScale);
      expect(AppMotion.pressScaleOf(normal, small: true),
          AppMotion.smallPressScale);
    });

    test('press timing matches the kit', () {
      expect(AppMotion.tap, const Duration(milliseconds: 120));
      expect(AppMotion.pressedScale, 0.97);
      expect(AppMotion.smallPressScale, 0.94);
    });
  });

  group('brand assets', () {
    // These only fail at `flutter build` otherwise, long after the mistake.
    test('launcher and splash assets exist and are PNGs', () {
      const expected = [
        'assets/icon/icon.png',
        'assets/icon/icon_foreground.png',
        'assets/icon/icon_background.png',
        'assets/icon/splash_logo.png',
        'assets/icon/splash_logo_dark.png',
      ];
      for (final path in expected) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        final header = file.readAsBytesSync().take(8).toList();
        expect(
          header,
          [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
          reason: '$path is not a PNG',
        );
      }
    });

    test('pubspec points the adaptive icon at the ring-only foreground', () {
      // Kit §1: handing the full-bleed square to the foreground slot lets the
      // OS mask and parallax clip the dot off the ring.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('adaptive_icon_foreground: assets/icon/icon_foreground.png'),
      );
      expect(
        pubspec,
        contains('adaptive_icon_background: assets/icon/icon_background.png'),
      );
      // The pre-rebrand violet must not survive anywhere in the icon config.
      expect(pubspec, isNot(contains('6750E7')));
    });

    test('the three font families the kit names are registered', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final family in ['Manrope', 'Newsreader', 'JetBrainsMono']) {
        expect(pubspec, contains('family: $family'));
      }
    });
  });
}
