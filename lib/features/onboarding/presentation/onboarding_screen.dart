import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/motion.dart';
import '../../../app/theme/app_color_theme.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_fonts.dart';
import '../../../core/services/demo_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/widgets/tab_rail.dart';
import '../../settings/application/settings_providers.dart';

/// The first-launch welcome: what LifeOS is, that it's private, a quick
/// setup, and reminders. Shown once, in place of the app, until finished or
/// skipped; see `OnboardingGate` for when it is offered at all.
///
/// The setup choices write straight to settings, so the app behind it is
/// already in the chosen theme and currency the moment it appears. A colour
/// theme picked here needs no restart: nothing else has been built yet.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const pageCount = 4;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  /// Which finishing button is working, so it can show progress.
  String? _busy;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) => _pages.animateToPage(
    page,
    duration: AppMotion.of(context, AppMotion.screenEnter),
    curve: AppMotion.curveOf(context, AppMotion.standard),
  );

  Future<void> _finish(String how) async {
    if (_busy != null) return;
    setState(() => _busy = how);
    try {
      switch (how) {
        case 'reminders':
          await ref.read(notificationServiceProvider).requestReminderPermissions();
        case 'sample':
          await ref.read(demoDataServiceProvider).generate();
      }
    } catch (_) {
      // A refused permission or a failed sample fill shouldn't trap anyone
      // on the welcome screens; both can be done again from Settings.
    }
    await ref.read(settingsControllerProvider).setOnboardingCompleted(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _page < 2
                      ? TextButton(
                          onPressed: () => _goTo(2),
                          child: const Text('Skip'),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: const [
                    _WelcomePage(),
                    _PrivacyPage(),
                    _SetupPage(),
                    _RemindersPage(),
                  ],
                ),
              ),
              _Dots(count: OnboardingScreen.pageCount, active: _page),
              const SizedBox(height: 18),
              if (_page < OnboardingScreen.pageCount - 1)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _goTo(_page + 1),
                    child: Text(_page == 2 ? 'Continue' : 'Next'),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy == null
                        ? () => _finish('reminders')
                        : null,
                    child: Text(
                      _busy == 'reminders' ? 'One moment…' : 'Turn on reminders',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _busy == null ? () => _finish('sample') : null,
                  child: Text(
                    _busy == 'sample'
                        ? 'Adding sample data…'
                        : 'Try it with sample data',
                  ),
                ),
                TextButton(
                  onPressed: _busy == null ? () => _finish('fresh') : null,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  child: const Text('Start fresh'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.art, required this.title, required this.body});

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 250, child: Center(child: art)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 15,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final modules = [
      (LucideIcons.wallet, 'Money', colors.finance),
      (LucideIcons.flame, 'Habits', colors.habits),
      (LucideIcons.listChecks, 'Tasks', colors.tasks),
      (LucideIcons.heartPulse, 'Health', colors.goals),
      (LucideIcons.bookOpen, 'Learn', colors.notes),
      (LucideIcons.calendar, 'Calendar', colors.calendar),
    ];
    return _Page(
      art: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (icon, label, color) in modules)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      title: 'Your whole day,\nin one calm place.',
      body:
          'Track spending, build habits, plan tasks, take your medication on '
          'time and keep notes — LifeOS brings them together.',
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Page(
      art: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(LucideIcons.shieldCheck, size: 64, color: scheme.primary),
      ),
      title: 'Private by design.',
      body:
          'Everything stays on this phone. No account, no sign-up, no ads. '
          'Back it up whenever you like, and lock the app with your '
          'fingerprint or a PIN.',
    );
  }
}

/// Currency, colour theme and light/dark — written as they're picked.
class _SetupPage extends ConsumerWidget {
  const _SetupPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsControllerProvider);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Make it yours.',
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You can change these any time in Settings.',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          label('CURRENCY'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in supportedCurrencies)
                ChoiceChip(
                  label: Text('${c.code} ${c.symbol}'),
                  selected: settings.currencyCode == c.code,
                  onSelected: (_) => controller.setCurrencyCode(c.code),
                ),
            ],
          ),
          label('COLOUR THEME'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final theme in AppColorTheme.values)
                Semantics(
                  button: true,
                  selected: settings.colorTheme == theme,
                  label: theme.label,
                  child: GestureDetector(
                    onTap: () => controller.setColorTheme(theme),
                    child: AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.navColor),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: theme.previewColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: settings.colorTheme == theme
                              ? scheme.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            settings.colorTheme.label,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          label('APPEARANCE'),
          AppTabRail<ThemeMode>(
            value: settings.themeMode,
            labels: const {
              ThemeMode.system: 'System',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            },
            onChanged: controller.setThemeMode,
          ),
        ],
      ),
    );
  }
}

class _RemindersPage extends StatelessWidget {
  const _RemindersPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Page(
      art: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(LucideIcons.bellRing, size: 56, color: scheme.primary),
      ),
      title: 'Never miss a thing.',
      body:
          'Reminders for tasks, bills, habits and doses — as a gentle '
          'notification or a proper alarm. Or explore first with sample '
          'data, which you can remove from Settings.',
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.navColor),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
