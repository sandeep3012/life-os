import 'package:flutter/material.dart';

/// Curated brand palettes. Display mode (light, dark, or system) is selected
/// independently in Settings; every palette supplies both appearances.
enum AppColorTheme { forest, oledMidnight, ocean, indigo, plum }

extension AppColorThemeX on AppColorTheme {
  String get storageValue => name;

  String get label => switch (this) {
    AppColorTheme.oledMidnight => 'OLED Midnight',
    AppColorTheme.forest => 'Forest',
    AppColorTheme.ocean => 'Ocean',
    AppColorTheme.indigo => 'Indigo',
    AppColorTheme.plum => 'Plum',
  };

  Color get previewColor => switch (this) {
    AppColorTheme.oledMidnight => const Color(0xFF4FD1C5),
    AppColorTheme.forest => const Color(0xFF0B7C56),
    AppColorTheme.ocean => const Color(0xFF096B8A),
    AppColorTheme.indigo => const Color(0xFF6750E7),
    AppColorTheme.plum => const Color(0xFF8B3F8F),
  };

  ThemePalette forBrightness(Brightness brightness) {
    final light = brightness == Brightness.light;
    return switch (this) {
      AppColorTheme.oledMidnight =>
        light
            ? const ThemePalette(
                seed: Color(0xFF167C76),
                background: Color(0xFFF7EEE9),
                surface: Color(0xFFFFFFFF),
                surfaceDim: Color(0xFFFBF6F4),
                raised: Color(0xFFFFFFFF),
                stage: Color(0xFFE8E0DB),
                ink: Color(0xFF162427),
                ink2: Color(0xFF617174),
                text3: Color(0xFF899A9B),
                primary: Color(0xFF167C76),
                secondary: Color(0xFF2F925D),
                onPrimary: Color(0xFFFFFFFF),
                accentSoft: Color(0x1F167C76),
                accentInk: Color(0xFF126963),
                heroA: Color(0xFF116E68),
                heroB: Color(0xFF2F925D),
                heroVeil: Color(0x1AFFFFFF),
                heroTrack: Color(0x47FFFFFF),
                codeBg: Color(0xFFF2E9E4),
              )
            : const ThemePalette(
                seed: Color(0xFF4FD1C5),
                background: Color(0xFF121316),
                surface: Color(0xFF1C1E24),
                surfaceDim: Color(0xFF252831),
                raised: Color(0xFF20232B),
                stage: Color(0xFF08090B),
                ink: Color(0xFFE8F3F3),
                ink2: Color(0xFFAFBEC3),
                text3: Color(0xFF748288),
                primary: Color(0xFF4FD1C5),
                secondary: Color(0xFF48BB78),
                onPrimary: Color(0xFF092925),
                accentSoft: Color(0x294FD1C5),
                accentInk: Color(0xFF92E7DF),
                heroA: Color(0xFF178D86),
                heroB: Color(0xFF48BB78),
                heroVeil: Color(0x1A08090B),
                heroTrack: Color(0x3D08090B),
                codeBg: Color(0xFF111217),
              ),
      AppColorTheme.forest =>
        light
            ? const ThemePalette(
                seed: Color(0xFF0E9F6E),
                background: Color(0xFFF5F1E9),
                surface: Color(0xFFFFFFFF),
                surfaceDim: Color(0xFFFAF6EE),
                raised: Color(0xFFFFFFFF),
                stage: Color(0xFFE7E2D8),
                ink: Color(0xFF1C1B18),
                ink2: Color(0xFF6E6A61),
                text3: Color(0xFF9C978C),
                primary: Color(0xFF0B7C56),
                onPrimary: Color(0xFFFFFFFF),
                accentSoft: Color(0x1F0E9F6E),
                accentInk: Color(0xFF0B7C56),
                heroA: Color(0xFF0A6E4D),
                heroB: Color(0xFF0C8058),
                heroVeil: Color(0x1AFFFFFF),
                heroTrack: Color(0x47FFFFFF),
                codeBg: Color(0xFFF1ECE2),
              )
            : const ThemePalette(
                seed: Color(0xFF34D399),
                background: Color(0xFF161512),
                surface: Color(0xFF201E1A),
                surfaceDim: Color(0xFF2A2823),
                raised: Color(0xFF26241F),
                stage: Color(0xFF0C0B09),
                ink: Color(0xFFF4F0E7),
                ink2: Color(0xFFA9A499),
                text3: Color(0xFF736F66),
                primary: Color(0xFF34D399),
                onPrimary: Color(0xFF0C0B09),
                accentSoft: Color(0x2934D399),
                accentInk: Color(0xFF6EE7B7),
                heroA: Color(0xFF34D399),
                heroB: Color(0xFF6EE7B7),
                heroVeil: Color(0x1A0C0B09),
                heroTrack: Color(0x3D0C0B09),
                codeBg: Color(0xFF15140F),
              ),
      AppColorTheme.ocean =>
        light
            ? const ThemePalette(
                seed: Color(0xFF096B8A),
                background: Color(0xFFF8EFE3),
                surface: Color(0xFFFFFFFF),
                surfaceDim: Color(0xFFFCF7F1),
                raised: Color(0xFFFFFFFF),
                stage: Color(0xFFE9E1D5),
                ink: Color(0xFF15252B),
                ink2: Color(0xFF61737A),
                text3: Color(0xFF8B9CA2),
                primary: Color(0xFF096B8A),
                onPrimary: Color(0xFFFFFFFF),
                accentSoft: Color(0x1F096B8A),
                accentInk: Color(0xFF096B8A),
                heroA: Color(0xFF075A75),
                heroB: Color(0xFF087A98),
                heroVeil: Color(0x1AFFFFFF),
                heroTrack: Color(0x47FFFFFF),
                codeBg: Color(0xFFF3EADE),
              )
            : const ThemePalette(
                seed: Color(0xFF67D5EE),
                background: Color(0xFF161412),
                surface: Color(0xFF211E1A),
                surfaceDim: Color(0xFF2C2722),
                raised: Color(0xFF27231F),
                stage: Color(0xFF0C0A09),
                ink: Color(0xFFE7F4F7),
                ink2: Color(0xFFA9C1C8),
                text3: Color(0xFF718B92),
                primary: Color(0xFF67D5EE),
                onPrimary: Color(0xFF082027),
                accentSoft: Color(0x2967D5EE),
                accentInk: Color(0xFF9BE7F5),
                heroA: Color(0xFF117A92),
                heroB: Color(0xFF67D5EE),
                heroVeil: Color(0x1A0C0A09),
                heroTrack: Color(0x3D0C0A09),
                codeBg: Color(0xFF141210),
              ),
      AppColorTheme.indigo =>
        light
            ? const ThemePalette(
                seed: Color(0xFF6750E7),
                background: Color(0xFFF5EEF2),
                surface: Color(0xFFFFFFFF),
                surfaceDim: Color(0xFFFAF6F8),
                raised: Color(0xFFFFFFFF),
                stage: Color(0xFFE6E0E3),
                ink: Color(0xFF211B36),
                ink2: Color(0xFF5B5570),
                text3: Color(0xFF8B84A3),
                primary: Color(0xFF6750E7),
                secondary: Color(0xFF6750E7),
                onPrimary: Color(0xFFFFFFFF),
                accentSoft: Color(0xFFEAE5FC),
                accentInk: Color(0xFF6750E7),
                heroA: Color(0xFF5B48D0),
                heroB: Color(0xFF8D7BF5),
                heroVeil: Color(0x1AFFFFFF),
                heroTrack: Color(0x47FFFFFF),
                codeBg: Color(0xFFF0E9ED),
              )
            : const ThemePalette(
                seed: Color(0xFF6750E7),
                background: Color(0xFF161214),
                surface: Color(0xFF201B1E),
                surfaceDim: Color(0xFF2B2427),
                raised: Color(0xFF262023),
                stage: Color(0xFF0B0A0A),
                ink: Color(0xFFECE9F7),
                ink2: Color(0xFFABA5C4),
                text3: Color(0xFF726C8C),
                primary: Color(0xFF8D7BF5),
                secondary: Color(0xFF8D7BF5),
                onPrimary: Color(0xFF14121F),
                accentSoft: Color(0xFF2B2450),
                accentInk: Color(0xFF8D7BF5),
                heroA: Color(0xFF6D5FE0),
                heroB: Color(0xFF8D7BF5),
                heroVeil: Color(0x1A0B0A0A),
                heroTrack: Color(0x3D0B0A0A),
                codeBg: Color(0xFF131012),
              ),
      AppColorTheme.plum =>
        light
            ? const ThemePalette(
                seed: Color(0xFF8B3F8F),
                background: Color(0xFFF0F2E6),
                surface: Color(0xFFFFFFFF),
                surfaceDim: Color(0xFFF8F8F2),
                raised: Color(0xFFFFFFFF),
                stage: Color(0xFFE2E3D8),
                ink: Color(0xFF30202F),
                ink2: Color(0xFF786779),
                text3: Color(0xFFA18EA2),
                primary: Color(0xFF8B3F8F),
                onPrimary: Color(0xFFFFFFFF),
                accentSoft: Color(0x1F8B3F8F),
                accentInk: Color(0xFF7B327E),
                heroA: Color(0xFF733078),
                heroB: Color(0xFF974B9B),
                heroVeil: Color(0x1AFFFFFF),
                heroTrack: Color(0x47FFFFFF),
                codeBg: Color(0xFFEBEDE1),
              )
            : const ThemePalette(
                seed: Color(0xFFE9A8ED),
                background: Color(0xFF151512),
                surface: Color(0xFF1F201B),
                surfaceDim: Color(0xFF292A24),
                raised: Color(0xFF242620),
                stage: Color(0xFF0B0B0A),
                ink: Color(0xFFF9EFF9),
                ink2: Color(0xFFCAB5CA),
                text3: Color(0xFF907A91),
                primary: Color(0xFFE9A8ED),
                onPrimary: Color(0xFF351338),
                accentSoft: Color(0x29E9A8ED),
                accentInk: Color(0xFFF2C5F4),
                heroA: Color(0xFFAC67B1),
                heroB: Color(0xFFE9A8ED),
                heroVeil: Color(0x1A0B0B0A),
                heroTrack: Color(0x3D0B0B0A),
                codeBg: Color(0xFF131310),
              ),
    };
  }
}

