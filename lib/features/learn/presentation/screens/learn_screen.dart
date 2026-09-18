import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/motion.dart';
import '../../../../app/router/app_sidebar.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/dashed_action_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/learn_providers.dart';
import '../widgets/note_editor_sheet.dart';

/// The comp's Learn screen: a gradient review-queue hero, a horizontal run of
/// notebook cards with progress bars, a Recent / Starred / Due tab rail, then the
/// note list and a dashed "Write a new note" row.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

enum _LearnTab { recent, starred, due }

class _LearnScreenState extends ConsumerState<LearnScreen> {
  _LearnTab _tab = _LearnTab.recent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final books = ref.watch(bookProgressProvider);
    final notes = ref.watch(learnNotesProvider).value ?? const [];
    final due = ref.watch(dueNotesProvider);

    final visible = switch (_tab) {
      _LearnTab.recent => notes,
      _LearnTab.starred => notes.where((n) => n.starred).toList(),
      _LearnTab.due => due,
    };

    return Scaffold(
      drawer: const AppSidebar(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Builder(
                builder: (context) => AppTopBar(
                  centerText: 'Learn',
                  centerIsTitle: true,
                  trailingIcon: LucideIcons.plus,
                  onTrailing: () => showNoteEditorSheet(context),
                  onMenu: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),

            _ReviewQueueHero(
              dueCount: due.length,
              totalCount: notes.length,
              onStart: due.isEmpty
                  ? null
                  : () => context.go(RoutePaths.learnNote(due.first.id)),
            ),

            const SizedBox(height: 20),
            SectionHeader(
              title: 'Notebooks',
              trailing: Text(
                '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 11),
            if (books.isEmpty)
              Text(
                'No notebooks yet — your first note creates one.',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 13.5,
                  color: colors.text3,
                ),
              )
            else
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 9),
                  itemBuilder: (context, i) => _NotebookCard(progress: books[i]),
                ),
              ),

            const SizedBox(height: 20),
            AppTabRail<_LearnTab>(
              value: _tab,
              labels: const {
                _LearnTab.recent: 'Recent',
                _LearnTab.starred: 'Starred',
                _LearnTab.due: 'Due',
              },
              height: 36,
              fontSize: 12.5,
              onChanged: (t) => setState(() => _tab = t),
            ),

            const SizedBox(height: 12),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    switch (_tab) {
                      _LearnTab.recent => 'Nothing written yet.',
                      _LearnTab.starred => 'No starred notes.',
                      _LearnTab.due => 'Nothing due — you are all caught up.',
                    },
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      color: colors.text3,
                    ),
                  ),
                ),
              )
            else
              for (final note in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NoteCard(note: note),
                ),

            const SizedBox(height: 2),
            DashedActionButton(
              label: 'Write a new note',
              onTap: () => showNoteEditorSheet(context),
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
}

/// Comp: radius-24 gradient card — `REVIEW QUEUE`, the due count, a blurb, and a
/// light-on-accent CTA.
class _ReviewQueueHero extends StatelessWidget {
  const _ReviewQueueHero({
    required this.dueCount,
    required this.totalCount,
    this.onStart,
  });

  final int dueCount;
  final int totalCount;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onHero = Theme.of(context).colorScheme.onPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.5, -0.866),
            end: const Alignment(0.5, 0.866),
            colors: [colors.heroA, colors.heroB],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -46,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.heroVeil,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Overline(
                    'Review queue',
                    color: onHero.withValues(alpha: 0.92),
                    letterSpacing: 1.2,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$dueCount',
                        style: TextStyle(
                          fontFamily: AppFonts.serif,
                          fontSize: 36,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: onHero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          dueCount == 1
                              ? 'note due for revision'
                              : 'notes due for revision',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: onHero.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Text(
                    totalCount == 0
                        ? 'Write your first note and it joins the queue.'
                        : dueCount == 0
                            ? 'Nothing due right now. Come back tomorrow.'
                            : 'Spaced repetition keeps what you read. '
                                'Reviewing now pushes each note further out.',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 13,
                      height: 1.45,
                      color: onHero.withValues(alpha: 0.9),
                    ),
                  ),
                  if (onStart != null) ...[
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Tappable(
                        onTap: onStart,
                        haptic: TapHaptic.medium,
                        semanticLabel: 'Start a review',
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: onHero,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Start a 5-min review',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: colors.heroA,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comp: a 132px radius-19 card with a 4px colour spine down its leading edge.
class _NotebookCard extends StatelessWidget {
  const _NotebookCard({required this.progress});

  final BookProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final accent =
        Color(int.parse(progress.book.colorHex.replaceFirst('#', '0xFF')));

    return SizedBox(
      width: 132,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            SurfaceCard(
              padding: const EdgeInsets.all(14),
              radius: 19,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(LucideIcons.bookOpen, size: 16, color: accent),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    progress.book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${progress.noteCount} '
                    '${progress.noteCount == 1 ? 'note' : 'notes'}',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11.5,
                      color: colors.text3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 4,
                      backgroundColor: scheme.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comp: radius-20 card — a coloured book label, relative time, serif title,
/// excerpt, tag chips and a due marker.
class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});

  final LearnNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final books = ref.watch(learnBooksProvider).value ?? const [];
    final match = books.where((b) => b.id == note.bookId);
    final book = match.isEmpty ? null : match.first;
    final accent = book == null
        ? scheme.secondary
        : Color(int.parse(book.colorHex.replaceFirst('#', '0xFF')));

    final due = note.reviewDueAt != null &&
        !note.reviewDueAt!.isAfter(DateTime.now());
    final tags = note.tagsCsv.split(',').where((t) => t.trim().isNotEmpty);

    return Tappable(
      haptic: TapHaptic.light,
      semanticLabel: note.title,
      onTap: () => context.go(RoutePaths.learnNote(note.id)),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: due ? scheme.secondary : scheme.outline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Overline(book?.name ?? 'Note', color: accent, letterSpacing: 0.5),
                ),
                Text(
                  _relative(note.updatedAt),
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 11.5,
                    color: colors.text3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              note.title,
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 17.5,
                height: 1.28,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            if (note.excerpt.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                note.excerpt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12.5,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 11),
            Row(
              children: [
                for (final tag in tags) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      tag.trim(),
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (note.starred)
                  Icon(LucideIcons.star, size: 15, color: colors.warning),
                if (due) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Due',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.accentInk,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
