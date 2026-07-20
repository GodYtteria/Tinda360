import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:tinda360/services/store_pin_service.dart';

/// Prompts the user to enter their 4-digit store PIN and verifies it against
/// [pinService], with optional biometric unlock and recovery-code / Google reset.
///
/// Returns `true` if unlocked or reset, or `false` if cancelled.
Future<bool> showPinPromptDialog(
  BuildContext context, {
  required String title,
  required StorePinService pinService,
  Future<bool> Function()? onAuthenticateBiometric,
  Future<bool> Function()? onResetWithGoogle,
}) async {
  final dialogResult = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _PinPromptDialog(
      title: title,
      pinService: pinService,
      onAuthenticateBiometric: onAuthenticateBiometric,
      onResetWithGoogle: onResetWithGoogle,
    ),
  );
  return dialogResult ?? false;
}

/// Shows the generated one-time recovery code with a Copy button.
Future<void> showRecoveryCodeDialog(
  BuildContext context, {
  required String recoveryCode,
}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Your Recovery Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Write down or copy this one-time code. You can use it to reset your PIN if you forget it offline.',
            ),
            const SizedBox(height: 12),
            SelectableText(
              recoveryCode,
              textAlign: TextAlign.center,
              style: Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recoveryCode));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Recovery code copied.')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );

/// Prompts the user to enter and confirm a new 4-digit store PIN.
///
/// Returns the validated 4-digit PIN string, or `null` if cancelled.
Future<String?> showSetPinDialog(
  BuildContext context, {
  required String title,
}) {
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _SetPinDialog(title: title),
  );
}

final class _PinPromptDialog extends StatefulWidget {
  const new({
    required this.title,
    required this.pinService,
    this.onAuthenticateBiometric,
    this.onResetWithGoogle,
  });

  final String title;
  final StorePinService pinService;
  final Future<bool> Function()? onAuthenticateBiometric;
  final Future<bool> Function()? onResetWithGoogle;

  @override
  State<_PinPromptDialog> createState() => _PinPromptDialogState();
}

final class _PinPromptDialogState extends State<_PinPromptDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _recoveryController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final FocusNode _recoveryFocusNode = FocusNode();
  String? _errorMessage;
  bool _isVerifying = false;
  bool _isRecoveryMode = false;

  @override
  void dispose() {
    _pinController.dispose();
    _recoveryController.dispose();
    _pinFocusNode.dispose();
    _recoveryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    if (_isVerifying) {
      return;
    }

    final enteredPin = _pinController.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(enteredPin)) {
      setState(() {
        _errorMessage = 'Enter a 4-digit PIN.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final isMatch = await widget.pinService.verifyPin(enteredPin);
    if (!mounted) {
      return;
    }

    if (isMatch) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isVerifying = false;
      _errorMessage = 'Incorrect PIN. Try again.';
    });
  }

  Future<void> _submitRecoveryCode() async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
    final resetOk = await widget.pinService.resetWithRecoveryCode(
      _recoveryController.text,
    );
    if (!mounted) return;
    if (resetOk) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isVerifying = false;
      _errorMessage = 'Invalid recovery code.';
    });
  }

  Future<void> _tryBiometric() async {
    final handler = widget.onAuthenticateBiometric;
    if (handler == null || _isVerifying) return;
    setState(() => _isVerifying = true);
    final unlocked = await handler();
    if (!mounted) return;
    if (unlocked) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isVerifying = false;
      _errorMessage = 'Biometric unlock failed or cancelled.';
    });
  }

  Future<void> _tryGoogleReset() async {
    final handler = widget.onResetWithGoogle;
    if (handler == null || _isVerifying) return;
    setState(() => _isVerifying = true);
    final verified = await handler();
    if (!mounted) return;
    if (verified) {
      await widget.pinService.clearPin();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isVerifying = false;
      _errorMessage = 'Google account did not match.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(_isRecoveryMode ? 'Reset Store PIN' : widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isRecoveryMode) ...[
            TextField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              autofocus: true,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: '4-digit PIN',
                counterText: '',
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _submitPin(),
            ),
            if (widget.onAuthenticateBiometric != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isVerifying ? null : _tryBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use Fingerprint / Screen Lock'),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isVerifying
                    ? null
                    : () {
                        setState(() {
                          _isRecoveryMode = true;
                          _errorMessage = null;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _recoveryFocusNode.requestFocus();
                          }
                        });
                      },
                child: const Text('Forgot PIN?'),
              ),
            ),
          ] else ...[
            TextField(
              controller: _recoveryController,
              focusNode: _recoveryFocusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Recovery code (e.g. T360-XXXX)',
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _submitRecoveryCode(),
            ),
            if (widget.onResetWithGoogle != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isVerifying ? null : _tryGoogleReset,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Verify with Google Account'),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _isVerifying
                    ? null
                    : () {
                        setState(() {
                          _isRecoveryMode = false;
                          _errorMessage = null;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _pinFocusNode.requestFocus();
                          }
                        });
                      },
                child: const Text('Back to PIN'),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerifying
              ? null
              : (_isRecoveryMode ? _submitRecoveryCode : _submitPin),
          child: Text(_isRecoveryMode ? 'Reset PIN' : 'Unlock'),
        ),
      ],
    );
  }
}

final class _SetPinDialog extends StatefulWidget {
  const new({required this.title});

  final String title;

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

final class _SetPinDialogState extends State<_SetPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _savePin() {
    final enteredPin = _pinController.text.trim();
    final confirmedPin = _confirmPinController.text.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(enteredPin)) {
      setState(() {
        _errorMessage = 'PIN must be exactly 4 digits.';
      });
      return;
    }

    if (enteredPin != confirmedPin) {
      setState(() {
        _errorMessage = 'PINs do not match.';
      });
      return;
    }

    Navigator.of(context).pop(enteredPin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'New 4-digit PIN',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPinController,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: 'Confirm 4-digit PIN',
              counterText: '',
              errorText: _errorMessage,
            ),
            onSubmitted: (_) => _savePin(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _savePin,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
