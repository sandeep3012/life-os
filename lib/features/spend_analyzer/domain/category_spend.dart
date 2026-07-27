import '../../../core/database/app_database.dart';

class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.totalMinor,
    required this.share,
  });

  final Category category;
  final int totalMinor;

  /// 0..1 of this category's spend against the month's total.
  final double share;
}
