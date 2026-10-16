import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_fonts.dart';
import '../../../core/widgets/surface_card.dart';
import '../../auth/application/sync_auth_providers.dart';
import '../application/sync_providers.dart';
import '../domain/sync_crypto.dart';

/// Sidebar → Sync & account, and Settings → Sync: everything about sync on
/// one screen, whatever stage it's at — not available, signed out, setting
/// up, unlocking on another phone, or running.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync & account'),
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.settings),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          switch (status.phase) {
            SyncPhase.unavailable => const _Unavailable(),
            SyncPhase.signedOut => const _SignedOut(),
            SyncPhase.checking => _Checking(error: status.error),
            SyncPhase.needsSetup => _SetUp(email: status.email),
            SyncPhase.needsRecoveryKey => _Unlock(email: status.email),
            SyncPhase.ready => _Ready(status: status),
          },
        ],
      ),
    );
  }

  /// After a password-reset link brings the person back into the app.
  static Future<void> chooseNewPassword(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPasswordDialog(),
    );
    ref.read(syncControllerProvider.notifier).finishedChoosingPassword();
    if (password == null) return;
    final outcome = await ref
        .read(syncAuthControllerProvider)
        .updatePassword(password);
    if (!context.mounted) return;
    _snack(context, switch (outcome) {
      SyncAuthSuccess() => 'Password changed.',
      SyncAuthFailure(message: final m) => m,
      SyncAuthContinueElsewhere(message: final m) => m,
      SyncAuthNotConfigured() => SyncAuthNotConfigured.message,
    });
  }
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

class _Intro extends StatelessWidget {
  const _Intro({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Icon(icon, size: 30, color: context.appColors.accentInk),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 14.5,
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => const _Intro(
    icon: LucideIcons.cloudOff,
    title: 'Sync isn\'t available in this build',
    body:
        'Everything you add is saved on this device, as always. Sync needs a '
        'build made with the server\'s key.',
  );
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Intro(
          icon: LucideIcons.cloud,
          title: 'Your data on all your phones',
          body:
              'Sign in to keep LifeOS in step across devices and safe if a '
              'phone is lost. Everything is encrypted on your phone before it '
              'leaves — the server can\'t read any of it.\n\n'
              'You don\'t need an account to use LifeOS. Without one, your '
              'data stays on this device.',
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => context.push(RoutePaths.syncSignIn),
          child: const Text('Sign in'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => context.push(RoutePaths.syncSignUp),
          child: const Text('Create an account'),
        ),
      ],
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// The first phone on an account: make the recovery key.
class _SetUp extends ConsumerStatefulWidget {
  const _SetUp({this.email});

  final String? email;

  @override
  ConsumerState<_SetUp> createState() => _SetUpState();
}

class _SetUpState extends ConsumerState<_SetUp> {
  bool _busy = false;

  Future<void> _start() async {
    final controller = ref.read(syncControllerProvider.notifier);
    final pending = controller.newAccountKeys();
    final kept = await showRecoveryKeySheet(context, pending.recoveryKey);
    if (!kept || !mounted) return;
    setState(() => _busy = true);
    try {
      await controller.saveRecoveryKey(pending);
    } on Object {
      if (mounted) {
        _snack(context, "Couldn't reach the server. Try again in a moment.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Intro(
          icon: LucideIcons.keyRound,
          title: 'Set up sync',
          body:
              'Signed in as ${widget.email ?? 'you'}.\n\n'
              'Your data is locked with a key only your phones hold. You\'ll '
              'get a recovery key to keep somewhere safe — it\'s the only way '
              'to unlock your data on a new phone if this one is lost. We '
              'can\'t recover it for you.',
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _busy ? null : _start,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create my recovery key'),
        ),
        const SizedBox(height: 10),
        const _SignOutButton(),
      ],
    );
  }
}

/// Another phone on an account that already syncs: enter the recovery key.
class _Unlock extends ConsumerStatefulWidget {
  const _Unlock({this.email});

  final String? email;

  @override
  ConsumerState<_Unlock> createState() => _UnlockState();
}

class _UnlockState extends ConsumerState<_Unlock> {
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncControllerProvider.notifier).unlock(_key.text);
    } on SyncCryptoException catch (e) {
      _error = e.message;
    } on Object {
      _error = "Couldn't reach the server. Try again in a moment.";
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Intro(
          icon: LucideIcons.lockKeyhole,
          title: 'Unlock your data',
          body:
              'Signed in as ${widget.email ?? 'you'}. This account already '
              'syncs from another phone. Enter the recovery key you saved '
              'when you set it up.\n\n'
              'Anything already on this phone is kept and joins the rest.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _key,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 15),
          decoration: InputDecoration(
            labelText: 'Recovery key',
            hintText: 'LOS-XXXX-XXXX-…',
            errorText: _error,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _unlock,
          child: const Text('Unlock'),
        ),
        const SizedBox(height: 12),
        Text(
          'Lost it? On a phone that still syncs, open Sync & account → New '
          'recovery key.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        const _SignOutButton(),
      ],
    );
  }
}

class _Ready extends ConsumerWidget {
  const _Ready({required this.status});

