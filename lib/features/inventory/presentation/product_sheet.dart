import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/inventory/presentation/inventory_rules.dart';
import 'package:tinda360/features/inventory/presentation/inventory_screen.dart';
import 'package:tinda360/features/inventory/presentation/product_form_logic.dart';
import 'package:tinda360/features/inventory/presentation/product_sheet_extras.dart';
import 'package:tinda360/features/inventory/presentation/stock_history_sheet.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/barcode_scanner_sheet.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class ProductSheet extends ConsumerStatefulWidget {
  const new({
    super.key,
    this.existing,
    this.initialBarcode,
  });

  final StockedProduct? existing;

  final String? initialBarcode;

  static Future<void> show(
    BuildContext context, {
    StockedProduct? existing,
    String? initialBarcode,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppPalette.of(context).scrim,
    builder: (_) =>
        ProductSheet(existing: existing, initialBarcode: initialBarcode),
  );

  @override
  ConsumerState<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<ProductSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _utangPriceController;
  final TextEditingController _restockCostController = TextEditingController();
  late final TextEditingController _categoryController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _barcodeController;

  late ProductUnit _selectedUnit;
  Quantity _initialStock = Quantity.zero;
  Quantity _stockDelta = Quantity.zero;
  bool _noCount = false;
  LocalDay? _expiryDay;
  bool _isSaving = false;
  String? _inlineError;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final product = widget.existing?.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : _plainMoney(product.price),
    );
    _costController = TextEditingController(
      text: product == null ? '' : _plainMoney(product.cost),
    );
    final utangPrice = product?.utangPrice;
    _utangPriceController = TextEditingController(
      text: utangPrice == null ? '' : _plainMoney(utangPrice),
    );
    _categoryController = TextEditingController(
      text: product?.categoryId ?? '',
    );
    _lowStockController = TextEditingController(
      text: product?.lowStockAt == null
          ? ''
          : ProductFormLogic.decimalText(product!.lowStockAt!),
    );
    _barcodeController = TextEditingController(
      text: product?.barcode ?? widget.initialBarcode ?? '',
    );
    _noCount = product != null && !product.tracksStock;
    _expiryDay = product?.expiryDay;
    _selectedUnit = product?.unit ?? ProductUnit.piece;
  }

  String _plainMoney(Money money) {
    final major = money.minorUnits / money.currency.minorPerMajor;
    return major.toStringAsFixed(money.currency.exponent);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _utangPriceController.dispose();
    _restockCostController.dispose();
    _categoryController.dispose();
    _lowStockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  static const int _maxStock = 9999;

  Future<void> _editStockValue() async {
    final target = await showDialog<Quantity>(
      context: context,
      builder: (dialogContext) => _StockTargetDialog(
        startingQuantity: _isEditMode
            ? widget.existing!.stock + _stockDelta
            : _initialStock,
        allowsFraction: _selectedUnit.allowsFraction,
        maxStock: _maxStock,
        parseStockTarget: _parseStockTarget,
      ),
    );
    if (target == null || !mounted) return;
    setState(() {
      if (_isEditMode) {
        _stockDelta = target - widget.existing!.stock;
      } else {
        _initialStock = target;
      }
    });
  }

  static Quantity? _parseStockTarget(String rawInput, bool allowsFraction) {
    if (rawInput.trim().isEmpty) return Quantity.zero;
    final parsed = ProductFormLogic.parseQuantity(
      rawInput,
      allowsFraction: allowsFraction,
    );
    if (parsed == null) return null;
    const maxQuantity = Quantity.whole(_maxStock);
    return parsed.compareTo(maxQuantity) > 0 ? maxQuantity : parsed;
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    unawaited(HapticFeedback.mediumImpact());
    final currency = ref.read(storeCurrencyProvider);
    final restockCostText = _restockCostController.text.trim();
    final isRestock = _isEditMode && !_noCount && _stockDelta.isPositive;
    final usesRestockCost = isRestock && restockCostText.isNotEmpty;
    if (usesRestockCost && parseMoneyInput(restockCostText, currency) == null) {
      setState(
        () => _inlineError = AppLocalizations.of(
          context,
        ).failureProductAmountInvalid,
      );
      return;
    }
    final draft = ProductFormLogic.buildDraft(
      name: _nameController.text,
      unit: _selectedUnit,
      priceInput: _priceController.text,
      costInput: usesRestockCost ? restockCostText : _costController.text,
      currency: currency,
      categoryInput: _categoryController.text,
      barcodeInput: _barcodeController.text,
      lowStockInput: _lowStockController.text,
      initialStock: _initialStock,
      utangPriceInput: _utangPriceController.text,
      tracksStock: !_noCount,
      expiryDay: _expiryDay,
    );

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    if (_isEditMode && !_noCount && _stockDelta.isNegative) {
      final verified = await confirmStorePinIfSet(
        context,
        ref,
        title: AppLocalizations.of(context).settingsPinPromptTitle,
      );
      if (!mounted) return;
      if (!verified) {
        setState(() => _isSaving = false);
        return;
      }
    }

    final repository = ref.read(productRepositoryProvider);
    if (_isEditMode) {
      final result = await repository.update(
        widget.existing!.product.id,
        draft,
        stockChange: _noCount ? Quantity.zero : _stockDelta,
        stockReason: isRestock ? 'restock' : 'adjust',
      );
      _handleSaveResult(result);
    } else {
      final result = await repository.create(draft);
      _handleSaveResult(result);
    }
  }

  void _handleSaveResult<T>(Result<T, ProductFailure> result) {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    switch (result) {
      case Ok<T, ProductFailure>():
        Navigator.of(context).pop();
      case Err<T, ProductFailure>(:final failure):
        setState(() {
          _isSaving = false;
          _inlineError = localizedFailureMessage(localizations, failure);
        });
    }
  }

  Future<void> _confirmAndDelete() async {
    if (_isSaving || !_isEditMode) return;
    unawaited(HapticFeedback.selectionClick());
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.productDeleteButton),
        content: Text(localizations.productDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () {
              unawaited(HapticFeedback.mediumImpact());
              Navigator.of(dialogContext).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: palette.danger),
            child: Text(localizations.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final verified = await confirmStorePinIfSet(
      context,
      ref,
      title: AppLocalizations.of(context).settingsPinPromptTitle,
    );
    if (!verified || !mounted) return;

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });
    final result = await ref
        .read(productRepositoryProvider)
        .softDelete(widget.existing!.product.id);
    _handleSaveResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final currency = ref.watch(storeCurrencyProvider);
    final priceIsZero =
        parseMoneyInput(_priceController.text, currency)?.minorUnits == 0;
    final profit = ProductFormLogic.computeProfitPerSale(
      priceInput: _priceController.text,
      costInput: _costController.text,
      currency: currency,
    );

    return TindaBottomSheet(
      title: _isEditMode
          ? localizations.productSheetEditTitle
          : localizations.productSheetAddTitle,
      closeTooltip: localizations.commonClose,
      footer: TindaPrimaryButton(
        label: localizations.commonSave,
        isLoading: _isSaving,
        onPressed: _isSaving ? null : _saveProduct,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TindaTextInput(
            label: localizations.productNameLabel,
            hintText: localizations.productNameHint,
            controller: _nameController,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _inlineError = null),
          ),
          if (InventoryRules.hasDuplicateName(
            _nameController.text,
            ref.watch(inventoryProductsProvider).value ??
                const <StockedProduct>[],
            excludeProductId: widget.existing?.product.id,
          ))
            ProductFormWarning(
              message: localizations.productDuplicateNameWarning,
            ),
          const SizedBox(height: AppSpacing.s12),
          _PriceCostRow(
            priceController: _priceController,
            costController: _costController,
            onChanged: (_) => setState(() => _inlineError = null),
          ),
          if (priceIsZero)
            ProductFormWarning(message: localizations.productPriceZeroWarning),
          const SizedBox(height: AppSpacing.s12),
          TindaTextInput(
            label: localizations.productUtangPriceLabel,
            controller: _utangPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _inlineError = null),
          ),
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
            ),
            child: profit == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey<String>(
                      '${profit.minorUnits}-${profit.isNegative}',
                    ),
                    padding: const EdgeInsets.only(top: AppSpacing.s8),
                    child: Text(
                      localizations.productProfitPerSale(formatMoney(profit)),
                      style: AppTypography.meta(
                        profit.isNegative ? palette.danger : palette.success,
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.s16),
          _UnitSelector(
            selectedUnit: _selectedUnit,
            onSelected: (unit) => setState(() => _selectedUnit = unit),
          ),
          const SizedBox(height: AppSpacing.s12),
          TindaTextInput(
            label: localizations.productCategoryLabel,
            controller: _categoryController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.s16),
          ProductNoCountSwitchRow(
            noCount: _noCount,
            onChanged: (value) => setState(() => _noCount = value),
          ),
          const SizedBox(height: AppSpacing.s12),
          ProductExpiryField(
            expiryDay: _expiryDay,
            today: LocalDay.fromLocal(ref.read(clockProvider).now()),
            onChanged: (day) => setState(() => _expiryDay = day),
          ),
          if (!_noCount && _isEditMode) ...[
            const SizedBox(height: AppSpacing.s16),
            _AdjustStockSection(
              currentStock: widget.existing!.stock,
              delta: _stockDelta,
              unit: _selectedUnit,
              onValueTap: _editStockValue,
              onDecrement:
                  !(widget.existing!.stock +
                          _stockDelta -
                          const Quantity.whole(1))
                      .isNegative
                  ? () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(
                        () => _stockDelta -= const Quantity.whole(1),
                      );
                    }
                  : null,
              onIncrement:
                  (widget.existing!.stock + _stockDelta).compareTo(
                        const Quantity.whole(_maxStock),
                      ) <
                      0
                  ? () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(
                        () => _stockDelta += const Quantity.whole(1),
                      );
                    }
                  : null,
            ),
            if (_stockDelta.isPositive) ...[
              const SizedBox(height: AppSpacing.s12),
              TindaTextInput(
                label: localizations.productRestockCostLabel,
                controller: _restockCostController,
                hintText: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => _clearError(),
              ),
            ],
            const SizedBox(height: AppSpacing.s12),
            TindaSecondaryButton(
              label: localizations.productStockHistoryButton,
              icon: Icons.history_rounded,
              onPressed: () => unawaited(
                StockHistorySheet.show(context, widget.existing!.product),
              ),
            ),
          ] else if (!_noCount) ...[
            const SizedBox(height: AppSpacing.s16),
            _InitialStockSection(
              stockCount: _initialStock,
              unit: _selectedUnit,
              onValueTap: _editStockValue,
              onDecrement: _initialStock.compareTo(const Quantity.whole(1)) >= 0
                  ? () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(
                        () => _initialStock -= const Quantity.whole(1),
                      );
                    }
                  : null,
              onIncrement:
                  _initialStock.compareTo(const Quantity.whole(_maxStock)) < 0
                  ? () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(
                        () => _initialStock += const Quantity.whole(1),
                      );
                    }
                  : null,
            ),
          ],
          if (!_noCount) ...[
            const SizedBox(height: AppSpacing.s12),
            TindaTextInput(
              label: localizations.productLowStockLabel,
              controller: _lowStockController,
              keyboardType: TextInputType.numberWithOptions(
                decimal: _selectedUnit.allowsFraction,
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clearError(),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          TindaTextInput(
            label: localizations.productBarcodeLabel,
            controller: _barcodeController,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/scan_barcode.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  palette.textMuted,
                  BlendMode.srcIn,
                ),
              ),
              tooltip: localizations.posScanBarcode,
              onPressed: () async {
                unawaited(HapticFeedback.selectionClick());
                final code = await BarcodeScannerSheet.show(context);
                if (code == null || !mounted) return;
                unawaited(HapticFeedback.lightImpact());
                _barcodeController.text = code;
                _clearError();
              },
            ),
            onChanged: (_) => _clearError(),
          ),
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
            ),
            child: _inlineError == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey<String>(_inlineError!),
                    padding: const EdgeInsets.only(top: AppSpacing.s12),
                    child: Text(
                      _inlineError!,
                      style: AppTypography.meta(palette.danger, size: 13),
                    ),
                  ),
          ),
          if (_isEditMode) ...[
            const SizedBox(height: AppSpacing.s12),
            Center(
              child: TindaTextLinkButton(
                label: localizations.productDeleteButton,
                isDanger: true,
                onPressed: _isSaving ? null : _confirmAndDelete,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _clearError() {
    if (_inlineError != null) {
      setState(() => _inlineError = null);
    }
  }
}

class _PriceCostRow extends StatelessWidget {
  const new({
    required this.priceController,
    required this.costController,
    required this.onChanged,
  });

  final TextEditingController priceController;
  final TextEditingController costController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TindaTextInput(
            label: localizations.productPriceLabel,
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: TindaTextInput(
            label: localizations.productCostLabel,
            controller: costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _UnitSelector extends StatelessWidget {
  const new({
    required this.selectedUnit,
    required this.onSelected,
  });

  final ProductUnit selectedUnit;
  final ValueChanged<ProductUnit> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.productUnitLabel,
          style: AppTypography.meta(
            palette.text,
            size: 13,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final unit in ProductUnit.values)
              TindaFilterChip(
                label: localizedUnit(localizations, unit),
                selected: unit == selectedUnit,
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onSelected(unit);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _InitialStockSection extends StatelessWidget {
  const new({
    required this.stockCount,
    required this.unit,
    required this.onDecrement,
    required this.onIncrement,
    required this.onValueTap,
  });

  final Quantity stockCount;
  final ProductUnit unit;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback onValueTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            localizations.productInitialStockLabel,
            style: AppTypography.meta(
              palette.text,
              size: 13,
              weight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          flex: 2,
          child: TindaStepper(
            valueLabel:
                '${formatQuantity(stockCount, unit)} ${localizedUnit(localizations, unit)}',
            onDecrement: onDecrement,
            onIncrement: onIncrement,
            onValueTap: onValueTap,
            decrementTooltip: localizations.productStockDecrement,
            incrementTooltip: localizations.posAddToCart(
              localizedUnit(localizations, unit),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdjustStockSection extends StatelessWidget {
  const new({
    required this.currentStock,
    required this.delta,
    required this.unit,
    required this.onDecrement,
    required this.onIncrement,
    required this.onValueTap,
  });

  final Quantity currentStock;
  final Quantity delta;
  final ProductUnit unit;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback onValueTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final unitLabel = localizedUnit(localizations, unit);
    final deltaPrefix = delta.isNegative ? '-' : (delta.isPositive ? '+' : '');
    final deltaAmount = formatQuantity(delta.isNegative ? -delta : delta, unit);
    final valueLabel = '$deltaPrefix$deltaAmount $unitLabel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.productCurrentStockLabel(
            formatQuantity(currentStock, unit),
          ),
          style: AppTypography.meta(palette.textMuted, size: 13),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                localizations.productAdjustStockLabel,
                style: AppTypography.meta(
                  palette.text,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              flex: 2,
              child: TindaStepper(
                valueLabel: valueLabel,
                onDecrement: onDecrement,
                onIncrement: onIncrement,
                onValueTap: onValueTap,
                decrementTooltip: localizations.productStockDecrement,
                incrementTooltip: localizations.posAddToCart(unitLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StockTargetDialog extends StatefulWidget {
  const new({
    required this.startingQuantity,
    required this.allowsFraction,
    required this.maxStock,
    required this.parseStockTarget,
  });

  final Quantity startingQuantity;
  final bool allowsFraction;
  final int maxStock;
  final Quantity? Function(String rawInput, bool allowsFraction)
  parseStockTarget;

  @override
  State<_StockTargetDialog> createState() => _StockTargetDialogState();
}

class _StockTargetDialogState extends State<_StockTargetDialog> {
  late final TextEditingController _stockController = TextEditingController(
    text: ProductFormLogic.decimalText(widget.startingQuantity),
  );
  String? _errorMessage;

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  void _save(AppLocalizations localizations) {
    final target = widget.parseStockTarget(
      _stockController.text,
      widget.allowsFraction,
    );
    if (target == null) {
      setState(
        () => _errorMessage = localizations.failureProductQuantityInvalid,
      );
      return;
    }
    Navigator.of(context).pop(target);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.productInitialStockLabel),
      content: TextField(
        controller: _stockController,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.allowsFraction,
        ),
        inputFormatters: [
          if (widget.allowsFraction)
            FilteringTextInputFormatter.allow(RegExp('[0-9.]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: localizations.productInitialStockLabel,
          hintText: '0-${widget.maxStock}',
          errorText: _errorMessage,
        ),
        onSubmitted: (_) => _save(localizations),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.commonCancel),
        ),
        TextButton(
          onPressed: () => _save(localizations),
          child: Text(localizations.commonSave),
        ),
      ],
    );
  }
}
