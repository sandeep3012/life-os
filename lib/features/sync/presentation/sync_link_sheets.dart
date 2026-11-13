import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_fonts.dart';
import '../application/sync_providers.dart';
import '../domain/sync_crypto.dart';

/// The joining phone: shows a QR code for a phone that already syncs to
/// scan, and unlocks as soon as that phone has approved it.
Future<void> showLinkQrSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LinkQrSheet(),
    );

class _LinkQrSheet extends ConsumerStatefulWidget {
  const _LinkQrSheet();

  @override
  ConsumerState<_LinkQrSheet> createState() => _LinkQrSheetState();
}

class _LinkQrSheetState extends ConsumerState<_LinkQrSheet> {
  /// The server keeps a handed-over key readable for 15 minutes.
  static const _lifetime = Duration(minutes: 14);
  static const _every = Duration(seconds: 2);

  LinkRequest? _request;
  Timer? _poll;
  DateTime? _startedAt;
  bool _looking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_begin());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _begin() async {
    final controller = ref.read(syncControllerProvider.notifier);
    final request = await controller.startLink();
    if (!mounted) return;
    setState(() {
      _request = request;
      _startedAt = DateTime.now();
      _error = null;
    });
    _poll?.cancel();
    _poll = Timer.periodic(_every, (_) => _look(controller, request));
  }

  Future<void> _look(SyncController controller, LinkRequest request) async {
    if (_looking) return;
    if (DateTime.now().difference(_startedAt!) > _lifetime) {
      _poll?.cancel();
      if (mounted) setState(() => _request = null);
      return;
    }
    _looking = true;
    try {
      if (await controller.collectLink(request)) {
        _poll?.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    } on SyncCryptoException catch (e) {
      _poll?.cancel();
      if (mounted) setState(() => _error = e.message);
    } on Object {
      // Offline for a moment: the next look tries again.
    } finally {
      _looking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final request = _request;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Approve from your other phone',
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'On a phone that already syncs, open Sync & account → Add a '
              'phone, and scan this code. This phone unlocks by itself.',
              style: TextStyle(height: 1.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // A QR code needs dark on light to scan, in either theme.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox.square(
                  dimension: 220,
                  child: request == null
                      ? Center(
                          child: _error == null && _startedAt == null
                              ? const CircularProgressIndicator()
                              : const Icon(
                                  LucideIcons.timerOff,
                                  size: 40,
                                  color: Colors.black54,
                                ),
                        )
                      : QrImageView(
                          data: request.code,
                          padding: EdgeInsets.zero,
                          semanticsLabel: 'Code for your other phone to scan',
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              )
            else if (request == null && _startedAt != null)
              Text(
                'This code has expired.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Waiting for your other phone…',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            if (_error != null || (request == null && _startedAt != null)) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: _begin, child: const Text('New code')),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone that already syncs: scans the joining phone's code and, once
/// the person confirms, hands it the key. Returns true when it did.
Future<bool> scanToAddPhone(BuildContext context) async =>
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const _ScanScreen())) ??
    false;

class _ScanScreen extends ConsumerStatefulWidget {
  const _ScanScreen();

  @override
  ConsumerState<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<_ScanScreen> {
  final _scanner = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _handling = false;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (_handling || code == null) return;
    _handling = true;
    try {
      LinkRequest.parse(code);
    } on SyncCryptoException catch (e) {
      setState(() => _error = e.message);
      _handling = false;
      return;
    }
    await _scanner.stop();
    if (!mounted) return;
    final email = ref.read(syncControllerProvider).email;
    final approve = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add this phone?'),
        content: Text(
          'The phone showing this code gets access to all your synced data'
          '${email == null ? '' : ' for $email'}. Only approve a phone you '
          'have in your hand.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add phone'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (approve != true) {
      Navigator.of(context).pop(false);
      return;
    }
    try {
      await ref.read(syncControllerProvider.notifier).approveLink(code);
      if (mounted) Navigator.of(context).pop(true);
    } on SyncCryptoException catch (e) {
      _retry(e.message);
    } on Object {
      _retry("Couldn't reach the server. Try again in a moment.");
    }
  }

  void _retry(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    _handling = false;
    unawaited(_scanner.start());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add a phone')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              'On the new phone, sign in, open Sync & account and tap '
              '"Approve from my other phone". Then scan the code it shows.',
              style: TextStyle(height: 1.5, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: MobileScanner(
                controller: _scanner,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                          ? 'LifeOS needs the camera to scan the code. Allow '
                                'it in your phone\'s settings.'
                          : "The camera couldn't start.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _error ?? ' ',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the person type their saved recovery key to make sure it still
/// works. Changes nothing.
Future<void> showCheckRecoveryKeyDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _CheckKeyDialog());

class _CheckKeyDialog extends ConsumerStatefulWidget {
  const _CheckKeyDialog();

  @override
  ConsumerState<_CheckKeyDialog> createState() => _CheckKeyDialogState();
}

class _CheckKeyDialogState extends ConsumerState<_CheckKeyDialog> {
  final _key = TextEditingController();
  bool _busy = false;
  bool? _matches;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _matches = null;
    });
    bool? matches;
    try {
      matches = await ref
          .read(syncControllerProvider.notifier)
          .checkRecoveryKey(_key.text);
    } on Object {
      matches = null;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _matches = matches;
      });
      if (matches == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't reach the server. Try again in a moment."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Check recovery key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Type the key you saved to make sure it still works.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 15),
            decoration: const InputDecoration(
              labelText: 'Recovery key',
              hintText: 'LOS-XXXX-XXXX-…',
            ),
            onChanged: (_) {
              if (_matches != null) setState(() => _matches = null);
            },
          ),
          if (_matches != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _matches! ? LucideIcons.circleCheck : LucideIcons.circleX,
                  size: 18,
                  color: _matches! ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _matches!
                        ? 'That\'s the right key. Keep it safe.'
                        : 'That key doesn\'t match. If you\'ve lost it, make '
                              'a new one.',
                    style: TextStyle(
                      color: _matches! ? scheme.primary : scheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: const Text('Check'),
        ),
      ],
    );
  }
}
