import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Builds the app's light/dark ThemeData. Neutrals and module accents are
/// pinned to the exact values validated in the prototype mock-up (rather than
/// left to ColorScheme.fromSeed's auto-derived tones) so the shipped app
/// matches it pixel-for-pixel; only the handful of slots the prototype
/// doesn't define (secondary/tertiary roles) fall back to seed-derived tones.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _buildTheme(Brightness.light);

  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final appColors = isLight ? AppColors.light : AppColors.dark;

    const lightNeutrals = _Neutrals(
      bg: Color(0xFFF3F1FA),
      surface: Color(0xFFFFFFFF),
      surfaceDim: Color(0xFFFBFAFE),
      surfaceSunken: Color(0xFFECE8F7),
      ink: Color(0xFF211B36),
      ink2: Color(0xFF5B5570),
      ink3: Color(0xFF8B84A3),
      border: Color(0xFFE4E0F0),
      brandOn: Colors.white,
      brandSoft: Color(0xFFEAE5FC),
    );
    const darkNeutrals = _Neutrals(
      bg: Color(0xFF14121F),
      surface: Color(0xFF1E1B2E),
      surfaceDim: Color(0xFF262238),
      surfaceSunken: Color(0xFF100E19),
      ink: Color(0xFFECE9F7),
      ink2: Color(0xFFABA5C4),
      ink3: Color(0xFF726C8C),
      border: Color(0xFF322D48),
      brandOn: Color(0xFF14121F),
      brandSoft: Color(0xFF2B2450),
    );

    final neutrals = isLight ? lightNeutrals : darkNeutrals;
    final brand = isLight ? AppColors.seed : const Color(0xFF8D7BF5);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    ).copyWith(
      primary: brand,
      onPrimary: neutrals.brandOn,
      primaryContainer: neutrals.brandSoft,
      onPrimaryContainer: brand,
      surface: neutrals.surface,
      onSurface: neutrals.ink,
      onSurfaceVariant: neutrals.ink2,
      surfaceContainer: neutrals.surfaceDim,
      surfaceContainerHigh: neutrals.surface,
      surfaceContainerHighest: neutrals.surfaceSunken,
      outline: neutrals.border,
      outlineVariant: neutrals.border,
      error: appColors.critical,
    );

    final textTheme = _buildTextTheme(brightness, neutrals.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: neutrals.bg,
      fontFamily: 'Figtree',
      textTheme: textTheme,
      extensions: [appColors],
      cardTheme: CardThemeData(
        elevation: 0,
        color: neutrals.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: neutrals.border),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: neutrals.bg,
        foregroundColor: neutrals.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: neutrals.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: neutrals.brandSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? brand : neutrals.ink3,
            fontWeight: FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? brand : neutrals.ink3);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: neutrals.surface,
        side: BorderSide(color: neutrals.border),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutrals.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: neutrals.brandOn,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
      ),
      dividerTheme: DividerThemeData(color: neutrals.border, space: 1),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Fraunces carries headings and hero numbers; Figtree carries everything
  /// else. Sizes/heights come from Material 3's default type scale — only
  /// fontFamily/weight are swapped in, per role, to match the prototype.
  static TextTheme _buildTextTheme(Brightness brightness, Color ink) {
    final base = Typography.material2021(
      platform: TargetPlatform.android,
    ).black.apply(displayColor: ink, bodyColor: ink);

    TextStyle? display(TextStyle? s, {FontWeight w = FontWeight.w700}) =>
        s?.copyWith(fontFamily: 'Fraunces', fontWeight: w, letterSpacing: -0.2);
    TextStyle? body(TextStyle? s, {FontWeight w = FontWeight.w400}) =>
        s?.copyWith(fontFamily: 'Figtree', fontWeight: w);

    return base.copyWith(
      displayLarge: display(base.displayLarge),
      displayMedium: display(base.displayMedium),
      displaySmall: display(base.displaySmall),
      headlineLarge: display(base.headlineLarge),
      headlineMedium: display(base.headlineMedium, w: FontWeight.w600),
      headlineSmall: display(base.headlineSmall, w: FontWeight.w600),
      titleLarge: body(base.titleLarge, w: FontWeight.w700),
      titleMedium: body(base.titleMedium, w: FontWeight.w700),
      titleSmall: body(base.titleSmall, w: FontWeight.w600),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge, w: FontWeight.w700),
      labelMedium: body(base.labelMedium, w: FontWeight.w600),
      labelSmall: body(base.labelSmall, w: FontWeight.w600),
    );
  }
}

/// Monospace text style for currency figures, dates, and other tabular data —
/// mirrors the prototype's `--font-mono` (Plex Mono) role, which has no
/// equivalent slot in Flutter's [TextTheme].
class AppMonoText {
  AppMonoText._();

  static TextStyle style({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'PlexMono',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

class _Neutrals {
  const _Neutrals({
    required this.bg,
    required this.surface,
    required this.surfaceDim,
    required this.surfaceSunken,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
    required this.brandOn,
    required this.brandSoft,
  });

  final Color bg;
  final Color surface;
  final Color surfaceDim;
  final Color surfaceSunken;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color border;
  final Color brandOn;
  final Color brandSoft;
}
