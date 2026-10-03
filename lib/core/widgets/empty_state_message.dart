import 'package:flutter/material.dart';

/// A friendlier "nothing here yet" block: a big colorful emoji over a short
/// message, in place of a bare line of grey text. Used across list/history
/// screens once they have no rows to show.
class EmptyStateMessage extends StatelessWidget {
  const EmptyStateMessage({
    super.key,
    required this.emoji,
    required this.message,
    this.title,
    this.padding = const EdgeInsets.all(32),
  });

  /// The colourful glyph shown above the message — a [pickableEmojis] entry
  /// or any other Unicode emoji, always rendered in full colour regardless of
  /// theme.
  final String emoji;

  /// A short bold heading, e.g. "No bills tracked yet". Optional: some call
  /// sites only need the one explanatory line in [message].
  final String? title;

  final String message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  (title != null
                          ? theme.textTheme.bodySmall
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
