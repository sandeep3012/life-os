import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/motion.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_fonts.dart';
import '../reminders/ringing_alarm.dart';
import '../reminders/ringing_alarm_controller.dart';
import '../services/notification_service.dart';

/// The ringing alarm, full screen above everything — app lock included,
/// like the phone's own alarm, which rings over the lock screen. Nothing
/// when no alarm is ringing.
class AlarmRingingLayer extends ConsumerWidget {
  const AlarmRingingLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarm = ref.watch(ringingAlarmProvider);
    return AnimatedSwitcher(
      duration: AppMotion.of(context, const Duration(milliseconds: 220)),
      child: alarm == null
          ? const SizedBox.shrink()
          : AlarmRingingScreen(
              key: ValueKey(alarm.notificationId),
              alarm: alarm,
              onSnooze: () =>
                  ref.read(ringingAlarmProvider.notifier).snooze(),
              onDismiss: () =>
                  ref.read(ringingAlarmProvider.notifier).dismiss(),
            ),
    );
  }
}

class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({
    super.key,
    required this.alarm,
    required this.onSnooze,
    required this.onDismiss,
  });

  final RingingAlarm alarm;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A still bell under reduce-motion; a gentle pulse otherwise.
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _clock.cancel();
    _pulse.dispose();
    super.dispose();
  }

  static String _kindLabel(String kind) => switch (kind) {
    'habit' => 'Habit',
    'medication' => 'Medication',
    'event' => 'Event',
    'bill' => 'Bill',
    'goal' => 'Goal',
    _ => 'Task',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final snoozeMinutes = alarmSnoozeDuration.inMinutes;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(_now),
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 15,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.jm().format(_now),
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 64,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppFonts.tabular,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.12).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    LucideIcons.alarmClock,
                    size: 48,
                    color: colors.accentInk,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _kindLabel(widget.alarm.kind).toUpperCase(),
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: colors.accentInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.alarm.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: scheme.onSurface,
                ),
              ),
              if (widget.alarm.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.alarm.body,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 15,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: widget.onDismiss,
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: widget.onSnooze,
                  icon: const Icon(LucideIcons.alarmClockPlus, size: 20),
                  label: Text(
                    'Snooze $snoozeMinutes min',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
