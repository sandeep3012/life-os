import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/motion.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/learn_providers.dart';

/// The comp's note reader: a fixed header carrying the book label and a star
/// toggle, the note body in serif prose with quote and code treatments, the
/// recall-prompt card, and "Review later" / "Mark reviewed" pinned to the base.
class NoteReaderScreen extends ConsumerWidget {
  const NoteReaderScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final note = ref.watch(learnNoteByIdProvider(noteId));
    if (note == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: Center(
          child: Text(
            'This note is no longer available.',
            style: TextStyle(fontFamily: AppFonts.sans, color: colors.text3),
          ),
        ),
      );
    }

    final books = ref.watch(learnBooksProvider).value ?? const [];
    final match = books.where((b) => b.id == note.bookId);
    final book = match.isEmpty ? null : match.first;
    final accent = book == null
        ? scheme.secondary
        : Color(int.parse(book.colorHex.replaceFirst('#', '0xFF')));

    final blocks = NoteBlock.decode(note.bodyJson);
    final controller = ref.read(learnControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---- fixed header ----
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Tappable(
                    haptic: TapHaptic.light,
                    semanticLabel: 'Back',
                    onTap: () => context.go(RoutePaths.learn),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.chevronLeft,
                        size: 20,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (book?.name ?? 'Note').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _meta(note.minutes, note.reviewDueAt),
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 11.5,
                            color: colors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tappable(
                    haptic: TapHaptic.selection,
                    semanticLabel: note.starred ? 'Unstar note' : 'Star note',
                    selected: note.starred,
                    onTap: () => controller.toggleStar(note),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: note.starred ? colors.accentSoft : scheme.surface,
                        border: Border.all(
                          color: note.starred ? scheme.secondary : scheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        note.starred
                            ? LucideIcons.star
                            : LucideIcons.star,
                        size: 18,
                        color: note.starred
                            ? colors.accentInk
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- body ----
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                children: [
                  Text(
                    note.title,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 27,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final block in blocks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: _Block(block: block, accent: accent),
                    ),
                  if (note.prompt.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RECALL PROMPT',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: colors.text3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            note.prompt,
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 14.5,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ---- pinned actions ----
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Tappable(
                      haptic: TapHaptic.light,
                      semanticLabel: 'Review later',
                      onTap: () async {
                        await controller.reviewLater(note);
                        if (context.mounted) context.go(RoutePaths.learn);
                      },
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          border: Border.all(color: scheme.outline),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.primaryButtonRadius,
                          ),
                        ),
                        child: Text(
                          'Review later',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 2,
                    child: Tappable(
                      haptic: TapHaptic.medium,
                      semanticLabel: 'Mark reviewed',
                      onTap: () async {
                        await controller.markReviewed(note);
                        if (context.mounted) context.go(RoutePaths.learn);
                      },
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.primaryButtonRadius,
                          ),
                        ),
                        child: Text(
                          'Mark reviewed',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: AppMotion.screenEnter).slideY(
              begin: 0.02,
              end: 0.0,
              duration: AppMotion.screenEnter,
              curve: AppMotion.standard,
            ),
      ),
    );
  }

  static String _meta(int minutes, DateTime? dueAt) {
    final read = '$minutes min read';
    if (dueAt == null) return read;
    if (!dueAt.isAfter(DateTime.now())) return '$read · due now';
    return '$read · due ${DateFormat('d MMM').format(dueAt)}';
  }
}

/// The comp's three body treatments: plain prose, a quote with a coloured rule,
/// and a monospaced code block on the inset surface.
class _Block extends StatelessWidget {
  const _Block({required this.block, required this.accent});

  final NoteBlock block;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (block.type) {
      case 'quote':
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Text(
            block.text,
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 16,
              height: 1.65,
              fontStyle: FontStyle.italic,
              color: scheme.onSurface,
            ),
          ),
        );
      case 'code':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appColors.codeBg,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            block.text,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 12.5,
              height: 1.55,
              fontWeight: FontWeight.w400,
              color: scheme.onSurface,
            ),
          ),
        );
      default:
        return Text(
          block.text,
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 15,
            height: 1.65,
            color: scheme.onSurface,
          ),
        );
    }
  }
}
