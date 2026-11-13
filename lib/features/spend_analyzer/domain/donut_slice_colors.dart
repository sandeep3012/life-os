import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import '../../../core/utils/category_color.dart';
import 'category_spend.dart';

/// Bright hues for donut slices that have no colour of their own to show.
const _vivid = [
  Color(0xFF14B8A6), // teal
  Color(0xFFF59E0B), // amber
  Color(0xFF0EA5E9), // sky
  Color(0xFFEC4899), // pink
  Color(0xFF8B5CF6), // violet
  Color(0xFF84CC16), // lime
  Color(0xFFF97316), // orange
  Color(0xFF6366F1), // indigo
  Color(0xFFF43F5E), // rose
  Color(0xFF06B6D4), // cyan
];

/// Whether [color] reads as a colour on a chart, rather than as grey, near
/// black or near white.
bool isColorful(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.saturation >= 0.30 &&
      hsl.lightness >= 0.25 &&
      hsl.lightness <= 0.85;
}

/// One colour per slice of the spend donut, in [breakdown]'s order.
///
/// A category keeps its own colour when that colour is one — but "Other"
/// ships grey, spend with no category has none, and a category can be left
/// on "No color" or given a grey or black. Those slices each get a bright
/// hue instead, picked to sit as far as possible from every colour already
/// in the ring, so the donut is never part grey and no two slices look
/// alike when it can be helped.
List<Color> donutSliceColors(List<CategorySpend> breakdown) {
  final own = [
    for (final entry in breakdown) categoryColor(entry.category?.colorHex),
  ];
  final used = [
    for (final color in own)
      if (color != null && isColorful(color)) color,
  ];
  final result = <Color>[];
  for (final color in own) {
    if (color != null && isColorful(color)) {
      result.add(color);
      continue;
    }
    final pick = _farthestFrom(used);
    used.add(pick);
    result.add(pick);
  }
  return result;
}

Color _farthestFrom(List<Color> used) {
  if (used.isEmpty) return _vivid.first;
  var best = _vivid.first;
  var bestDistance = -1.0;
  for (final candidate in _vivid) {
    final hue = HSLColor.fromColor(candidate).hue;
    var nearest = 360.0;
    for (final other in used) {
      final d = (hue - HSLColor.fromColor(other).hue).abs();
      final around = d > 180 ? 360 - d : d;
      if (around < nearest) nearest = around;
    }
    if (nearest > bestDistance) {
      bestDistance = nearest;
      best = candidate;
    }
  }
  return best;
}
