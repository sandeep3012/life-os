import 'package:flutter/painting.dart';

/// What `Category.colorHex` holds when the user picked "No color".
///
/// A blank string rather than a nullable column: the column is `NOT NULL` and
/// every backup, import and demo-data row already round-trips it as text, so a
/// sentinel needs no schema migration. Anything that renders a category must
/// read the colour through [categoryColor], never `int.parse` it directly — a
/// blank string throws.
const noCategoryColorHex = '';

/// The colour [hex] encodes, or `null` for "No color" (blank) or a value that
/// isn't a hex colour. Callers pick their own neutral for `null`, since the
/// right one differs by surface (a habit ring, a transaction well, a chart).
Color? categoryColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final value = int.tryParse(hex.replaceFirst('#', '0xFF'));
  return value == null ? null : Color(value);
}
