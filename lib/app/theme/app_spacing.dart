/// Consistent spacing scale used across all feature screens.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ---- radii, from the design comp's own scale ----
  // The comp works in a tight band of radii rather than one value: content
  // cards at 22, compact tiles/stat pills at 16, inputs and primary buttons at
  // 15, icon buttons at 13, the floating nav pill at 24, sheets at 30.

  /// Main content cards. Kit: cards 22.
  static const double cardRadius = 22;

  /// Bottom sheets, top corners only (comp: `border-radius:30px 30px 0 0`).
  static const double sheetRadius = 30;

  /// Inputs and list rows. Kit: 16. Nested corners step down by 4 — a 16 row
  /// holds a 12 chip holds an 8 swatch.
  static const double tileRadius = 16;

  /// Chips and small tiles. Kit: 12.
  static const double chipRadius = 12;

  /// Swatches and dots. Kit: 8.
  static const double swatchRadius = 8;

  /// Text fields and list rows. Kit: 16 (was 15 from the older prototype).
  static const double controlRadius = 16;

  /// Primary CTA. Kit §4 Buttons: 48px tall, radius 14.
  static const double primaryButtonRadius = 14;
  static const double primaryButtonHeight = 48;

  /// The kit's button size ladder: 48 default, 40 medium, 32 small.
  static const double buttonHeightMedium = 40;
  static const double buttonHeightSmall = 32;

  /// Minimum touch target, regardless of the visual size. Kit §6 rule 1.
  static const double minTouchTarget = 44;

  /// FAB: 56px, radius 19.
  static const double fabSize = 56;
  static const double fabRadius = 19;

  /// Square icon buttons (comp: `border-radius:13px`).
  static const double iconButtonRadius = 13;

  /// The floating bottom-nav pill (comp: `border-radius:24px`).
  static const double navRadius = 24;

  /// Fully rounded — chips and legend dots.
  static const double pillRadius = 999;

  /// Field control height. Kit §4 Fields: 48px control inside a 50px box.
  static const double controlHeight = 48;
}
