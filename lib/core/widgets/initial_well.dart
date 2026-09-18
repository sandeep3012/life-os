import 'package:flutter/material.dart';

import '../../app/theme/app_fonts.dart';

/// The design's category avatar: a rounded well filled with its colour at 15%
/// alpha, carrying either an initial or a glyph at full opacity.
///
/// The handoff states this explicitly — "category chip/avatar wells use the
/// category color at 15% alpha; the glyph/initial uses it at full opacity" — and
/// it recurs at 26px (stat pills), 30px (account cards), 38px (add-menu tiles),
/// 40px (recurring rows) and 42px (transactions).
class InitialWell extends StatelessWidget {
  const InitialWell({
    super.key,
    required this.color,
    required this.size,
    required this.radius,
    this.label,
    this.icon,
    this.fontSize,
  });

  final Color color;
  final double size;
  final double radius;

  /// One or two characters. Ignored when [icon] is set.
  final String? label;
  final IconData? icon;
  final double? fontSize;

  /// Comp: a single uppercase initial taken from the name.
  static String initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: color)
          : Text(
              label ?? '',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: fontSize ?? size * 0.36,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
    );
  }
}
