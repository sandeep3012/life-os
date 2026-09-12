import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/tappable.dart';

/// Comp: a 34×34 radius-11 accent square carrying a serif "L", then "LifeOS" at
/// 20px Newsreader w600.
class AuthBrandRow extends StatelessWidget {
  const AuthBrandRow({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            'L',
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'LifeOS',
          style: TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Comp: the big serif hero with an accent full stop — "Welcome / back." at 40px
/// Newsreader w500, tracking −0.5, line-height ~1.02.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.lines, this.fontSize = 40});

  final List<String> lines;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: fontSize,
          height: 1.02,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        children: [
          TextSpan(text: lines.join('\n')),
          TextSpan(text: '.', style: TextStyle(color: scheme.secondary)),
        ],
      ),
    );
  }
}

/// Comp field: a 12px w600 `text2` label over a 52px row on `surface` with a
/// hairline at radius 15, an 18px leading icon in `text3`, and a 15px value.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.hintText,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? hintText;
  final bool obscure;

  /// When set, the trailing eye toggle is shown.
  final VoidCallback? onToggleObscure;

  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: AppSpacing.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.text3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 15,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 15,
                      color: colors.text3,
                    ),
                    // The bordered row above *is* the field chrome, so the
                    // TextField itself contributes none.
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (onToggleObscure != null)
                Tappable(
                  onTap: onToggleObscure,
                  semanticLabel: obscure ? 'Show password' : 'Hide password',
                  child: Icon(
                    obscure
                        ? LucideIcons.eye
                        : LucideIcons.eyeOff,
                    size: 19,
                    color: colors.text3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Comp: the primary CTA — 54px, radius 16, accent fill, 15.5px w700 `onAccent`
/// label with a trailing glyph.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.trailingIcon = LucideIcons.arrowRight,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData trailingIcon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tappable(
      onTap: busy ? null : onTap,
      haptic: TapHaptic.medium,
      semanticLabel: label,
      child: Container(
        height: AppSpacing.primaryButtonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppSpacing.primaryButtonRadius),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(trailingIcon, size: 18, color: scheme.onPrimary),
                ],
              ),
      ),
    );
  }
}

/// Comp: hairlines flanking "or continue with" in 12px w600 `text3`.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'or continue with'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: scheme.outline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.text3,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: scheme.outline)),
      ],
    );
  }
}

/// Comp: a 2-up grid of 50px radius-14 `surface` buttons with a hairline.
///
/// The marks are placeholders. The handoff requires Google's official multicolour
/// "G" and the Apple logo "per each provider's brand guidelines", which means
/// shipping their supplied assets — an approximation drawn by hand would breach
/// those guidelines, so these carry neutral stand-ins until the real assets are
/// added to `assets/`.
class AuthSocialRow extends StatelessWidget {
  const AuthSocialRow({super.key, this.onGoogle, this.onApple});

  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            label: 'Google',
            markColor: const Color(0xFF4285F4),
            markText: 'G',
            onTap: onGoogle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            label: 'Apple',
            icon: LucideIcons.apple,
            onTap: onApple,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    this.icon,
    this.markText,
    this.markColor,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? markText;
  final Color? markColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: 'Continue with $label',
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: scheme.onSurface)
            else
              Text(
                markText ?? '',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: markColor ?? scheme.onSurface,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comp: four 4px bars at radius 2 with 5px gaps; filled bars take the accent
/// (the last filled one at 55% opacity), empty bars the border tone.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.filled});

  /// 0..4.
  final int filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < filled
                    ? scheme.secondary.withValues(
                        alpha: i == filled - 1 && filled < 4 ? 0.55 : 1,
                      )
                    : scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Rough strength score used to fill the bars: length, plus a letter/digit and a
  /// symbol bonus.
  static int scoreOf(String password) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'\d').hasMatch(password) && RegExp('[A-Za-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score.clamp(1, 4);
  }
}
