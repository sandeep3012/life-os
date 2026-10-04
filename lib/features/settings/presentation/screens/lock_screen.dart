import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../application/app_lock_providers.dart';
import '../../application/settings_providers.dart';
import '../../../../app/transitions/screen_reveal.dart';

/// What the lock screen is asking for.
enum _Mode {
  /// An app PIN exists: the keypad.
  pin,

  /// No PIN, but the phone has a screen lock: ask the OS.
  device,

  /// No PIN and no phone lock — nothing to check against. Offers to set a PIN.
  noLock,

  /// Choosing that PIN.
  createPin,
}

/// The screen over the app while it is locked.
///
/// Unlocking is the phone's own lock (Face ID, fingerprint, or the phone's
/// passcode / PIN / pattern) or, if one is set, the app PIN. This sits above the
/// app's Navigator, so it can't open sheets or dialogs — anything it needs (the
/// PIN keypad, setting a PIN) is drawn right here.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  String? _error;
  bool _busy = false;

  final _unlockButtonKey = GlobalKey(debugLabel: 'unlock button');

  /// "Use PIN instead" was tapped on the phone-lock screen.
  bool _usePin = false;

  /// Set while choosing a new PIN: the first entry, kept until it is confirmed.
  bool _creatingPin = false;
  String? _firstPin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptOnOpen());
  }

  /// Asks the OS straight away when that is how this screen unlocks: the phone
  /// lock is switched on, or there is no PIN to fall back on.
  Future<void> _promptOnOpen() async {
    final service = ref.read(appLockServiceProvider);
    final hasPin = await service.hasPin();
    if (!ref.read(settingsProvider).biometricEnabled && hasPin) return;
    if (!await service.canUseDeviceAuth()) return;
    await _tryDevice();
  }

  Future<void> _tryDevice() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(appLockServiceProvider)
        .authenticateWithDevice();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case DeviceAuthResult.success:
        _unlock();
      case DeviceAuthResult.cancelled:
        break; // They backed out; the button and the keypad are still here.
      case DeviceAuthResult.unavailable:
        // The phone lock went away; re-read what's possible.
        ref.invalidate(canUseDeviceAuthProvider);
      case DeviceAuthResult.lockedOut:
        setState(() => _error = 'Too many attempts. Try again in a moment.');
      case DeviceAuthResult.error:
        setState(() => _error = "Couldn't unlock. Try again.");
    }
  }

  Future<void> _onDigit(String digit, _Mode mode) async {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length < 4) return;
    if (mode == _Mode.createPin) return; // Confirmed with the button.
    final ok = await ref.read(appLockServiceProvider).verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else if (_entered.length >= 6) {
      setState(() {
        _error = 'Incorrect PIN';
        _entered = '';
      });
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  /// "Next" / "Set PIN" while choosing a PIN: first entry, then the repeat.
  Future<void> _submitNewPin() async {
    if (_entered.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    if (_firstPin == null) {
      setState(() {
        _firstPin = _entered;
        _entered = '';
        _error = null;
      });
      return;
    }
    if (_entered != _firstPin) {
      setState(() {
        _error = "PINs don't match. Start again.";
        _firstPin = null;
        _entered = '';
      });
      return;
    }
    final service = ref.read(appLockServiceProvider);
    await service.setPin(_entered);
    // There is no phone lock to use any more, so the PIN is now the only way in.
    await ref.read(settingsControllerProvider).setBiometricEnabled(false);
    ref.invalidate(hasPinProvider);
    if (!mounted) return;
    _unlock();
  }

  /// Opens the app in a circle from the unlock button — or from the middle of
  /// the screen when the PIN pad was the way in.
  void _unlock() {
    final button = _unlockButtonKey.currentContext;
    ScreenReveal.run(
      style: revealStyleOf(context, ref, RevealStyle.circle),
      origin: button == null ? null : globalCenterOf(button),
      change: () => ref.read(isLockedProvider.notifier).unlock(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = ref.watch(hasPinProvider).value;
    final deviceAvailable = ref.watch(canUseDeviceAuthProvider).value;
    final settings = ref.watch(settingsProvider);

    // A beat while the two answers load, rather than flashing the wrong screen.
    if (hasPin == null || deviceAvailable == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    // With the phone lock switched on it leads, as in other apps; the PIN is
    // the fallback a tap away rather than the screen you land on.
    final phoneLockFirst =
        deviceAvailable && (!hasPin || settings.biometricEnabled);
    final mode = _creatingPin
        ? _Mode.createPin
        : phoneLockFirst && !_usePin
        ? _Mode.device
        : hasPin
        ? _Mode.pin
        : _Mode.noLock;
    final deviceButton =
        mode == _Mode.pin && settings.biometricEnabled && deviceAvailable;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: switch (mode) {
            _Mode.device => _DeviceView(
              buttonKey: _unlockButtonKey,
              busy: _busy,
              error: _error,
              onUnlock: _tryDevice,
              onUsePin: hasPin
                  ? () => setState(() {
                      _usePin = true;
                      _error = null;
                    })
                  : null,
            ),
            _Mode.noLock => _NoLockView(
              onSetPin: () => setState(() => _creatingPin = true),
            ),
            _ => _PinView(
              title: mode == _Mode.createPin
                  ? (_firstPin == null ? 'Choose a PIN' : 'Confirm your PIN')
                  : 'Enter PIN',
              entered: _entered,
              error: _error,
              onDigit: (d) => _onDigit(d, mode),
              onBackspace: _onBackspace,
              action: mode == _Mode.createPin
                  ? FilledButton(
                      onPressed: _submitNewPin,
                      child: Text(_firstPin == null ? 'Next' : 'Set PIN'),
                    )
                  : deviceButton
                  ? TextButton.icon(
                      key: _unlockButtonKey,
                      onPressed: _busy ? null : _tryDevice,
                      icon: const Icon(LucideIcons.scanFace),
                      label: const Text('Unlock with phone lock'),
                    )
                  : null,
            ),
          },
        ),
      ),
    );
  }
}

/// No app PIN: the phone's own lock is the way in.
class _DeviceView extends StatelessWidget {
  const _DeviceView({
    required this.buttonKey,
    required this.busy,
    required this.error,
    required this.onUnlock,
    this.onUsePin,
  });

  final Key buttonKey;
  final bool busy;
  final String? error;
  final VoidCallback onUnlock;

  /// Offered when there's an app PIN to fall back on.
  final VoidCallback? onUsePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      children: [
        const Spacer(),
        Icon(LucideIcons.lock, size: 40, color: colors.finance),
        const SizedBox(height: 16),
        Text('LifeOS is locked', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          "Unlock with your phone's Face ID, fingerprint or passcode.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(
          height: 36,
          child: error == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: buttonKey,
            onPressed: busy ? null : onUnlock,
            icon: const Icon(LucideIcons.scanFace),
            label: const Text('Unlock'),
          ),
        ),
        if (onUsePin != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onUsePin,
            child: const Text('Use PIN instead'),
          ),
        ],
      ],
    );
  }
}

