import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_lock_providers.dart';

enum PinSetupMode { create, change }

/// Returns `true` once a PIN has been successfully set/changed, or `null`
/// if the sheet was dismissed without completing.
Future<bool?> showPinSetupSheet(BuildContext context, {required PinSetupMode mode}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => _PinSetupSheet(mode: mode),
  );
}

enum _Step { verifyCurrent, enter, confirm }

class _PinSetupSheet extends ConsumerStatefulWidget {
  const _PinSetupSheet({required this.mode});

  final PinSetupMode mode;

  @override
  ConsumerState<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<_PinSetupSheet> {
  final _controller = TextEditingController();
  late _Step _step = widget.mode == PinSetupMode.change ? _Step.verifyCurrent : _Step.enter;
  String? _firstPin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title => switch (_step) {
    _Step.verifyCurrent => 'Enter current PIN',
    _Step.enter => 'Set a new PIN',
    _Step.confirm => 'Confirm PIN',
  };

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    final service = ref.read(appLockServiceProvider);

    if (_step == _Step.verifyCurrent) {
      final ok = await service.verifyPin(value);
      if (!ok) {
        setState(() => _error = 'Incorrect PIN');
        return;
      }
      setState(() {
        _step = _Step.enter;
        _error = null;
        _controller.clear();
      });
      return;
    }

    if (_step == _Step.enter) {
      setState(() {
        _firstPin = value;
        _step = _Step.confirm;
        _error = null;
        _controller.clear();
      });
      return;
    }

    // _Step.confirm
    if (value != _firstPin) {
      setState(() {
        _error = 'PINs didn\'t match — try again';
        _step = _Step.enter;
        _firstPin = null;
        _controller.clear();
      });
      return;
    }
    await service.setPin(value);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: InputDecoration(hintText: 'PIN', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _controller.text.trim().length >= 4 ? _submit : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
