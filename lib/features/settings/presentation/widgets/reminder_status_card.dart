import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/reminders/reminder_status.dart';
import '../../../../core/services/notification_service.dart';

class ReminderStatusCard extends ConsumerStatefulWidget {
  const ReminderStatusCard({super.key});
  @override
  ConsumerState<ReminderStatusCard> createState() => _ReminderStatusCardState();
}

class _ReminderStatusCardState extends ConsumerState<ReminderStatusCard>
    with WidgetsBindingObserver {
  late Future<ReminderStatus> _status;
  bool _requesting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = ref.read(notificationServiceProvider).readStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() {
    if (mounted) {
      setState(
        () => _status = ref.read(notificationServiceProvider).readStatus(),
      );
    }
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      await ref.read(notificationServiceProvider).requestReminderPermissions();
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not request permissions. Check LifeOS notifications in device settings.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<ReminderStatus>(
        future: _status,
        builder: (context, snapshot) {
          final status = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reminder status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                const Text('Reminder status is unavailable on this device.')
              else if (status != null) ...[
                Text(
                  'Permission: ${switch (status.enabled) {
                    true => 'Enabled',
                    false => 'Disabled',
                    null => 'Unknown',
                  }}',
                ),
                if (status.exactAlarms != null)
                  Text(
                    'Precise timing: ${status.exactAlarms! ? 'Allowed' : 'Not allowed'}',
                  ),
                Text('${status.pendingCount} pending notifications'),
                if (status.scheduled.isNotEmpty) ...[
                  Text(
                    'Next queued: ${status.scheduled.first.title} · ${DateFormat.yMMMd().add_jm().format(status.scheduled.first.time)}',
                  ),
                  Text(
                    'Last queued task/habit/event: ${DateFormat.yMMMd().add_jm().format(status.scheduled.last.time)}',
                  ),
                ] else
                  const Text('No queued task, habit, or event reminders.'),
              ],
              const SizedBox(height: 8),
              const Text(
                'The local queue is replenished while LifeOS is running or reopened. Pending does not guarantee delivery; device settings can silence reminders. Bill and goal times are not included in the dates above.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Refresh status'),
                  ),
                  TextButton(
                    onPressed: _requesting ? null : _request,
                    child: Text(
                      _requesting ? 'Requesting…' : 'Request permission',
                    ),
                  ),
                ],
              ),
              const Text(
                'If permission was previously denied, enable it in your device’s notification settings.',
              ),
            ],
          );
        },
      ),
    ),
  );
}
