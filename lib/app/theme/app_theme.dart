import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_spacing.dart';

/// Builds the app's light/dark [ThemeData] from the design comp
/// (`LifeOS.dc.html`). Neutrals are pinned to the comp's exact CSS custom
/// properties rather than left to `ColorScheme.fromSeed`'s derived tones, so the
/// shipped app matches it; only the roles the comp never shows
/// (secondary/tertiary containers) fall back to seed-derived values.
///
/// The comp's palette is warm and paper-like — a bone background with pure-white
/// cards in light, a warm near-black with lifted brown-grey cards in dark — with
/// a single green accent doing all the emphasis work. Note the comp separates
/// `--accent` (#0E9F6E, highlights and data) from `--btn` (#0B7C56, the darker
/// green that actually fills primary buttons in light mode); that distinction is
/// preserved here as [ColorScheme.primary] (button) vs [AppColors.good] (accent).
class AppTheme {
  AppTheme._();

  static ThemeData light() => _buildTheme(Brightness.light);

  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final appColors = isLight ? AppColors.light : AppColors.dark;

    const lightNeutrals = _Neutrals(
      bg: Color(0xFFF5F1E9), // --bg
      surface: Color(0xFFFFFFFF), // --surface
      surfaceDim: Color(0xFFFAF6EE), // --surface-2
      raised: Color(0xFFFFFFFF), // --raised
      ink: Color(0xFF1C1B18), // --text
      ink2: Color(0xFF6E6A61), // --text-2
      border: Color(0x171C1B18), // --border  rgba(28,27,24,.09)
      border2: Color(0x0F1C1B18), // --border-2 rgba(28,27,24,.06)
      btn: Color(0xFF0B7C56), // --btn
      brandOn: Color(0xFFFFFFFF), // --on-accent
    );
    const darkNeutrals = _Neutrals(
      bg: Color(0xFF161512),
      surface: Color(0xFF201E1A),
      surfaceDim: Color(0xFF2A2823),
      raised: Color(0xFF26241F),
      ink: Color(0xFFF4F0E7),
      ink2: Color(0xFFA9A499),
      border: Color(0x1AFFFFFF), // rgba(255,255,255,.10)
      border2: Color(0x0DFFFFFF), // rgba(255,255,255,.05)
      btn: Color(0xFF34D399),
      brandOn: Color(0xFF0C0B09),
    );

