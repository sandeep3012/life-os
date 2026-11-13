import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/spend_analyzer/domain/category_spend.dart';
import 'package:life_manager/features/spend_analyzer/domain/donut_slice_colors.dart';

void main() {
  final when = DateTime(2026, 11, 1);

  CategorySpend slice(String? name, [String colorHex = '']) => CategorySpend(
    category: name == null
        ? null
        : Category(
            id: name,
            name: name,
            icon: 'category',
            colorHex: colorHex,
            kind: 'expense',
            position: 0,
            createdAt: when,
          ),
    totalMinor: 1000,
    share: 0.2,
  );

  test('grey, black, colourless and uncategorised slices turn colourful', () {
    final colors = donutSliceColors([
      slice('Dining', '#E0475A'),
      slice('Groceries', '#2E9E63'),
      slice('Other', '#8B84A3'), // the grey "Other" ships with
      slice('Black', '#111111'),
      slice('No color'),
      slice(null), // Uncategorized
    ]);

    expect(colors[0], const Color(0xFFE0475A), reason: 'a real colour stays');
    expect(colors[1], const Color(0xFF2E9E63));
    for (final color in colors) {
      expect(isColorful(color), isTrue, reason: '$color');
    }
    expect(colors.toSet(), hasLength(colors.length), reason: 'all distinct');
  });

  test('the same breakdown always gets the same colours', () {
    final breakdown = [slice('Rent', '#A67C00'), slice('Other', '#8B84A3')];
    expect(donutSliceColors(breakdown), donutSliceColors(breakdown));
  });

  test('a replacement keeps clear of the colours already in the ring', () {
    final colors = donutSliceColors([
      slice('Dining', '#E0475A'), // red
      slice('Other', '#8B84A3'),
    ]);
    final gap =
        (HSLColor.fromColor(colors[0]).hue - HSLColor.fromColor(colors[1]).hue)
            .abs();
    expect(gap > 60 && gap < 300, isTrue, reason: 'not another red');
  });
}
