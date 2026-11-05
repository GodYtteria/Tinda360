import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/core/sales/sale_return_line.dart';
import 'package:tinda360/data/repositories/sale_return_providers.dart';
import 'package:tinda360/features/inventory/presentation/product_form_logic.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/bantay_name_store.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

Future<void> showSaleReturnSheet(
  BuildContext context, {
  required SaleRecord sale,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppPalette.of(context).scrim,
    builder: (_) => _SaleReturnSheet(sale: sale, messenger: messenger),
  );
}

class _SaleReturnSheet extends ConsumerStatefulWidget {
  const _SaleReturnSheet({required this.sale, required this.messenger});

  final SaleRecord sale;

  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_SaleReturnSheet> createState() => _SaleReturnSheetState();
}

class _SaleReturnSheetState extends ConsumerState<_SaleReturnSheet> {
  late final List<TextEditingController> _quantityControllers = [
    for (final _ in widget.sale.lines) TextEditingController(),
  ];
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    _reasonController.dispose();
    super.dispose();
  }

  Quantity? _enteredQuantity(int lineIndex) {
    final rawInput = _quantityControllers[lineIndex].text.trim();
    if (rawInput.isEmpty) return Quantity.zero;
    final line = widget.sale.lines[lineIndex];
    return ProductFormLogic.parseQuantity(
      rawInput,
      allowsFraction: line.unit.allowsFraction,
    );
  }

  Money _refundPreview() {
    var total = Money.zero(widget.sale.total.currency);
    for (var index = 0; index < widget.sale.lines.length; index++) {
      final quantity = _enteredQuantity(index);
      if (quantity == null || !quantity.isPositive) continue;
      total += SaleMath.lineTotal(widget.sale.lines[index].unitPrice, quantity);
    }
    return total;
  }

  Future<void> _submit(AppLocalizations localizations) async {
    if (_isSubmitting) return;
    final returnLines = <SaleReturnLine>[];
    for (var index = 0; index < widget.sale.lines.length; index++) {
      final quantity = _enteredQuantity(index);
      if (quantity == null) {
        setState(
          () => _errorMessage = localizations.failureSaleReturnQuantityInvalid,
        );
        return;
      }
      if (!quantity.isPositive) continue;
      returnLines.add(
        SaleReturnLine(
          productId: widget.sale.lines[index].productId,
          quantity: quantity,
        ),
      );
    }
    if (returnLines.isEmpty) {
      setState(
        () => _errorMessage = localizations.failureSaleReturnNothingSelected,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final verified = await confirmStorePinIfSet(
      context,
      ref,
      title: localizations.settingsPinPromptTitle,
    );
    if (!mounted) return;
    if (!verified) {
      setState(() => _isSubmitting = false);
      return;
    }
    final result = await ref
        .read(saleReturnRepositoryProvider)
        .returnItemsWithOutcome(
          widget.sale.id,
          returnLines,
          reason: _reasonController.text,
          cashierName: ref.read(bantayNameProvider).value,
        );
    switch (result) {
      case Ok(:final value):
        final message = switch ((
          value.creditedToUtang.isPositive,
          value.cashBack.isPositive,
        )) {
          (true, true) => localizations.ulatReturnSuccessUtangPartial(
            formatMoney(value.creditedToUtang),
            formatMoney(value.cashBack),
          ),
          (true, false) => localizations.ulatReturnSuccessUtang(
            formatMoney(value.creditedToUtang),
          ),
          _ => localizations.ulatReturnSuccessCash(formatMoney(value.refund)),
        };
        widget.messenger.showSnackBar(SnackBar(content: Text(message)));
        if (mounted) Navigator.of(context).pop();
      case Err(:final failure):
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = localizedFailureMessage(localizations, failure);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final hasReturnable = widget.sale.lines.any(
      (line) => line.returnableQuantity.isPositive,
    );
    return TindaBottomSheet(
      title: localizations.ulatReturnTitle,
      closeTooltip: localizations.commonClose,
      footer: hasReturnable
          ? TindaPrimaryButton(
              label: localizations.ulatReturnConfirmButton,
              isLoading: _isSubmitting,
              onPressed: () => _submit(localizations),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasReturnable)
            Text(
              localizations.ulatReturnNothingReturnable,
              style: AppTypography.meta(palette.textMuted),
            )
          else ...[
            for (var index = 0; index < widget.sale.lines.length; index++)
              if (widget.sale.lines[index].returnableQuantity.isPositive)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: _buildLineInput(localizations, palette, index),
                ),
            TindaTextInput(
              label: localizations.ulatReturnReasonLabel,
              controller: _reasonController,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    localizations.ulatReturnRefundTotal,
                    style: AppTypography.meta(palette.text),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: MoneyText(
                    _refundPreview(),
                    alignment: AlignmentDirectional.centerEnd,
                    style: AppTypography.meta(palette.text),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                _errorMessage!,
                style: AppTypography.meta(palette.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLineInput(
    AppLocalizations localizations,
    AppPalette palette,
    int index,
  ) {
    final line = widget.sale.lines[index];
    final unitLabel = localizedUnit(localizations, line.unit);
    return TindaTextInput(
      label:
          '${line.productName} (${localizations.ulatReturnAvailable('${formatQuantity(line.returnableQuantity, line.unit)} $unitLabel')})',
      controller: _quantityControllers[index],
      hintText: localizations.ulatReturnQuantityLabel,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }
}
