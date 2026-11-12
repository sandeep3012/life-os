import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/motion.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_fonts.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/widgets/undo_snack_bar.dart';
import '../../settings/application/settings_providers.dart';
import '../application/voice_entry_controller.dart';
import '../data/sample_voice_parser.dart';
import '../domain/voice_draft.dart';

/// Add menu → Speak: say an expense, task, habit or event, then pick the
/// right one of three readings. Asks once, first, whether it's all right to
/// send what's said to the AI service.
Future<void> showVoiceEntrySheet(BuildContext context, WidgetRef ref) async {
  // Test mode sends nothing anywhere, so there's nothing to agree to yet.
  if (!ref.read(voiceTestModeProvider) &&
      !ref.read(settingsProvider).voiceEntryConsent) {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConsentDialog(),
    );
    if (agreed != true || !context.mounted) return;
    await ref.read(settingsControllerProvider).setVoiceEntryConsent(true);
    if (!context.mounted) return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const VoiceEntrySheet(),
  );
}

class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(LucideIcons.mic),
    title: const Text('Add things by voice'),
    content: const Text(
      'Your phone turns what you say into text. To work out what to add, '
      'LifeOS sends that sentence — with your account and category names, '
      'so it can pick the right ones — to an AI service (Anthropic). Nothing '
      'else from your data is sent, and it isn\'t used to train models.\n\n'
      'Needs internet and a signed-in account.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Not now'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Turn on'),
      ),
    ],
  );
}

class VoiceEntrySheet extends ConsumerStatefulWidget {
  const VoiceEntrySheet({super.key});

  @override
  ConsumerState<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends ConsumerState<VoiceEntrySheet> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceEntryControllerProvider.notifier).listen();
    });
  }

  Future<void> _choose(ResolvedVoiceDraft option) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final saved = await ref
          .read(voiceEntryControllerProvider.notifier)
          .choose(option);
      navigator.pop();
      showUndoSnackBar(
        messenger,
        message: saved.message,
        onUndo: saved.undo,
      );
    } on Object {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save that. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(voiceEntryControllerProvider);
    final controller = ref.read(voiceEntryControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sheetRadius),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        // Three option cards can be taller than a small phone (or one in
        // landscape) has room for; the sheet scrolls then rather than
        // overflowing.
        child: SingleChildScrollView(
          child: AnimatedSize(
          duration: AppMotion.of(context, const Duration(milliseconds: 220)),
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (ref.watch(voiceTestModeProvider)) const _TestModeBadge(),
              ...switch (state.phase) {
                VoicePhase.idle ||
                VoicePhase.listening => _listening(state, controller),
                VoicePhase.thinking => _thinking(state),
                VoicePhase.choosing => _choosing(state, controller),
                VoicePhase.error => _error(state, controller),
              },
            ],
          ),
          ),
        ),
      ),
    );
  }

  List<Widget> _listening(
    VoiceEntryState state,
    VoiceEntryController controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      const _Heading('Listening…'),
      const SizedBox(height: 6),
      Text(
        'Say it the way you\'d tell a friend — "spent 250 on lunch from HDFC", '
        '"call Mom tomorrow at 6", "gym every Monday and Thursday".',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 13.5,
          height: 1.45,
          color: scheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 22),
      const Center(child: _PulsingMic()),
      const SizedBox(height: 20),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        // Settled words in full ink, the part still being worked out in grey
        // after them — it firms up as the recogniser decides.
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 20,
              height: 1.3,
              color: scheme.onSurface,
            ),
            children: [
              TextSpan(text: state.text),
              if (state.text.isNotEmpty && state.pending.isNotEmpty)
                const TextSpan(text: ' '),
              TextSpan(
                text: state.pending,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (state.text.isEmpty && state.pending.isEmpty)
                const TextSpan(text: ' '),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: controller.stopListening,
        icon: const Icon(LucideIcons.check, size: 18),
        label: const Text('Done'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ];
  }

  List<Widget> _thinking(VoiceEntryState state) => [
    const _Heading('Working it out…'),
    const SizedBox(height: 16),
    _Quote(state.text),
    const SizedBox(height: 24),
    const Center(child: CircularProgressIndicator()),
    const SizedBox(height: 24),
  ];

  List<Widget> _choosing(
    VoiceEntryState state,
    VoiceEntryController controller,
  ) => [
    const _Heading('Which one did you mean?'),
    const SizedBox(height: 12),
    _Quote(state.text),
    const SizedBox(height: 16),
    for (final (i, option) in state.options.indexed)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _OptionCard(
          index: i,
          option: option,
          best: i == 0,
          onTap: _saving || !option.canSave ? null : () => _choose(option),
        ),
      ),
    const SizedBox(height: 4),
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : controller.listen,
            icon: const Icon(LucideIcons.mic, size: 18),
            label: const Text('Say it again'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('None of these'),
          ),
        ),
      ],
    ),
  ];

  List<Widget> _error(VoiceEntryState state, VoiceEntryController controller) {
    final scheme = Theme.of(context).colorScheme;
    return [
      Icon(LucideIcons.micOff, size: 34, color: scheme.onSurfaceVariant),
      const SizedBox(height: 12),
      Text(
        state.message ?? 'Something went wrong.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      if (state.text.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Quote(state.text),
      ],
      const SizedBox(height: 20),
      if (state.text.isNotEmpty)
        FilledButton(
          onPressed: () => controller.understand(state.text),
          child: const Text('Try again'),
        ),
      OutlinedButton.icon(
        onPressed: controller.listen,
        icon: const Icon(LucideIcons.mic, size: 18),
        label: const Text('Say it again'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ];
  }
}

/// Says plainly that the options are samples, not the AI's.
class _TestModeBadge extends StatelessWidget {
  const _TestModeBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.warm.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.flaskConical, size: 16, color: colors.warm),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Test mode: speech is real; the options are samples, not AI. '
                'Turn off in Settings → Developer tools.',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12.5,
                  height: 1.35,
                  color: colors.warm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _Quote extends StatelessWidget {
  const _Quote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    '“$text”',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 14.5,
      fontStyle: FontStyle.italic,
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _PulsingMic extends StatefulWidget {
  const _PulsingMic();

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withValues(alpha: 0.14),
        ),
        child: Icon(LucideIcons.mic, size: 38, color: context.appColors.accentInk),
      ),
    );
  }
}

