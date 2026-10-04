import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/compact_editor_sheet.dart';

/// How the app lock is opened.
enum UnlockMethod {
  /// The phone's own lock: Face ID, fingerprint, or its passcode / PIN / pattern.
  phoneLock,

  /// A PIN made just for this app.
  appPin,
}

/// Asks which way to unlock the app. Only shown when the phone has a screen lock
/// to use; without one there is nothing to choose and the app PIN is the only way.
Future<UnlockMethod?> showUnlockMethodSheet(BuildContext context) {
  return showCompactEditorSheet<UnlockMethod>(
    context: context,
    builder: (context) => CompactEditorSheet(
      title: 'Unlock with',
      child: Column(
        children: [
          _Option(
            icon: LucideIcons.scanFace,
            title: 'Phone lock',
            subtitle:
                "Face ID, fingerprint or your phone's passcode. "
                'No extra PIN to remember.',
            recommended: true,
            onTap: () => Navigator.of(context).pop(UnlockMethod.phoneLock),
          ),
          const SizedBox(height: 10),
          _Option(
            icon: LucideIcons.keyRound,
            title: 'App PIN',
            subtitle: 'A separate PIN just for LifeOS.',
            onTap: () => Navigator.of(context).pop(UnlockMethod.appPin),
          ),
        ],
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.recommended = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: recommended
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: recommended ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Recommended',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
