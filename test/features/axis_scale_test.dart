import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/spend_analyzer/domain/axis_scale.dart';

void main() {
  test('rounds the top up to a round step', () {
    final s = niceAxisScale(lowest: 0, highest: 47000);

    expect(s.min, 0);
    expect(s.step, 20000);
    expect(s.max, 60000);
    expect(s.ticks, [0, 20000, 40000, 60000]);
  });

  test('a small spread keeps a sensible step', () {
    final s = niceAxisScale(lowest: 0, highest: 850);

    expect(s.step, 250);
    expect(s.max, 1000);
  });

  test('lakhs: ₹1,09,135 gets round lakh-ish steps', () {
    final s = niceAxisScale(lowest: 0, highest: 109135);

    expect(s.step, 50000);
    expect(s.max, 150000);
  });

  test('negative values extend the axis below zero', () {
    final s = niceAxisScale(lowest: -12000, highest: 109000);

    expect(s.min, lessThan(0));
    expect(s.min % s.step, 0);
    expect(s.ticks, contains(0));
    expect(s.min, lessThanOrEqualTo(-12000));
  });

  test('no negatives means it starts at zero', () {
    expect(niceAxisScale(lowest: 500, highest: 9000).min, 0);
  });

  test('all zero still gives a usable axis', () {
    final s = niceAxisScale(lowest: 0, highest: 0);

    expect(s.max, greaterThan(0));
    expect(s.span, greaterThan(0));
    expect(s.ticks.length, greaterThan(1));
  });

  test('every tick is a multiple of the step', () {
    for (final high in [137.0, 4800.0, 52000.0, 109135.0, 4500000.0]) {
      final s = niceAxisScale(lowest: 0, highest: high);
      expect(s.max, greaterThanOrEqualTo(high));
      for (final t in s.ticks) {
        expect((t / s.step) % 1, closeTo(0, 1e-9));
      }
    }
  });
}
