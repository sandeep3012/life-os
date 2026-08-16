import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/app_lock_providers.dart';
import '../../application/settings_providers.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  String? _error;
  bool _checkingBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptBiometrics());
  }

  Future<void> _maybePromptBiometrics() async {
    final settings = ref.read(settingsProvider);
    if (!settings.biometricEnabled) return;
    final service = ref.read(appLockServiceProvider);
    if (!await service.canUseBiometrics()) return;
    await _tryBiometrics();
  }

  Future<void> _tryBiometrics() async {
    if (_checkingBiometrics) return;
    setState(() => _checkingBiometrics = true);
    final ok = await ref.read(appLockServiceProvider).authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _checkingBiometrics = false);
    if (ok) ref.read(isLockedProvider.notifier).unlock();
  }

  Future<void> _onDigit(String digit) async {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length < 4) return;
    final ok = await ref.read(appLockServiceProvider).verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      ref.read(isLockedProvider.notifier).unlock();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.lock_rounded, size: 40, color: colors.finance),
              const SizedBox(height: 16),
              Text('Enter PIN', style: theme.textTheme.titleLarge),
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
                        color: i < _entered.length
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: _error == null
                    ? null
                    : Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
              ),
              const Spacer(),
              _Keypad(onDigit: _onDigit, onBackspace: _onBackspace),
              const SizedBox(height: 16),
              if (settings.biometricEnabled)
                TextButton.icon(
                  onPressed: _checkingBiometrics ? null : _tryBiometrics,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Use biometrics'),
                ),
            ],
          ),
        ),
      ),
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
                          icon: const Icon(Icons.backspace_outlined),
                        )
                      : TextButton(
                          onPressed: () => onDigit(key),
                          child: Text(key, style: Theme.of(context).textTheme.headlineSmall),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}
