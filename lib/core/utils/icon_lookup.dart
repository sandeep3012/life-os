import 'package:flutter/material.dart';

/// Maps the icon-name strings stored on [Category.icon] / [AccountType.icon]
/// to a concrete [IconData] — the curated set offered by [pickableIcons], so
/// every name a category/account-type picker can produce resolves here.
/// Falls back to a generic label icon for anything unrecognized (e.g. an
/// icon name from a future app version, or a row restored from an older
/// backup whose icon set has since changed).
const Map<String, IconData> _iconsByName = {
  'label': Icons.label_rounded,
  'category': Icons.category_rounded,
  'restaurant': Icons.restaurant_rounded,
  'shopping_cart': Icons.shopping_cart_rounded,
  'directions_car': Icons.directions_car_rounded,
  'home': Icons.home_rounded,
  'movie': Icons.movie_rounded,
  'autorenew': Icons.autorenew_rounded,
  'payments': Icons.payments_rounded,
  'local_grocery_store': Icons.local_grocery_store_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  'school': Icons.school_rounded,
  'flight': Icons.flight_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'pets': Icons.pets_rounded,
  'checkroom': Icons.checkroom_rounded,
  'sports_esports': Icons.sports_esports_rounded,
  'card_giftcard': Icons.card_giftcard_rounded,
  'build': Icons.build_rounded,
  'wifi': Icons.wifi_rounded,
  'account_balance_wallet': Icons.account_balance_wallet_rounded,
  'savings': Icons.savings_rounded,
  'credit_card': Icons.credit_card_rounded,
  'trending_up': Icons.trending_up_rounded,
  'account_balance': Icons.account_balance_rounded,
};

/// Curated icon choices offered when creating/editing a category or account
/// type — every key here must have an entry in [_iconsByName].
const pickableIcons = [
  'label',
  'category',
  'restaurant',
  'shopping_cart',
  'local_grocery_store',
  'directions_car',
  'home',
  'movie',
  'autorenew',
  'payments',
  'local_hospital',
  'school',
  'flight',
  'fitness_center',
  'pets',
  'checkroom',
  'sports_esports',
  'card_giftcard',
  'build',
  'wifi',
  'account_balance_wallet',
  'savings',
  'credit_card',
  'trending_up',
  'account_balance',
];

IconData resolveIcon(String? name) => _iconsByName[name] ?? Icons.label_rounded;
