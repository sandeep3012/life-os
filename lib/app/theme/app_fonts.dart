import 'dart:ui' show FontFeature;

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

  /// Headings, hero numbers, section titles. Comp: `font-family:'Newsreader',serif`.
  static const serif = 'Newsreader';

  /// Body, labels, buttons, nav. Comp: `font-family:'Manrope',system-ui,sans-serif`.
  static const sans = 'Manrope';

  /// Currency figures, dates, counts. Same family as [sans] — pair with [tabular].
  static const numeric = sans;

  /// IDs, file names and code blocks — and nothing else. Kit §2 reserves a
  /// monospace face for these; numbers stay in [numeric] with tabular figures so
  /// they match surrounding body text.
  static const mono = 'JetBrainsMono';

  /// Fixed-advance digits, so figures in a column line up.
  /// Comp equivalent: `font-variant-numeric:tabular-nums`.
  static const tabular = <FontFeature>[FontFeature.tabularFigures()];
}
