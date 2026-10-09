import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/ai_analyser/domain/insight_digest.dart';

Insight insight(
  String title,
  DateTime generatedAt, {
  String severity = 'info',
  bool dismissed = false,
}) => Insight(
  id: title,
  type: 'test',
  severity: severity,
  title: title,
  generatedAt: generatedAt,
  dismissed: dismissed,
);

/// "AI insight alerts": one note at 9 AM about what's new since the last one.
void main() {
  test('before 9 the note is this morning, after 9 tomorrow morning', () {
    final early = DateTime(2026, 10, 9, 7);
    final late = DateTime(2026, 10, 9, 15);
    final found = [insight('Dining over budget', DateTime(2026, 10, 9, 6))];

    expect(
      InsightDigest.compose(found, now: early)!.at,
      DateTime(2026, 10, 9, 9),
    );
    expect(
      InsightDigest.compose([
        insight('Dining over budget', DateTime(2026, 10, 9, 14)),
      ], now: late)!.at,
      DateTime(2026, 10, 10, 9),
    );
  });

  test("an insight already in this morning's note isn't announced again", () {
    // Found at 8 AM, so it went out at 9 AM; at 3 PM it's old news.
    final digest = InsightDigest.compose([
      insight('Dining over budget', DateTime(2026, 10, 9, 8)),
    ], now: DateTime(2026, 10, 9, 15));
    expect(digest, isNull);
  });

  test('several new ones lead with the most pressing', () {
    final now = DateTime(2026, 10, 9, 20);
    final digest = InsightDigest.compose([
      insight('Reading streak at risk', DateTime(2026, 10, 9, 19)),
      insight(
        'Dining is 120% of budget',
        DateTime(2026, 10, 9, 18),
        severity: 'critical',
      ),
      insight('Old one', DateTime(2026, 10, 8, 18)),
    ], now: now)!;

    expect(digest.title, '2 things worth knowing');
    expect(digest.body, 'Dining is 120% of budget — and 1 more in LifeOS.');
  });

  test('one new insight reads as itself', () {
    final digest = InsightDigest.compose([
      insight('Rent is due tomorrow', DateTime(2026, 10, 9, 19)),
    ], now: DateTime(2026, 10, 9, 20))!;
    expect(digest.title, 'Worth knowing');
    expect(digest.body, 'Rent is due tomorrow');
  });

  test('dismissed insights and empty days send nothing', () {
    final now = DateTime(2026, 10, 9, 20);
    expect(InsightDigest.compose(const [], now: now), isNull);
    expect(
      InsightDigest.compose([
        insight('Hidden', DateTime(2026, 10, 9, 19), dismissed: true),
      ], now: now),
      isNull,
    );
  });
}
