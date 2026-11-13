import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_fonts.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/tappable.dart';
import '../../auth/application/sync_auth_providers.dart';
import '../application/sync_providers.dart';
import '../domain/sync_crypto.dart';
import 'sync_link_sheets.dart';

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
          style: TextStyle(
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

  /// Standard recovery unless the person picks Maximum privacy.
  bool _serverRecovery = true;

  Future<void> _start() async {
    final controller = ref.read(syncControllerProvider.notifier);
    final pending = controller.newAccountKeys();
    // Standard recovery doesn't need a recovery key to be kept: signing in
    // is the way back. One can be made later from Sync & account.
    if (!_serverRecovery) {
      final kept = await showRecoveryKeySheet(context, pending.recoveryKey);
      if (!kept || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await controller.saveRecoveryKey(
        pending,
        serverRecovery: _serverRecovery,
      );
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
              'Your data is encrypted on this phone before it\'s uploaded. '
              'Choose how you\'d get it back if you lose this phone.',
        ),
        const SizedBox(height: 20),
        RecoveryModeChoice(
          serverRecovery: _serverRecovery,
          onChanged: _busy
              ? null
              : (value) => setState(() => _serverRecovery = value),
        ),
        const SizedBox(height: 10),
        Text(
          'You can change this later in Sync & account.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _start,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _serverRecovery ? 'Turn on sync' : 'Create my recovery key',
                ),
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
              'syncs from another phone. Approve this phone from that one, '
              'or enter the recovery key you saved when you set it up.\n\n'
              'Anything already on this phone is kept and joins the rest.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : () => showLinkQrSheet(context),
          icon: const Icon(LucideIcons.qrCode, size: 18),
          label: const Text('Approve from my other phone'),
        ),
        const SizedBox(height: 20),
        Text(
          'Or use your recovery key',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
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
        OutlinedButton(
          onPressed: _busy ? null : _unlock,
          child: const Text('Unlock with recovery key'),
        ),
        const SizedBox(height: 12),
        Text(
          'Lost the key and no other phone? On a phone that still syncs, '
          'open Sync & account → New recovery key.',
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
                      style: TextStyle(
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
        if (status.keyBackedUpTo case final where?) ...[
          const SizedBox(height: 8),
          Text(
            'Your key is also saved in $where, so a new phone signed in '
            'there unlocks without the recovery key.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.smartphone),
                title: const Text('Add a phone'),
                subtitle: const Text('Scan the code your new phone shows'),
                onTap: () async {
                  if (await scanToAddPhone(context) && context.mounted) {
                    _snack(context, 'Approved. The new phone unlocks now.');
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.lifeBuoy),
                title: const Text('Recovery'),
                subtitle: Text(switch (status.serverRecovery) {
                  true => 'Standard · signing in gets your data back',
                  false => 'Maximum privacy · only your key and phones',
                  null => 'Checking…',
                }),
                onTap: status.serverRecovery == null
                    ? null
                    : () =>
                          _changeRecovery(context, ref, status.serverRecovery!),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.shieldCheck),
                title: const Text('Check recovery key'),
                subtitle: const Text('Make sure the one you saved still works'),
                onTap: () => showCheckRecoveryKeyDialog(context),
              ),
              const Divider(height: 1),
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

  Future<void> _changeRecovery(
    BuildContext context,
    WidgetRef ref,
    bool current,
  ) async {
    final controller = ref.read(syncControllerProvider.notifier);
    final wanted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecoveryModeSheet(serverRecovery: current),
    );
    if (wanted == null || wanted == current || !context.mounted) return;
    try {
      if (wanted) {
        await controller.setServerRecovery(true);
        if (context.mounted) {
          _snack(
            context,
            'Standard recovery on. Signing in gets your data back.',
          );
        }
        return;
      }
      // Maximum privacy leaves the recovery key as the last way back, so
      // one has to be saved first — Standard setups never showed one.
      final pending = controller.replacementRecoveryKey();
      final kept = await showRecoveryKeySheet(
        context,
        pending.recoveryKey,
        replacing: true,
      );
      if (!kept) return;
      await controller.saveRecoveryKey(pending);
      await controller.setServerRecovery(false);
      if (context.mounted) {
        _snack(context, 'Maximum privacy on. The server\'s copy is deleted.');
      }
    } on Object {
      if (context.mounted) {
        _snack(context, "Couldn't reach the server. Nothing was changed.");
      }
    }
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

/// Standard recovery or Maximum privacy, as two cards to pick from.
class RecoveryModeChoice extends StatelessWidget {
  const RecoveryModeChoice({
    super.key,
    required this.serverRecovery,
    required this.onChanged,
  });

  final bool serverRecovery;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ModeCard(
        selected: serverRecovery,
        icon: LucideIcons.lifeBuoy,
        title: 'Standard',
        body:
            'Sign in on any phone and your data comes back, even if you '
            'lose every phone. LifeOS keeps a protected copy of your key, '
            'so in principle we could read your data.',
        onTap: onChanged == null ? null : () => onChanged!(true),
      ),
      const SizedBox(height: 10),
      _ModeCard(
        selected: !serverRecovery,
        icon: LucideIcons.lockKeyhole,
        title: 'Maximum privacy',
        body:
            'Only your phones and a recovery key you keep can unlock your '
            'data — nobody else, including us. Lose them all and your synced '
            'data is gone for good.',
        onTap: onChanged == null ? null : () => onChanged!(false),
      ),
    ],
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tappable(
      selected: selected,
      onTap: onTap,
      haptic: TapHaptic.selection,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? scheme.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: 20,
              color: selected ? scheme.primary : scheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sync & account → Recovery: pick a mode; returns the choice.
class _RecoveryModeSheet extends StatefulWidget {
  const _RecoveryModeSheet({required this.serverRecovery});

  final bool serverRecovery;

  @override
  State<_RecoveryModeSheet> createState() => _RecoveryModeSheetState();
}

class _RecoveryModeSheetState extends State<_RecoveryModeSheet> {
  late bool _serverRecovery = widget.serverRecovery;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recovery',
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          RecoveryModeChoice(
            serverRecovery: _serverRecovery,
            onChanged: (value) => setState(() => _serverRecovery = value),
          ),
          if (widget.serverRecovery && !_serverRecovery) ...[
            const SizedBox(height: 12),
            Text(
              'You\'ll save a new recovery key first; then the server\'s copy '
              'is deleted.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _serverRecovery == widget.serverRecovery
                ? null
                : () => Navigator.of(context).pop(_serverRecovery),
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
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
            Text(
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
                  : 'Keep this somewhere safe — a password manager, your '
                        'notes, an email to yourself, or on paper. You\'ll need '
                        'it only if you lose every phone and your phone\'s '
                        'backup. Nobody, including us, can recover it.',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: widget.recoveryKey),
                    );
                    if (context.mounted) {
                      _snack(context, 'Recovery key copied.');
                    }
                  },
                  icon: const Icon(LucideIcons.copy, size: 16),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                // Drive, Notes, email, a password manager — whatever the
                // phone offers.
                TextButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      subject: 'LifeOS recovery key',
                      text:
                          'LifeOS recovery key\n${widget.recoveryKey}\n\n'
                          'Unlocks your synced LifeOS data on a new phone. '
                          'Keep it private.',
                    ),
                  ),
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: const Text('Save to…'),
                ),
              ],
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