/// The page background in light mode (Settings → Appearance → Background).
///
/// Each colour theme has a background chosen to pair with its accent the way
/// Forest's cream pairs with its green — a soft paper from a different colour
/// family than the accent, clearly darker than the white cards. That's
/// [recommended]; the others are the same for every theme. Dark mode has no
/// choice: each theme's dark background is fixed.
enum AppBackground {
  recommended('recommended', 'Recommended'),
  cream('cream', 'Cream'),
  stone('stone', 'Stone'),
  softWhite('soft_white', 'Soft white');

  const AppBackground(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AppBackground fromStorage(String? value) => values.firstWhere(
    (b) => b.storageValue == value,
    orElse: () => AppBackground.recommended,
  );
}

extension AppColorThemeBackgrounds on AppColorTheme {
  static const _cream = Color(0xFFF5F1E9);
  static const _stone = Color(0xFFEFEDE8);

  /// The backgrounds offered for this theme. Forest's recommended background
  /// *is* cream, so it's listed once.
  List<AppBackground> get backgrounds => this == AppColorTheme.forest
      ? const [
          AppBackground.cream,
          AppBackground.stone,
          AppBackground.softWhite,
        ]
      : AppBackground.values;

  /// [background] as this theme lists it: Forest shows "Recommended" as
  /// Cream.
  AppBackground shown(AppBackground background) =>
      this == AppColorTheme.forest && background == AppBackground.recommended
      ? AppBackground.cream
      : background;

