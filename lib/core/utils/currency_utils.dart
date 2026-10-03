import 'package:intl/intl.dart';

class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.locale,
    required this.label,
  });

  final String code;
  final String symbol;
  final String locale;
  final String label;
}

/// Curated list, not a full ISO-4217 picker — matches this app's existing
/// bias toward small curated lists (e.g. the finance icon picker) over
/// exhaustive ones.
const supportedCurrencies = [
  CurrencyOption(code: 'INR', symbol: '₹', locale: 'en_IN', label: 'Indian Rupee'),
  CurrencyOption(code: 'USD', symbol: '\$', locale: 'en_US', label: 'US Dollar'),
  CurrencyOption(code: 'EUR', symbol: '€', locale: 'en_IE', label: 'Euro'),
  CurrencyOption(code: 'GBP', symbol: '£', locale: 'en_GB', label: 'British Pound'),
  CurrencyOption(code: 'JPY', symbol: '¥', locale: 'ja_JP', label: 'Japanese Yen'),
  CurrencyOption(code: 'AUD', symbol: '\$', locale: 'en_AU', label: 'Australian Dollar'),
];

CurrencyOption _optionFor(String code) {
  return supportedCurrencies.firstWhere(
    (c) => c.code == code,
    orElse: () => supportedCurrencies.first,
  );
}

String currencySymbolFor(String code) => _optionFor(code).symbol;

/// Formats an amount stored in minor units (e.g. paise, cents) as a
/// currency-grouped string for [currencyCode] (e.g. 14238050 with 'INR' ->
/// "₹1,42,380.50").
/// Stand-in for a hidden amount: the currency symbol, then six dots.
///
/// The symbol stays so a masked balance still reads as money, and the fixed
/// width means toggling visibility doesn't reflow the row around it.
String maskedAmount(String currencyCode) => '${currencySymbolFor(currencyCode)} ••••••';

/// [formatMinor], or [maskedAmount] when the user has hidden balances.
String formatMinorMasked(
  int minor, {
  required String currencyCode,
  required bool visible,
  bool showDecimals = true,
  bool showSign = false,
}) => visible
    ? formatMinor(minor, currencyCode: currencyCode, showDecimals: showDecimals, showSign: showSign)
    : maskedAmount(currencyCode);

String formatMinor(
  int minor, {
  required String currencyCode,
  bool showDecimals = true,
  bool showSign = false,
}) {
  final option = _optionFor(currencyCode);
  final major = minor / 100;
  final format = NumberFormat.currency(
    locale: option.locale,
    symbol: option.symbol,
    decimalDigits: showDecimals ? 2 : 0,
  );
  final formatted = format.format(major.abs());
  if (!showSign) return minor < 0 ? '-$formatted' : formatted;
  return minor < 0 ? '-$formatted' : '+$formatted';
}

/// A short form of [minor] for tight spots like chart labels: ₹850, ₹47k,
/// ₹1.1L. INR counts in lakh and crore, the way it is spoken and written there
/// (₹1,09,135 is "₹1.1L", not "₹109k"); other currencies use k, M and B.
///
/// A value of 10 or more in its unit drops the decimal (₹47k); a smaller one
/// keeps one when it matters (₹1.5k). A value that rounds up to the next unit
/// moves into it, so ₹99,950 reads "₹1L" rather than "₹100k". The sign is
/// dropped: this is for totals.
String formatCompactMinor(int minor, {required String currencyCode}) {
  final symbol = currencySymbolFor(currencyCode);
  final major = minor.abs() / 100;

  // Ascending: (size of one unit, its suffix).
  final ladder = currencyCode == 'INR'
      ? const [(1000.0, 'k'), (100000.0, 'L'), (10000000.0, 'Cr')]
      : const [(1000.0, 'k'), (1000000.0, 'M'), (1000000000.0, 'B')];

  double round(double v) =>
      v >= 10 ? v.roundToDouble() : (v * 10).roundToDouble() / 10;
  String text(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // Whole currency units below 1,000 (unless 999.6 rounds up to 1,000).
  if (major.round() < 1000) return '$symbol${major.round()}';

  var i = 0;
  while (i + 1 < ladder.length && major >= ladder[i + 1].$1) {
    i++;
  }
  var value = round(major / ladder[i].$1);
  // Rounding can land exactly on the next unit: 99.95k -> 100k is really 1L.
  if (i + 1 < ladder.length && value * ladder[i].$1 >= ladder[i + 1].$1) {
    i++;
    value = round(major / ladder[i].$1);
  }
  return '$symbol${text(value)}${ladder[i].$2}';
}
