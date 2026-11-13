import 'dart:ui' show FontFeature;

import 'app_font_style.dart';

/// Font families and numeric styling from the design comp, as named constants
/// rather than string literals scattered through widget code.
///
/// The comp uses exactly two families — Newsreader for headings, hero numbers
/// and card titles; Manrope for everything else — and gets tabular figures by
/// applying `font-variant-numeric:tabular-nums` to Manrope rather than by
/// switching to a separate monospace family. [numeric] therefore points at
/// Manrope too, and callers pair it with [tabular]; that combination is what
/// replaces the previous design's dedicated Plex Mono role.
class AppFonts {
  AppFonts._();

  static AppFontStyle _style = AppFontStyle.classic;

  /// The font look in use (Settings → Appearance → Font).
  static AppFontStyle get style => _style;

  /// Switches the look. Text picks it up the next time its widget builds, so
  /// the caller rebuilds the tree — see `LifeOSApp`.
  static void use(AppFontStyle style) => _style = style;

  /// Headings, hero numbers, section titles. Comp:
  /// `font-family:'Newsreader',serif` — or the chosen look's heading family.
  ///
  /// A getter, not a constant: it changes with the setting, so a `TextStyle`
  /// that names it can't be `const`.
  static String get serif => _style.headingFamily;

  /// Body, labels, buttons, nav. Comp:
  /// `font-family:'Manrope',system-ui,sans-serif` — or the chosen look's
  /// body family.
  static String get sans => _style.bodyFamily;

  /// Currency figures, dates, counts. Same family as [sans] — pair with [tabular].
  static String get numeric => sans;

  /// IDs, file names and code blocks — and nothing else. Kit §2 reserves a
  /// monospace face for these; numbers stay in [numeric] with tabular figures so
  /// they match surrounding body text.
  static const mono = 'JetBrainsMono';

  /// Fixed-advance digits, so figures in a column line up.
  /// Comp equivalent: `font-variant-numeric:tabular-nums`.
  static const tabular = <FontFeature>[FontFeature.tabularFigures()];
}
