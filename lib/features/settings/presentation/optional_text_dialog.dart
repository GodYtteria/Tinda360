import 'package:flutter/material.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';

Future<String?> showOptionalTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initialText,
  String? hintText,
  TextInputType? keyboardType,
}) => showDialog<String>(
  context: context,
  builder: (_) => _OptionalTextDialog(
    title: title,
    label: label,
    initialText: initialText,
    hintText: hintText,
    keyboardType: keyboardType,
  ),
);

class _OptionalTextDialog extends StatefulWidget {
  const _OptionalTextDialog({
    required this.title,
    required this.label,
    required this.initialText,
    this.hintText,
    this.keyboardType,
  });

  final String title;
  final String label;
  final String initialText;
  final String? hintText;
  final TextInputType? keyboardType;

  @override
  State<_OptionalTextDialog> createState() => _OptionalTextDialogState();
}

class _OptionalTextDialogState extends State<_OptionalTextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TindaTextInput(
        label: widget.label,
        hintText: widget.hintText,
        controller: _controller,
        keyboardType: widget.keyboardType,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.commonCancel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(localizations.commonSave),
        ),
      ],
    );
  }
}
