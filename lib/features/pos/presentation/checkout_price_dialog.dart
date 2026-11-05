import 'package:flutter/material.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';

typedef LinePriceChoice = ({Money? price});

Money? parseLinePriceInput(String rawInput, Money normalPrice) {
  final parsed = parseMoneyInput(rawInput, normalPrice.currency);
  if (parsed == null || parsed.isNegative) return null;
  return parsed;
}

Future<LinePriceChoice?> showLinePriceDialog(
  BuildContext context, {
  required String productName,
  required Money normalPrice,
  required Money? currentOverride,
}) {
  return showDialog<LinePriceChoice>(
    context: context,
    builder: (_) => _LinePriceDialog(
      productName: productName,
      normalPrice: normalPrice,
      currentOverride: currentOverride,
    ),
  );
}

class _LinePriceDialog extends StatefulWidget {
  const _LinePriceDialog({
    required this.productName,
    required this.normalPrice,
    required this.currentOverride,
  });

  final String productName;
  final Money normalPrice;
  final Money? currentOverride;

  @override
  State<_LinePriceDialog> createState() => _LinePriceDialogState();
}

class _LinePriceDialogState extends State<_LinePriceDialog> {
  late final TextEditingController _priceController = TextEditingController(
    text: _plainAmount(widget.currentOverride ?? widget.normalPrice),
  );
  String? _errorMessage;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  String _plainAmount(Money money) => formatMoney(money).replaceFirst('₱', '');

  void _submit(AppLocalizations localizations) {
    final price = parseLinePriceInput(
      _priceController.text,
      widget.normalPrice,
    );
    if (price == null) {
      setState(() => _errorMessage = localizations.checkoutPriceInvalid);
      return;
    }
    Navigator.of(context).pop((price: price));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(localizations.checkoutPriceDialogTitle(widget.productName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.checkoutPriceNormal(
              formatMoney(widget.normalPrice),
            ),
          ),
          const SizedBox(height: 12),
          TindaTextInput(
            label: localizations.checkoutPriceLabel,
            controller: _priceController,
            errorText: _errorMessage,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _errorMessage = null),
            onSubmitted: (_) => _submit(localizations),
          ),
        ],
      ),
      actions: [
        if (widget.currentOverride != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop((price: null)),
            child: Text(localizations.checkoutPriceReset),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.commonCancel),
        ),
        FilledButton(
          onPressed: () => _submit(localizations),
          child: Text(localizations.commonSave),
        ),
      ],
    );
  }
}
