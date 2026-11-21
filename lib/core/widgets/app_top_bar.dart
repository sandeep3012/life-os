import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'section_header.dart';
import 'tappable.dart';

/// The dashboard/finance top row. Comp: a 42×42 radius-13 `surface` button with a
/// hairline on the leading edge, a centred uppercase date or title, and a 42px
/// circular avatar with a 135° `heroA → heroB` gradient and a 2px `surface` ring.
///
/// The avatar shows a glyph rather than initials: this build has no profile to
/// take a name from. When the sync account lands it supplies one, and [initials]
/// takes over.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.centerText,
    this.onMenu,
    this.menuKey,
    this.onAvatar,
    this.initials,
    this.trailingIcon,
    this.onTrailing,
    this.centerIsTitle = false,
    this.showTrailing = true,
    this.trailingLabel = 'Filter',
    this.center,
  });

  final String centerText;

  /// Replaces the centre text — a search field, say.
  final Widget? center;
  final VoidCallback? onMenu;

  /// Lets a screen tour point at the menu button.
  final Key? menuKey;
  final VoidCallback? onAvatar;
  final String? initials;

  /// When set, replaces the avatar with a bordered icon button — the comp's
  /// finance screen uses a filter button in that slot.
  final IconData? trailingIcon;
  final String trailingLabel;
  final VoidCallback? onTrailing;

  /// Finance renders its centre slot as a 19px serif title instead of an overline.
  final bool centerIsTitle;

  /// The Habits header has no trailing control — the comp balances the row with
  /// an empty 42px spacer so the title stays optically centred.
  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KeyedSubtree(
          key: menuKey,
          child: _IconButton(
            icon: LucideIcons.menu,
            onTap: onMenu,
            semanticLabel: 'Menu',
          ),
        ),
        Expanded(
          child: Center(
            child: center != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: center,
                  )
                : centerIsTitle
                ? Text(
                    centerText,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 19),
                  )
                : Overline(centerText, letterSpacing: 0.4),
          ),
        ),
        if (!showTrailing)
          const SizedBox(width: 42)
        else if (trailingIcon != null)
          _IconButton(
            icon: trailingIcon!,
            onTap: onTrailing,
            semanticLabel: trailingLabel,
          )
        else
          _Avatar(initials: initials, onTap: onAvatar),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap, this.semanticLabel});

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: semanticLabel,
      enforceMinTouchTarget: true,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.iconButtonRadius),
        ),
        child: Icon(icon, size: 19, color: scheme.onSurface),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.initials, this.onTap});

  final String? initials;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: 'Account',
      enforceMinTouchTarget: true,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 2),
          gradient: LinearGradient(
            // CSS `linear-gradient(135deg, …)`.
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.heroA, colors.heroB],
          ),
        ),
        child: initials == null
            ? Icon(LucideIcons.user, size: 20, color: scheme.onPrimary)
            : Center(
                child: Text(
                  initials!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
      ),
    );
  }
}

/// [AppTopBar] as a Scaffold's `appBar`, for the screens the side menu opens
/// (Goals, Notes, Documents, Insights, Search, Settings). They used Material's
/// own app bar, so the header changed shape — small left-hand title, bare
/// icons — whenever someone moved between one of them and Home or Planner.
/// The menu button opens the enclosing Scaffold's drawer.
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({
    super.key,
    required this.title,
    this.center,
    this.trailingIcon,
    this.trailingLabel = 'Options',
    this.onTrailing,
  });

  final String title;
  final Widget? center;
  final IconData? trailingIcon;
  final String trailingLabel;
  final VoidCallback? onTrailing;

  /// The same 10 / 14 padding the tab screens give the bar, around its
  /// 44-point buttons.
  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: AppTopBar(
          centerText: title,
          centerIsTitle: true,
          center: center,
          onMenu: () => Scaffold.of(context).openDrawer(),
          showTrailing: trailingIcon != null,
          trailingIcon: trailingIcon,
          trailingLabel: trailingLabel,
          onTrailing: onTrailing,
        ),
      ),
    );
  }
}
