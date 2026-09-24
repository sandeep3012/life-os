import '../../../core/database/app_database.dart';

/// One slice of the month's expense donut.
///
/// [category] is null for spend that carries no category — a bill or recurring
/// transaction saved without one, most often. That spend used to be dropped
/// from the breakdown entirely, which both hid it and skewed every other
/// slice's share, since the shares were divided by a total it wasn't in.
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.totalMinor,
    required this.share,
  });

  final Category? category;

  /// Matches what the Reports screen calls it.
  String get label => category?.name ?? 'Uncategorized';

  bool get isUncategorized => category == null;
  final int totalMinor;

  /// 0..1 of this category's spend against the month's total.
  final double share;
}