/// One detail on an option card. With [onTap] it can be changed; [missing]
/// marks one the AI couldn't fill in.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon, this.onTap, this.missing = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final ink = missing ? colors.accentInk : scheme.onSurfaceVariant;
    return Material(
      color: missing
          ? scheme.primary.withValues(alpha: 0.10)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: onTap == null
            ? BorderSide.none
            : BorderSide(color: missing ? scheme.primary : scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: ink),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12.5,
                    fontWeight: missing ? FontWeight.w700 : FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(LucideIcons.chevronDown, size: 12, color: ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends ConsumerWidget {
  const _OptionCard({
    required this.index,
    required this.option,
    required this.best,
    required this.onTap,
  });

  final int index;
  final ResolvedVoiceDraft option;

  /// The most likely reading.
  final bool best;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final currency = ref.watch(settingsProvider).currencyCode;
    final (icon, color, label) = switch (option.kind) {
      VoiceDraftKind.expense => (
        LucideIcons.arrowDownLeft,
        colors.spend,
        'Expense',
      ),
      VoiceDraftKind.income => (
        LucideIcons.arrowUpRight,
        colors.finance,
        'Income',
      ),
      VoiceDraftKind.task => (LucideIcons.circleCheckBig, colors.tasks, 'Task'),
      VoiceDraftKind.habit => (LucideIcons.sprout, colors.habits, 'Habit'),
      VoiceDraftKind.event => (LucideIcons.calendar, colors.calendar, 'Event'),
    };

    final controller = ref.read(voiceEntryControllerProvider.notifier);
    void update(ResolvedVoiceDraft next) => controller.edit(index, next);
    final hasCategory = option.kind != VoiceDraftKind.event;

    // Each detail the AI filled in is a chip: tap to change it here, then
    // tap the card to save. A detail it couldn't fill is offered as "+ …".
    final chips = <Widget>[
      if (option.amountMinor != null)
        _Chip(
          label: formatMinor(option.amountMinor!.abs(), currencyCode: currency),
        ),
      if (hasCategory)
        _Chip(
          icon: LucideIcons.tag,
          label: option.category == null
              ? '+ Category'
              : option.categoryFromHistory
              ? '${option.category!.name} · as last time'
              : option.category!.name,
          missing: option.category == null,
          onTap: () => _pickCategory(context, ref, update),
        ),
      if (option.kind.isMoney)
        _Chip(
          icon: LucideIcons.wallet,
          label: option.account?.name ?? '+ Account',
          missing: option.account == null,
          onTap: () => _pickAccount(context, ref, update),
        ),
      if (option.kind != VoiceDraftKind.habit)
        _Chip(
          icon: LucideIcons.calendar,
          label: option.when == null ? '+ Date' : _when(option),
          missing: option.when == null && option.kind == VoiceDraftKind.event,
          onTap: () => _pickDate(context, update),
        ),
      if (option.kind == VoiceDraftKind.habit && option.hasTime)
        _Chip(icon: LucideIcons.bell, label: DateFormat.jm().format(option.when!)),
      if (option.draft.repeat != 'none')
        _Chip(icon: LucideIcons.repeat, label: _repeat(option.draft)),
    ];

    return Opacity(
      opacity: option.canSave ? 1 : 0.55,
      child: Material(
        color: best ? scheme.primary.withValues(alpha: 0.06) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
          side: BorderSide(
            color: best ? scheme.primary : scheme.outlineVariant,
            width: best ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.draft.title,
                        style: const TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: chips),
                      ],
                      if (!option.canSave)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Add an account first to record money.',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 12.5,
                              color: colors.warm,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (best)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 16,
                      color: colors.accentInk,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCategory(
    BuildContext context,
    WidgetRef ref,
    void Function(ResolvedVoiceDraft) update,
  ) async {
    final choices = ref
        .read(voiceEntryControllerProvider)
        .categoriesFor(option.kind);
    // Money always has a category; a task or habit can go without.
    final allowNone = !option.kind.isMoney;
    final picked = await _pick<Category?>(
      context,
      title: 'Category',
      items: [
        for (final c in choices) (c, c.name),
        if (allowNone) (null, 'No category'),
      ],
      selected: option.category,
      same: (a, b) => a?.id == b?.id,
    );
    if (picked == null) return;
    final (value,) = picked;
    update(
      value == null
          ? option.copyWith(clearCategory: true)
          : option.copyWith(category: value),
    );
  }

  Future<void> _pickAccount(
    BuildContext context,
    WidgetRef ref,
    void Function(ResolvedVoiceDraft) update,
  ) async {
    final accounts = ref.read(voiceEntryControllerProvider).accounts;
    final picked = await _pick<Account?>(
      context,
      title: 'Account',
      items: [for (final a in accounts) (a, a.name)],
      selected: option.account,
      same: (a, b) => a?.id == b?.id,
    );
    if (picked == null) return;
    final (value,) = picked;
    if (value != null) update(option.copyWith(account: value));
  }

  Future<void> _pickDate(
    BuildContext context,
    void Function(ResolvedVoiceDraft) update,
  ) async {
    final now = DateTime.now();
    final current = option.when ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (day == null) return;
    // The time of day stays as it was said.
    update(
      option.copyWith(
        when: DateTime(
          day.year,
          day.month,
          day.day,
          option.hasTime ? current.hour : 0,
          option.hasTime ? current.minute : 0,
        ),
      ),
    );
  }

  /// A short list to choose from. Returns the choice wrapped in a record so
  /// "No category" (null) can be told apart from dismissing the sheet.
  static Future<(T,)?> _pick<T>(
    BuildContext context, {
    required String title,
    required List<(T, String)> items,
    required T selected,
    required bool Function(T, T) same,
  }) => showModalBottomSheet<(T,)>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final (value, label) in items)
            ListTile(
              title: Text(label),
              trailing: same(value, selected)
                  ? const Icon(LucideIcons.check, size: 18)
                  : null,
              onTap: () => Navigator.of(context).pop((value,)),
            ),
        ],
      ),
    ),
  );

  static String _when(ResolvedVoiceDraft o) {
    final when = o.when!;
    final today = DateTime.now();
    final day = DateTime(when.year, when.month, when.day);
    final diff = day.difference(DateTime(today.year, today.month, today.day));
    final date = switch (diff.inDays) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => DateFormat('EEE d MMM').format(when),
    };
    if (!o.hasTime) return date;
    final end = o.endsAt;
    final time = DateFormat.jm().format(when);
    return end == null
        ? '$date, $time'
        : '$date, $time – ${DateFormat.jm().format(end)}';
  }

  static String _repeat(VoiceDraft d) {
    if (d.repeat == 'weekly' && d.weekdays.isNotEmpty) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return 'Every ${[for (final w in d.weekdays) names[w - 1]].join(', ')}';
    }
    return switch (d.repeat) {
      'daily' => 'Every day',
      'weekly' => 'Every week',
      'monthly' => 'Every month',
      'yearly' => 'Every year',
      _ => '',
    };
  }
}