    final neutrals = isLight ? lightNeutrals : darkNeutrals;
    final brand = neutrals.btn;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    ).copyWith(
      primary: brand,
      onPrimary: neutrals.brandOn,
      primaryContainer: appColors.accentSoft,
      onPrimaryContainer: appColors.accentInk,
      secondary: appColors.good,
      onSecondary: neutrals.brandOn,
      surface: neutrals.surface,
      onSurface: neutrals.ink,
      onSurfaceVariant: neutrals.ink2,
      surfaceContainer: neutrals.surfaceDim,
      surfaceContainerHigh: neutrals.surface,
      surfaceContainerHighest: neutrals.raised,
      outline: neutrals.border,
      outlineVariant: neutrals.border2,
      error: appColors.critical,
      onError: neutrals.brandOn,
    );

    final textTheme = _buildTextTheme(neutrals.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: neutrals.bg,
      fontFamily: AppFonts.sans,
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
        // The shell's own nav is `AppFloatingNavBar` (app/router/app_shell.dart),
        // because the comp's nav is a pill inset from the screen edges and that
        // shape can't be expressed as NavigationBar theming. These values keep
        // any *other* NavigationBar consistent with it: lifted surface, accent on
        // the active item, third text tone on the rest, no indicator pill.
        backgroundColor: appColors.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? appColors.good : appColors.text3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? appColors.good : appColors.text3,
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        // Comp tab rail: a `--surface-2` track holding pills that turn
        // `--surface` when active, with the label going from `--text-2` to
        // `--text`. Emphasis is the raised pill, not a colour wash.
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return neutrals.surface;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return neutrals.ink;
            return neutrals.ink2;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return neutrals.ink;
            return neutrals.ink2;
          }),
          side: WidgetStateProperty.all(BorderSide.none),
          textStyle: WidgetStateProperty.all(
            textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: neutrals.surface,
        side: BorderSide(color: neutrals.border),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // Comp fields are a card-coloured surface with a visible hairline —
        // not a sunken fill — at radius 15.
        filled: true,
        fillColor: neutrals.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          borderSide: BorderSide(color: neutrals.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          borderSide: BorderSide(color: neutrals.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          borderSide: BorderSide(color: appColors.good, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          borderSide: BorderSide(color: appColors.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          borderSide: BorderSide(color: appColors.critical, width: 1.6),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: appColors.text3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle(textTheme)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(textTheme).copyWith(
          elevation: const WidgetStatePropertyAll<double>(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(appColors.accentInk),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(neutrals.ink),
          side: WidgetStatePropertyAll(BorderSide(color: neutrals.border)),
          // Height only — see _primaryButtonStyle on why not Size.fromHeight.
          minimumSize: const WidgetStatePropertyAll(
            Size(64, AppSpacing.controlHeight),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: neutrals.brandOn,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: neutrals.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: appColors.stage.withValues(alpha: 0.55),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: neutrals.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
      dividerTheme: DividerThemeData(color: neutrals.border, space: 1),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Primary CTA, per the handoff spec: 54px tall, radius 16, accent fill,
  /// `onAccent` ink, label 15.5px w700. Deliberately one step larger than the
  /// 52px/r15 input rows.
  static ButtonStyle _primaryButtonStyle(TextTheme textTheme) {
    return ButtonStyle(
      // Height only — deliberately NOT Size.fromHeight, which is
      // Size(double.infinity, h) and would force every button in the app to
      // demand infinite width, crashing any that isn't inside a width-bounded
      // parent. Full-width CTAs get their width from their layout instead.
      minimumSize: const WidgetStatePropertyAll(
        Size(64, AppSpacing.primaryButtonHeight),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.primaryButtonRadius),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        textTheme.labelLarge?.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Newsreader carries every heading role — including card and section titles,
  /// which the comp sets in Newsreader 600 at 17px, not in the UI face. Manrope
  /// carries body, labels, buttons and nav. Sizes/heights come from Material 3's
  /// type scale; family, weight and tracking are swapped per role to match the
  /// comp.
  static TextTheme _buildTextTheme(Color ink) {
    final base = Typography.material2021(
      platform: TargetPlatform.android,
    ).black.apply(displayColor: ink, bodyColor: ink);

    // Comp hero headings: Newsreader 500 with `letter-spacing:-.5px`.
    TextStyle? hero(TextStyle? s, {FontWeight w = FontWeight.w500}) => s?.copyWith(
      fontFamily: AppFonts.serif,
      fontWeight: w,
      letterSpacing: -0.5,
    );
    // Comp card/section titles: Newsreader 600, near-neutral tracking.
    TextStyle? title(TextStyle? s) => s?.copyWith(
      fontFamily: AppFonts.serif,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    );
    TextStyle? body(TextStyle? s, {FontWeight w = FontWeight.w400}) =>
        s?.copyWith(fontFamily: AppFonts.sans, fontWeight: w);

    return base.copyWith(
      displayLarge: hero(base.displayLarge),
      displayMedium: hero(base.displayMedium),
      displaySmall: hero(base.displaySmall),
      headlineLarge: hero(base.headlineLarge),
      headlineMedium: hero(base.headlineMedium),
      headlineSmall: title(base.headlineSmall),
      titleLarge: title(base.titleLarge),
      titleMedium: title(base.titleMedium),
      titleSmall: body(base.titleSmall, w: FontWeight.w700),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge, w: FontWeight.w700),
      labelMedium: body(base.labelMedium, w: FontWeight.w600),
      labelSmall: body(base.labelSmall, w: FontWeight.w600),
    );
  }
}

/// Tabular-figure text style for currency figures, dates and other columnar
/// data. The comp has no separate monospace family — it gets aligned digits by
/// applying `font-variant-numeric:tabular-nums` to Manrope — so this now returns
/// Manrope with [FontFeature.tabularFigures], replacing the previous design's
/// Plex Mono role. Kept under the same name and signature so call sites and the
/// intent ("this number belongs in a column") stay unchanged.
class AppMonoText {
  AppMonoText._();

  static TextStyle style({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: AppFonts.numeric,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: AppFonts.tabular,
    );
  }
}

class _Neutrals {
  const _Neutrals({
    required this.bg,
    required this.surface,
    required this.surfaceDim,
    required this.raised,
    required this.ink,
    required this.ink2,
    required this.border,
    required this.border2,
    required this.btn,
    required this.brandOn,
  });

  final Color bg;
  final Color surface;
  final Color surfaceDim;
  final Color raised;
  final Color ink;
  final Color ink2;
  final Color border;
  final Color border2;
  final Color btn;
  final Color brandOn;
}
