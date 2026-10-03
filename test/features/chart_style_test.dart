import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/features/spend_analyzer/presentation/widgets/chart_style.dart';

/// The guide lines have to be light but findable. They were once near-black
/// (withValues(alpha: 0.7) replaced outlineVariant's own faint alpha), and then
/// the plain outlineVariant (about 12%) was too faint to see.
void main() {
  for (final dark in [false, true]) {
    test(
      'the guide lines are light but visible in the ${dark ? 'dark' : 'light'} theme',
      () {
        final scheme = (dark ? AppTheme.dark() : AppTheme.light()).colorScheme;
        final alpha = chartGridColor(scheme).a;

        expect(alpha, lessThanOrEqualTo(0.3), reason: 'dark guide lines');
        expect(
          alpha,
          greaterThanOrEqualTo(0.15),
          reason: 'guide lines too faint to see',
        );
      },
    );
  }
}
