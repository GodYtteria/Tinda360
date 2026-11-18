import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/store_pin_service.dart';

Future<bool> showPinPromptDialog(
  BuildContext context, {
  required String title,
  required StorePinService pinService,
  Future<bool> Function()? onAuthenticateBiometric,
  Future<bool> Function()? onResetWithGoogle,
  Future<void> Function()? onRemoveDamagedPin,
}) async {
  final dialogResult = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _PinPromptDialog(
      title: title,
      pinService: pinService,
      onAuthenticateBiometric: onAuthenticateBiometric,
      onResetWithGoogle: onResetWithGoogle,
      onRemoveDamagedPin: onRemoveDamagedPin,
    ),
  );
  return dialogResult ?? false;
}

Future<void> showRecoveryCodeDialog(
  BuildContext context, {
  required String recoveryCode,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => AlertDialog(
    title: Text(AppLocalizations.of(context).pinRecoveryTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).pinRecoveryBody,
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
            SnackBar(
              content: Text(AppLocalizations.of(context).pinRecoveryCopied),
            ),
          );
        },
        child: Text(AppLocalizations.of(context).pinCopy),
      ),
      FilledButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: Text(AppLocalizations.of(context).pinDone),
      ),
    ],
  ),
);

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
    this.onRemoveDamagedPin,
  });

  final String title;
  final StorePinService pinService;
  final Future<bool> Function()? onAuthenticateBiometric;
  final Future<bool> Function()? onResetWithGoogle;
  final Future<void> Function()? onRemoveDamagedPin;

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
  bool _isPinDamaged = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkPinDamage());
  }

  Future<void> _checkPinDamage() async {
    final damaged = await widget.pinService.isPinDamaged();
    if (!mounted || !damaged) return;
    setState(() => _isPinDamaged = true);
  }

  Future<void> _removeDamagedPin() async {
    final removeDamagedPin = widget.onRemoveDamagedPin;
    if (removeDamagedPin == null || _isVerifying) return;
    setState(() => _isVerifying = true);
    await removeDamagedPin();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

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
        _errorMessage = AppLocalizations.of(context).pinEnterFourDigits;
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

    final lockout = await widget.pinService.lockoutRemaining();
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _errorMessage = lockout == null
          ? AppLocalizations.of(context).pinIncorrect
          : _lockoutMessage(lockout);
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
    final lockout = await widget.pinService.lockoutRemaining();
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _errorMessage = lockout == null
          ? AppLocalizations.of(context).pinInvalidRecoveryCode
          : _lockoutMessage(lockout);
    });
  }

  String _lockoutMessage(Duration remaining) {
    final seconds = remaining.inSeconds + 1;
    return AppLocalizations.of(context).pinLockedOut(seconds);
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
      _errorMessage = AppLocalizations.of(context).pinBiometricFailed;
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
      _errorMessage = AppLocalizations.of(context).pinGoogleMismatch;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        _isRecoveryMode
            ? AppLocalizations.of(context).pinResetTitle
            : widget.title,
      ),
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
            if (_isPinDamaged) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).pinDamaged,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (widget.onRemoveDamagedPin != null)
                OutlinedButton.icon(
                  onPressed: _isVerifying ? null : _removeDamagedPin,
                  icon: const Icon(Icons.lock_reset),
                  label: Text(AppLocalizations.of(context).pinRemoveDamaged),
                ),
            ],
            if (widget.onAuthenticateBiometric != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isVerifying ? null : _tryBiometric,
                icon: const Icon(Icons.fingerprint),
                label: Text(AppLocalizations.of(context).pinUseBiometric),
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
                child: Text(AppLocalizations.of(context).pinForgot),
              ),
            ),
          ] else ...[
            TextField(
              controller: _recoveryController,
              focusNode: _recoveryFocusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).pinRecoveryCodeLabel,
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _submitRecoveryCode(),
            ),
            if (widget.onResetWithGoogle != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isVerifying ? null : _tryGoogleReset,
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(AppLocalizations.of(context).pinVerifyGoogle),
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
                child: Text(AppLocalizations.of(context).pinBackToPin),
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
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: _isVerifying
              ? null
              : (_isRecoveryMode ? _submitRecoveryCode : _submitPin),
          child: Text(
            _isRecoveryMode
                ? AppLocalizations.of(context).pinResetButton
                : AppLocalizations.of(context).pinUnlock,
          ),
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
        _errorMessage = AppLocalizations.of(context).pinMustBeFourDigits;
      });
      return;
    }

    if (enteredPin != confirmedPin) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).pinMismatch;
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
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).pinNewLabel,
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
              labelText: AppLocalizations.of(context).pinConfirmLabel,
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
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: _savePin,
          child: Text(AppLocalizations.of(context).commonSave),
        ),
      ],
    );
  }
}