  final SyncStatus status;

  String _when(DateTime? at) {
    if (at == null) return 'Not synced yet';
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return 'Synced just now';
    if (ago.inHours < 1) return 'Synced ${ago.inMinutes} min ago';
    if (ago.inDays < 1) return 'Synced ${ago.inHours} h ago';
    return 'Synced ${ago.inDays} d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final controller = ref.read(syncControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status.error != null || status.uploadsRefused
                        ? LucideIcons.cloudAlert
                        : LucideIcons.cloudCheck,
                    color: status.error != null || status.uploadsRefused
                        ? colors.warm
                        : colors.accentInk,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status.syncing
                          ? 'Syncing…'
                          // Downloads ran, but nothing here went up: "synced"
                          // would be untrue.
                          : status.uploadsRefused
                          ? 'Not uploading'
                          : _when(status.lastSyncedAt),
                      style: const TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                status.email ?? '',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (status.pending > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${status.pending} change${status.pending == 1 ? '' : 's'} '
                  'waiting to upload',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              if (status.uploadsRefused) ...[
                const SizedBox(height: 10),
                Text(
                  'Sync isn\'t active on this account, so changes stay on '
                  'this phone for now. Downloads still work.',
                  style: TextStyle(color: colors.warm),
                ),
              ],
              if (status.error != null) ...[
                const SizedBox(height: 10),
                Text(status.error!, style: TextStyle(color: colors.warm)),
              ],
              if (status.skipped > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${status.skipped} record${status.skipped == 1 ? '' : 's'} '
                  'couldn\'t be read and were skipped.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: status.syncing ? null : controller.syncNow,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: const Text('Sync now'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Encrypted on this phone before upload. Insights and device '
          'settings (app lock, motion, sounds) stay on each phone.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.keyRound),
                title: const Text('New recovery key'),
                subtitle: const Text('Replaces the one you saved before'),
                onTap: () => _newRecoveryKey(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.logOut),
                title: const Text('Sign out'),
                subtitle: const Text('Your data stays on this phone'),
                onTap: () => _signOut(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(LucideIcons.trash2, color: colors.critical),
                title: Text(
                  'Delete account',
                  style: TextStyle(color: colors.critical),
                ),
                subtitle: const Text('Removes your data from the server'),
                onTap: () => _deleteAccount(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _newRecoveryKey(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(syncControllerProvider.notifier);
    final pending = controller.replacementRecoveryKey();
    final kept = await showRecoveryKeySheet(
      context,
      pending.recoveryKey,
      replacing: true,
    );
    if (!kept) return;
    try {
      await controller.saveRecoveryKey(pending);
      if (context.mounted) {
        _snack(context, 'New recovery key saved. The old one no longer works.');
      }
    } on Object {
      if (context.mounted) {
        _snack(context, "Couldn't reach the server. The old key still works.");
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your synced data, recovery key and account are removed from the '
          'server for good. Everything on this phone stays. Other phones '
          'keep their copy but stop syncing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(syncControllerProvider.notifier).deleteAccount();
      if (context.mounted) _snack(context, 'Account deleted.');
    } on Object {
      if (context.mounted) {
        _snack(context, "Couldn't reach the server. Nothing was deleted.");
      }
    }
  }
}

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'Sync stops on this phone. Everything already here stays here.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(syncControllerProvider.notifier).signOut();
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () => _signOut(context, ref),
    child: const Text('Sign out'),
  );
}

/// Shows [recoveryKey] and returns true once the person confirms they've
/// kept it. Nothing is saved until they do.
Future<bool> showRecoveryKeySheet(
  BuildContext context,
  String recoveryKey, {
  bool replacing = false,
}) async {
  final kept = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) =>
        _RecoveryKeySheet(recoveryKey: recoveryKey, replacing: replacing),
  );
  return kept ?? false;
}

class _RecoveryKeySheet extends StatefulWidget {
  const _RecoveryKeySheet({required this.recoveryKey, required this.replacing});

  final String recoveryKey;
  final bool replacing;

  @override
  State<_RecoveryKeySheet> createState() => _RecoveryKeySheetState();
}

class _RecoveryKeySheetState extends State<_RecoveryKeySheet> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your recovery key',
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.replacing
                  ? 'Keep this somewhere safe. Once saved, the old recovery key '
                        'stops working.'
                  : 'Keep this somewhere safe — a password manager, a photo, or '
                        'on paper. You\'ll need it to unlock your data on a new '
                        'phone. Nobody, including us, can recover it.',
              style: TextStyle(height: 1.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                widget.recoveryKey,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 17,
                  height: 1.5,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.recoveryKey));
                if (context.mounted) _snack(context, 'Recovery key copied.');
              },
              icon: const Icon(LucideIcons.copy, size: 16),
              label: const Text('Copy'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saved,
              onChanged: (v) => setState(() => _saved = v ?? false),
              title: const Text('I\'ve saved my recovery key'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saved ? () => Navigator.of(context).pop(true) : null,
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose a new password'),
    content: TextField(
      controller: _password,
      obscureText: true,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'New password'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_password.text),
        child: const Text('Save'),
      ),
    ],
  );
}
