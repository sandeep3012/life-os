import 'package:intl/intl.dart';

/// Formats an amount stored in minor units (paise) as an Indian-grouped
/// rupee string (e.g. 14238050 -> "₹1,42,380.50"), matching the prototype.
String formatMinor(int minor, {bool showDecimals = true, bool showSign = false}) {
  final rupees = minor / 100;
  final format = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: showDecimals ? 2 : 0,
  );
  final formatted = format.format(rupees.abs());
  if (!showSign) return minor < 0 ? '-$formatted' : formatted;
  return minor < 0 ? '-$formatted' : '+$formatted';
}
