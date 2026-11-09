import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/inventory/presentation/product_form_logic.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

Future<void> askAndSetCartQuantity(
  BuildContext context, {
  required PosCartNotifier cartNotifier,
  required StockedProduct stocked,
  required Quantity currentQuantity,
  Money? unitPrice,
}) async {
  final typedQuantity = await showCartQuantityDialog(
    context,
    stocked: stocked,
    currentQuantity: currentQuantity,
    unitPrice: unitPrice,
  );
  if (typedQuantity == null || !context.mounted) return;
  final accepted = cartNotifier.setQuantity(
    stocked.product.id,
    typedQuantity,
    available: stocked.sellCap,
  );
  if (accepted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppLocalizations.of(context).posOutOfStock(stocked.product.name),
      ),
    ),
  );
}

Future<Quantity?> showCartQuantityDialog(
  BuildContext context, {
  required StockedProduct stocked,
  required Quantity currentQuantity,
  Money? unitPrice,
}) {
  return showDialog<Quantity>(
    context: context,
    builder: (dialogContext) => _CartQuantityDialog(
      stocked: stocked,
      currentQuantity: currentQuantity,
      unitPrice: unitPrice,
    ),
  );
}

({Quantity? quantity, String? errorMessage}) validateCartQuantityInput(
  String rawInput, {
  required StockedProduct stocked,
  required AppLocalizations localizations,
}) {
  final quantity = rawInput.trim().isEmpty
      ? null
      : ProductFormLogic.parseQuantity(
          rawInput,
          allowsFraction: stocked.product.unit.allowsFraction,
        );
  if (quantity == null) {
    return (
      quantity: null,
      errorMessage: localizations.failureSaleQuantityInvalid,
    );
  }
  if (quantity.compareTo(stocked.sellCap) > 0) {
    return (
      quantity: null,
      errorMessage: localizations.posOutOfStock(stocked.product.name),
    );
  }
  return (quantity: quantity, errorMessage: null);
}

class _CartQuantityDialog extends StatefulWidget {
  const new({
    required this.stocked,
    required this.currentQuantity,
    this.unitPrice,
  });

  final StockedProduct stocked;
  final Quantity currentQuantity;
  final Money? unitPrice;

  Money get effectiveUnitPrice => unitPrice ?? stocked.product.price;

  @override
  State<_CartQuantityDialog> createState() => _CartQuantityDialogState();
}

class _CartQuantityDialogState extends State<_CartQuantityDialog> {
  late final String _startingText = ProductFormLogic.decimalText(
    widget.currentQuantity,
  );
  late final TextEditingController _quantityController =
      TextEditingController(
          text: _startingText,
        )
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: _startingText.length,
        );
  String? _errorMessage;
  bool _amountMode = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _selectMode(bool amountMode) {
    if (amountMode == _amountMode) return;
    setState(() {
      _amountMode = amountMode;
      _errorMessage = null;
      _quantityController.text = amountMode
          ? ''
          : ProductFormLogic.decimalText(widget.currentQuantity);
    });
  }

  void _submit(AppLocalizations localizations) {
    if (_amountMode) {
      final amountQuantity = quantityForAmount(
        _quantityController.text,
        unitPrice: widget.effectiveUnitPrice,
        stock: widget.stocked.sellCap,
      );
      if (amountQuantity == null) {
        setState(
          () => _errorMessage = localizations.failureSaleQuantityInvalid,
        );
        return;
      }
      Navigator.of(context).pop(amountQuantity);
      return;
    }
    final validation = validateCartQuantityInput(
      _quantityController.text,
      stocked: widget.stocked,
      localizations: localizations,
    );
    if (validation.quantity == null) {
      setState(() => _errorMessage = validation.errorMessage);
      return;
    }
    Navigator.of(context).pop(validation.quantity);
  }

  String _stockHelperText(AppLocalizations localizations) {
    final stocked = widget.stocked;
    if (!stocked.tracksStock) return localizations.inventoryNoCountLabel;
    return localizations.posStockLabel(
      formatQuantity(stocked.stock, stocked.product.unit),
    );
  }

  String _amountHelperText(AppLocalizations localizations) {
    final product = widget.stocked.product;
    final computed = quantityForAmount(
      _quantityController.text,
      unitPrice: widget.effectiveUnitPrice,
      stock: widget.stocked.sellCap,
    );
    if (computed == null) {
      return _stockHelperText(localizations);
    }
    return localizations.posAmountEquals(
      formatQuantity(computed, product.unit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final product = widget.stocked.product;
    final allowsFraction = product.unit.allowsFraction;
    return AlertDialog(
      scrollable: true,
      title: Text(product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allowsFraction)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(localizations.posQuantityMode),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    enabled: widget.effectiveUnitPrice.isPositive,
                    label: Text(localizations.posAmountMode),
                  ),
                ],
                selected: {_amountMode},
                onSelectionChanged: (selection) => _selectMode(selection.first),
              ),
            ),
          TextField(
            key: const Key('cartQuantityField'),
            controller: _quantityController,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: allowsFraction,
            ),
            inputFormatters: [
              if (allowsFraction)
                FilteringTextInputFormatter.allow(RegExp('[0-9.]'))
              else
                FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: _amountMode ? (_) => setState(() {}) : null,
            decoration: InputDecoration(
              suffixText: _amountMode
                  ? '₱'
                  : localizedUnit(localizations, product.unit),
              helperText: _amountMode
                  ? _amountHelperText(localizations)
                  : _stockHelperText(localizations),
              errorText: _errorMessage,
            ),
            onSubmitted: (_) => _submit(localizations),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.commonCancel),
        ),
        TextButton(
          onPressed: () => _submit(localizations),
          child: Text(localizations.commonSave),
        ),
      ],
    );
  }
}

Quantity? quantityForAmount(
  String rawAmount, {
  required Money unitPrice,
  required Quantity stock,
}) {
  if (!unitPrice.isPositive) return null;
  final currency = unitPrice.currency;
  final pattern = RegExp('^\\d{1,7}(\\.\\d{1,${currency.exponent}})?\$');
  final trimmed = rawAmount.trim();
  if (!pattern.hasMatch(trimmed)) return null;
  final parts = trimmed.split('.');
  final fractionText = (parts.length > 1 ? parts[1] : '').padRight(
    currency.exponent,
    '0',
  );
  final amountMinor =
      int.parse(parts[0]) * currency.minorPerMajor +
      (fractionText.isEmpty ? 0 : int.parse(fractionText));
  final computedMilli =
      amountMinor * Quantity.milliPerUnit ~/ unitPrice.minorUnits;
  final cappedMilli = computedMilli < stock.milli ? computedMilli : stock.milli;
  if (cappedMilli <= 0) return null;
  return Quantity.milli(cappedMilli);
}
