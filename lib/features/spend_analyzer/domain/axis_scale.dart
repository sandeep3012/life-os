import 'dart:math' as math;

/// A chart axis that starts at or below zero and rises in round steps.
class AxisScale {
  const AxisScale({required this.min, required this.max, required this.step});

  /// Never above zero: a chart with no negative values starts at 0.
  final double min;

  /// Never below one [step].
  final double max;
  final double step;

  double get span => max - min;

  /// Every gridline value from [min] to [max].
  List<double> get ticks => [
    for (var v = min; v <= max + step / 1000; v += step) v,
  ];
}

/// A tidy axis for data between [lowest] and [highest] (in major units — rupees,
/// not paise).
///
/// Picks a step of 1, 2, 2.5 or 5 times a power of ten that gives about four
/// intervals, and rounds the ends out to it, so the labels read ₹0, ₹10k, ₹20k
/// rather than ₹0, ₹9.7k, ₹19.4k. All-zero data still gets a usable axis.
AxisScale niceAxisScale({required double lowest, required double highest}) {
  final top = math.max(highest, 0);
  final bottom = math.min(lowest, 0);
  final range = top - bottom;
  if (range <= 0) return const AxisScale(min: 0, max: 1000, step: 250);

  final rough = range / 4;
  final magnitude = math
      .pow(10, (math.log(rough) / math.ln10).floor())
      .toDouble();
  final step = [
    1.0,
    2.0,
    2.5,
    5.0,
    10.0,
  ].map((m) => m * magnitude).firstWhere((s) => s >= rough);

  final max = math.max((top / step).ceil() * step, step);
  final min = (bottom / step).floor() * step;
  return AxisScale(min: min, max: max, step: step);
}