  /// What to save when [background] is picked under this theme. Picking
  /// Forest's Cream saves "recommended", so moving to another theme later
  /// still gets that theme's own pairing rather than cream everywhere.
  AppBackground saved(AppBackground background) =>
      this == AppColorTheme.forest && background == AppBackground.cream
      ? AppBackground.recommended
      : background;

  /// The light-mode page colour for [background] under this theme.
  Color lightBackground(AppBackground background) => switch (background) {
    AppBackground.recommended => forBrightness(Brightness.light).background,
    AppBackground.cream => _cream,
    AppBackground.stone => _stone,
    // A near-white with a breath of the theme's own colour.
    AppBackground.softWhite => switch (this) {
      AppColorTheme.forest => const Color(0xFFFBF9F5),
      AppColorTheme.oledMidnight => const Color(0xFFF3F8F8),
      AppColorTheme.ocean => const Color(0xFFF3F8FA),
      AppColorTheme.indigo => const Color(0xFFF3F1FA),
      AppColorTheme.plum => const Color(0xFFFCF6FC),
    },
  };

  /// This theme's palette for [brightness], on [background] in light mode.
  ThemePalette paletteFor(Brightness brightness, AppBackground background) {
    final palette = forBrightness(brightness);
    if (brightness == Brightness.dark) return palette;
    final color = lightBackground(background);
    return color == palette.background
        ? palette
        : palette.withBackground(color);
  }
}

AppColorTheme appColorThemeFromStorage(String value) =>
    AppColorTheme.values.firstWhere(
      (theme) => theme.storageValue == value,
      orElse: () => AppColorTheme.forest,
    );

class ThemePalette {
  const ThemePalette({
    required this.seed,
    required this.background,
    required this.surface,
    required this.surfaceDim,
    required this.raised,
    required this.stage,
    required this.ink,
    required this.ink2,
    required this.text3,
    required this.primary,
    this.secondary,
    required this.onPrimary,
    required this.accentSoft,
    required this.accentInk,
    required this.heroA,
    required this.heroB,
    required this.heroVeil,
    required this.heroTrack,
    required this.codeBg,
  });