/// No app PIN and no phone lock: nothing to check against, so say so and offer
/// the one thing that restores protection.
class _NoLockView extends StatelessWidget {
  const _NoLockView({required this.onSetPin});

  final VoidCallback onSetPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      children: [
        const Spacer(),
        Icon(LucideIcons.lockOpen, size: 40, color: colors.finance),
        const SizedBox(height: 16),
        Text('No phone lock is set', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          "LifeOS can't use your phone's lock because there isn't one. "
          'Set an app PIN to keep your data protected.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSetPin,
            child: const Text('Set an app PIN'),
          ),
        ),
      ],
    );
  }
}

/// The PIN dots and keypad, with one optional action under them.
class _PinView extends StatelessWidget {
  const _PinView({
    required this.title,
    required this.entered,
    required this.error,
    required this.onDigit,
    required this.onBackspace,
    required this.action,
  });

  final String title;
  final String entered;
  final String? error;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      children: [
        const Spacer(),
        Icon(LucideIcons.lock, size: 40, color: colors.finance),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 6; i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < entered.length
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: error == null
              ? null
              : Text(error!, style: TextStyle(color: theme.colorScheme.error)),
        ),
        const Spacer(),
        _Keypad(onDigit: onDigit, onBackspace: onBackspace),
        const SizedBox(height: 16),
        ?action,
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row)
                SizedBox(
                  width: 72,
                  height: 64,
                  child: key.isEmpty
                      ? const SizedBox.shrink()
                      : key == '⌫'
                      ? IconButton(
                          onPressed: onBackspace,
                          icon: const Icon(LucideIcons.delete),
                        )
                      : TextButton(
                          onPressed: () => onDigit(key),
                          child: Text(
                            key,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}
