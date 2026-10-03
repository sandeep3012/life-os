import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/utils/currency_utils.dart';

/// Short amounts for chart labels. Minor units in, so ₹47,000 is 4,700,000.
void main() {
  String inr(int rupees) =>
      formatCompactMinor(rupees * 100, currencyCode: 'INR');

  test('under a thousand is written out', () {
    expect(inr(0), '₹0');
    expect(inr(850), '₹850');
    expect(inr(999), '₹999');
  });

  test('thousands use k, with a decimal only when it is under ten', () {
    expect(inr(1000), '₹1k');
    expect(inr(1500), '₹1.5k');
    expect(inr(9500), '₹9.5k');
    expect(inr(47000), '₹47k');
    expect(inr(47300), '₹47k');
    expect(inr(52000), '₹52k');
  });

  test('INR counts in lakh and crore', () {
    expect(inr(100000), '₹1L');
    expect(inr(109135), '₹1.1L');
    expect(inr(1240000), '₹12L');
    expect(inr(10000000), '₹1Cr');
    expect(inr(25000000), '₹2.5Cr');
  });

  test('a value that rounds up into the next unit moves into it', () {
    expect(inr(99950), '₹1L');
    expect(inr(9999500), '₹1Cr');
    // 999.6 rounds to 1000.
    expect(formatCompactMinor(99960, currencyCode: 'INR'), '₹1k');
  });

  test('other currencies use k, M and B', () {
    String usd(int dollars) =>
        formatCompactMinor(dollars * 100, currencyCode: 'USD');
    expect(usd(47000), '\$47k');
    expect(usd(109135), '\$109k');
    expect(usd(1250000), '\$1.3M');
    expect(usd(2000000000), '\$2B');
  });

  test('the sign is dropped', () {
    expect(formatCompactMinor(-4700000, currencyCode: 'INR'), '₹47k');
  });
}
