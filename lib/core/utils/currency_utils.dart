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
