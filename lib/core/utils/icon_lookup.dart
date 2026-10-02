import 'package:flutter/foundation.dart';
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
/// icon names. Unicode strings are rendered as text by [IconOrEmoji], full
/// colour and expressive where the Lucide set above is deliberately flat and
/// single-tone — offered as a separate "Colorful icons" group in the picker,
/// never mixed into the plain [pickableIcons] one.
const pickableEmojis = [
  '🍽️',
  '🛒',
  '🚗',
  '🏠',
  '🎬',
  '💳',
  '🏥',
  '🎓',
  '✈️',
  '🏋️',
  '🐾',
  '👕',
  '🎮',
  '🎁',
  '🔧',
  '📶',
  '👛',
  '💰',
  '🏦',
  '☕',
  '🎵',
  '📚',
  '❤️',
  '⭐',
  '🔁',
  '🏷️',
  '🐷',
  '💵',
  '📈',
  '💧',
  '💪',
  '🏃',
  '🧘',
  '😴',
  '📓',
  '🚶',
  '⚖️',
  '🤸',
  '🏆',
  '💼',
  '💊',
  '👣',
  '📰',
  '🎥',
  '💡',
  '🪪',
  '🩺',
  '🧾',
  '🗂️',
  '🎂',
];

/// The icon a category carries when none was chosen — matches the `icon`
/// column's own default, and what [resolveIcon] falls back to.
const defaultCategoryIcon = 'label';

IconData resolveIcon(String? name) =>
    _iconsByName[name] ?? _iconsByName[defaultCategoryIcon]!;

/// Blank counts as "no icon", not as an emoji — a row imported from an older
/// backup can carry an empty string, which would otherwise render as nothing.
bool isEmojiIcon(String? value) =>
    value != null && value.isNotEmpty && !_iconsByName.containsKey(value);

/// An emoji, centred the way an [Icon] is.
///
/// A plain [Text] draws an emoji low and a touch left of centre. Fixing the
/// line box is not enough: pinning the height to 1 with even leading centres
/// the font's ascent and descent, but Apple Color Emoji draws its image low
/// and left inside that box regardless — measured on an iPhone, the image
/// centre sat ~0.8pt below and ~0.6pt left of a 20pt glyph's box centre while
/// Lucide icons sat at 0. So Apple platforms get a small optical shift,
/// proportional to [size]. Other platforms are left at the font's own
/// placement until they've been measured.
class EmojiGlyph extends StatelessWidget {
  const EmojiGlyph(this.emoji, {super.key, this.size = 20, this.color});

  final String emoji;
  final double size;
  final Color? color;

  static bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: _isApple ? Offset(size * 0.03, -size * 0.05) : Offset.zero,
    child: Text(
      emoji,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        color: color,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    ),
  );
}

class IconOrEmoji extends StatelessWidget {
  const IconOrEmoji({
    super.key,
    required this.value,
    this.size = 20,
    this.color,
  });
  final String? value;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => isEmojiIcon(value)
      ? EmojiGlyph(value!, size: size, color: color)
      : Icon(resolveIcon(value), size: size, color: color);
}
