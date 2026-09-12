import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Maps the icon-name strings stored on [Category.icon] / [AccountType.icon]
/// to a concrete [IconData] — the curated set offered by [pickableIcons], so
/// every name a category/account-type picker can produce resolves here.
/// Falls back to a generic label icon for anything unrecognized (e.g. an
/// icon name from a future app version, or a row restored from an older
/// backup whose icon set has since changed).
const Map<String, IconData> _iconsByName = {
  'label': LucideIcons.tag,
  'category': LucideIcons.shapes,
  'restaurant': LucideIcons.utensils,
  'shopping_cart': LucideIcons.shoppingCart,
  'directions_car': LucideIcons.car,
  'home': LucideIcons.house,
  'movie': LucideIcons.clapperboard,
  'autorenew': LucideIcons.refreshCw,
  'payments': LucideIcons.banknote,
  'local_grocery_store': LucideIcons.shoppingCart,
  'local_hospital': LucideIcons.cross,
  'school': LucideIcons.school,
  'flight': LucideIcons.plane,
  'fitness_center': LucideIcons.dumbbell,
  'pets': LucideIcons.pawPrint,
  'checkroom': LucideIcons.shirt,
  'sports_esports': LucideIcons.gamepad2,
  'card_giftcard': LucideIcons.gift,
  'build': LucideIcons.wrench,
  'wifi': LucideIcons.wifi,
  'account_balance_wallet': LucideIcons.wallet,
  'savings': LucideIcons.piggyBank,
  'credit_card': LucideIcons.creditCard,
  'trending_up': LucideIcons.trendingUp,
  'account_balance': LucideIcons.landmark,
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

/// A curated set of Unicode choices that can be stored alongside Material
/// icon names. Unicode strings are rendered as text by [IconOrEmoji].
const pickableEmojis = ['🍽️', '🛒', '🚗', '🏠', '🎬', '💳', '🏥', '🎓', '✈️', '🏋️', '🐾', '👕', '🎮', '🎁', '🔧', '📶', '👛', '💰', '🏦', '☕', '🎵', '📚', '❤️', '⭐'];

IconData resolveIcon(String? name) => _iconsByName[name] ?? LucideIcons.tag;

bool isEmojiIcon(String? value) => value != null && !_iconsByName.containsKey(value);

class IconOrEmoji extends StatelessWidget {
  const IconOrEmoji({super.key, required this.value, this.size = 20, this.color});
  final String? value;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => isEmojiIcon(value)
      ? Text(value!, style: TextStyle(fontSize: size, color: color))
      : Icon(resolveIcon(value), size: size, color: color);
}