  final Color seed;
  final Color background;
  final Color surface;
  final Color surfaceDim;
  final Color raised;
  final Color stage;
  final Color ink;
  final Color ink2;
  final Color text3;
  final Color primary;
  final Color? secondary;
  final Color onPrimary;
  final Color accentSoft;
  final Color accentInk;
  final Color heroA;
  final Color heroB;
  final Color heroVeil;
  final Color heroTrack;
  final Color codeBg;

  /// This palette on a different page [background]. The shades that sit
  /// around it follow, in the proportions Forest's keep to its cream: the
  /// dimmed surface halfway to white, the stage a step darker, the code
  /// block a touch darker.
  ThemePalette withBackground(Color background) {
    Color scaled(double factor) => Color.from(
      alpha: 1,
      red: background.r * factor,
      green: background.g * factor,
      blue: background.b * factor,
    );
    return ThemePalette(
      seed: seed,
      background: background,
      surface: surface,
      surfaceDim: Color.lerp(background, const Color(0xFFFFFFFF), 0.5)!,
      raised: raised,
      stage: scaled(0.94),
      ink: ink,
      ink2: ink2,
      text3: text3,
      primary: primary,
      secondary: secondary,
      onPrimary: onPrimary,
      accentSoft: accentSoft,
      accentInk: accentInk,
      heroA: heroA,
      heroB: heroB,
      heroVeil: heroVeil,
      heroTrack: heroTrack,
      codeBg: scaled(0.98),
    );
  }
}
