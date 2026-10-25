import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/inventory/presentation/product_form_logic.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/barcode_scanner_sheet.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Bottom sheet for adding a new product or editing/deleting an existing one.
class ProductSheet extends ConsumerStatefulWidget {
  /// Creates the product sheet. Pass [existing] to open in edit mode.
  const ProductSheet({
    super.key,
    this.existing,
  });

  /// Existing stocked product when editing; null when adding.
  final StockedProduct? existing;

  @override
  ConsumerState<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<ProductSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _categoryController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _barcodeController;

  late ProductUnit _selectedUnit;
  int _initialStockWhole = 0;
  int _stockDeltaWhole = 0;
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
    _categoryController = TextEditingController(
      text: product?.categoryId ?? '',
    );
    _lowStockController = TextEditingController(
      text: product?.lowStockAt == null
          ? ''
          : (product!.lowStockAt!.milli ~/ Quantity.milliPerUnit).toString(),
    );
    _barcodeController = TextEditingController(text: product?.barcode ?? '');
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
    _categoryController.dispose();
    _lowStockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  static const int _maxStock = 9999;

  Future<void> _editStockValue() async {
    final localizations = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: (_isEditMode
              ? (widget.existing!.stock.milli ~/ Quantity.milliPerUnit) +
                  _stockDeltaWhole
              : _initialStockWhole)
          .toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.productInitialStockLabel),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: localizations.productInitialStockLabel,
            hintText: '0-$_maxStock',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.of(dialogContext).pop(parsed.clamp(0, _maxStock));
            },
            child: Text(localizations.commonSave),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() {
      if (_isEditMode) {
        _stockDeltaWhole =
            value - (widget.existing!.stock.milli ~/ Quantity.milliPerUnit);
      } else {
        _initialStockWhole = value;
      }
    });
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    unawaited(HapticFeedback.mediumImpact());
    final currency = ref.read(storeCurrencyProvider);
    final draft = ProductFormLogic.buildDraft(
      name: _nameController.text,
      unit: _selectedUnit,
      priceInput: _priceController.text,
      costInput: _costController.text,
      currency: currency,
      categoryInput: _categoryController.text,
      barcodeInput: _barcodeController.text,
      lowStockInput: _lowStockController.text,
      initialStock: Quantity.whole(_initialStockWhole),
    );

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    final repository = ref.read(productRepositoryProvider);
    if (_isEditMode) {
      final productId = widget.existing!.product.id;
      final updateResult = await repository.update(productId, draft);
      switch (updateResult) {
        case Ok<void, ProductFailure>():
          if (_stockDeltaWhole != 0) {
            final adjustResult = await repository.adjustStock(
              productId,
              Quantity.whole(_stockDeltaWhole),
            );
            _handleSaveResult(adjustResult);
            return;
          }
          _handleSaveResult(updateResult);
        case Err<void, ProductFailure>():
          _handleSaveResult(updateResult);
      }
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
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: AppSpacing.s12),
          _PriceCostRow(
            priceController: _priceController,
            costController: _costController,
            onChanged: (_) => setState(() => _inlineError = null),
          ),
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
            ),
            child: profit == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey<String>('${profit.minorUnits}-${profit.isNegative}'),
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
          if (_isEditMode) ...[
            const SizedBox(height: AppSpacing.s16),
            _AdjustStockSection(
              currentStock: widget.existing!.stock,
              deltaWhole: _stockDeltaWhole,
              unit: _selectedUnit,
              onValueTap: _editStockValue,
              onDecrement: widget.existing!.stock.milli +
                          (_stockDeltaWhole - 1) * Quantity.milliPerUnit >=
                      0
                  ? () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() => _stockDeltaWhole--);
                    }
                  : null,
              onIncrement:
                  (widget.existing!.stock.milli ~/ Quantity.milliPerUnit) +
                              _stockDeltaWhole <
                          _maxStock
                      ? () {
                          unawaited(HapticFeedback.selectionClick());
                          setState(() => _stockDeltaWhole++);
                        }
                      : null,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.s16),
            _InitialStockSection(
              stockCount: _initialStockWhole,
              unit: _selectedUnit,
              onValueTap: _editStockValue,
              onDecrement: _initialStockWhole > 0
                  ? () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() => _initialStockWhole--);
                    }
                  : null,
              onIncrement: _initialStockWhole < _maxStock
                  ? () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() => _initialStockWhole++);
                    }
                  : null,
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          TindaTextInput(
            label: localizations.productLowStockLabel,
            controller: _lowStockController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
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
  const _PriceCostRow({
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
  const _UnitSelector({
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
  const _InitialStockSection({
    required this.stockCount,
    required this.unit,
    required this.onDecrement,
    required this.onIncrement,
    required this.onValueTap,
  });

  final int stockCount;
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
        Expanded(
          child: Text(
            localizations.productInitialStockLabel,
            style: AppTypography.meta(
              palette.text,
              size: 13,
              weight: FontWeight.w700,
            ),
          ),
        ),
        TindaStepper(
          valueLabel: '$stockCount ${localizedUnit(localizations, unit)}',
          onDecrement: onDecrement,
          onIncrement: onIncrement,
          onValueTap: onValueTap,
          decrementTooltip: localizations.productStockDecrement,
          incrementTooltip: localizations.posAddToCart(
            localizedUnit(localizations, unit),
          ),
        ),
      ],
    );
  }
}

class _AdjustStockSection extends StatelessWidget {
  const _AdjustStockSection({
    required this.currentStock,
    required this.deltaWhole,
    required this.unit,
    required this.onDecrement,
    required this.onIncrement,
    required this.onValueTap,
  });

  final Quantity currentStock;
  final int deltaWhole;
  final ProductUnit unit;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback onValueTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final unitLabel = localizedUnit(localizations, unit);
    final deltaPrefix = deltaWhole > 0 ? '+' : '';
    final valueLabel = '$deltaPrefix$deltaWhole $unitLabel';

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
            Expanded(
              child: Text(
                localizations.productAdjustStockLabel,
                style: AppTypography.meta(
                  palette.text,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            TindaStepper(
              valueLabel: valueLabel,
              onDecrement: onDecrement,
              onIncrement: onIncrement,
              onValueTap: onValueTap,
              decrementTooltip: localizations.productStockDecrement,
              incrementTooltip: localizations.posAddToCart(unitLabel),
            ),
          ],
        ),
      ],
    );
  }
}
