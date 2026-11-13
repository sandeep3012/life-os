/// The font looks offered in Settings → Appearance → Font. Each is a pair:
/// a family for headings (`AppFonts.serif`) and one for body and UI text
/// (`AppFonts.sans`). All are bundled, so they work
/// offline.
enum AppFontStyle {
  /// The design's own pairing, and the default.
  classic(
    'classic',
    'Classic',
    'Bookish headings, crisp text',
    headingFamily: 'Newsreader',
    headingAsset: 'assets/fonts/Newsreader-Variable.ttf',
    bodyFamily: 'Manrope',
    bodyAsset: 'assets/fonts/Manrope-Variable.ttf',
  ),
  modern(
    'modern',
    'Modern',
    'Fresh and confident',
    headingFamily: 'PlusJakartaSans',
    headingAsset: 'assets/fonts/PlusJakartaSans-Variable.ttf',
    bodyFamily: 'PlusJakartaSans',
    bodyAsset: 'assets/fonts/PlusJakartaSans-Variable.ttf',
  ),
  clean(
    'clean',
    'Clean',
    'Neutral and very legible',
    headingFamily: 'Inter',
    headingAsset: 'assets/fonts/Inter-Variable.ttf',
    bodyFamily: 'Inter',
    bodyAsset: 'assets/fonts/Inter-Variable.ttf',
  ),
  friendly(
    'friendly',
    'Friendly',
    'Soft, rounded letters',
    headingFamily: 'Nunito',
    headingAsset: 'assets/fonts/Nunito-Variable.ttf',
    bodyFamily: 'Nunito',
    bodyAsset: 'assets/fonts/Nunito-Variable.ttf',
  ),
  elegant(
    'elegant',
    'Elegant',
    'High-contrast serif headings',
    headingFamily: 'PlayfairDisplay',
    headingAsset: 'assets/fonts/PlayfairDisplay-Variable.ttf',
    bodyFamily: 'DMSans',
    bodyAsset: 'assets/fonts/DMSans-Variable.ttf',
  ),
  geometric(
    'geometric',
    'Geometric',
    'Round, simple shapes',
    headingFamily: 'Outfit',
    headingAsset: 'assets/fonts/Outfit-Variable.ttf',
    bodyFamily: 'Outfit',
    bodyAsset: 'assets/fonts/Outfit-Variable.ttf',
  ),
  easyRead(
    'easy_read',
    'Easy read',
    'Wider letters, built for reading',
    headingFamily: 'Lexend',
    headingAsset: 'assets/fonts/Lexend-Variable.ttf',
    bodyFamily: 'Lexend',
    bodyAsset: 'assets/fonts/Lexend-Variable.ttf',
  );

  const AppFontStyle(
    this.storageValue,
    this.label,
    this.description, {
    required this.headingFamily,
    required this.headingAsset,
    required this.bodyFamily,
    required this.bodyAsset,
  });

  final String storageValue;
  final String label;
  final String description;

  /// The families as `pubspec.yaml` registers them. Text asks for
  /// `AppFonts.serif` / `AppFonts.sans`, which name the chosen style's.
  final String headingFamily;
  final String bodyFamily;
  final String headingAsset;
  final String bodyAsset;

  static AppFontStyle fromStorage(String? value) => values.firstWhere(
    (s) => s.storageValue == value,
    orElse: () => AppFontStyle.classic,
  );
}
