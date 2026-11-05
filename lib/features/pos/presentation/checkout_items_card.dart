import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class CheckoutLine {
  const CheckoutLine({
    required this.stocked,
    required this.quantity,
    required this.subtotal,
    this.unitPriceOverride,
    this.usesUtangPrice = false,
  });

  final StockedProduct stocked;
  final Quantity quantity;
  final Money subtotal;
  final Money? unitPriceOverride;
  final bool usesUtangPrice;

  Money? get saleUnitPriceOverride =>
      unitPriceOverride ?? (usesUtangPrice ? stocked.utangPrice : null);

  Money get effectiveUnitPrice =>
      saleUnitPriceOverride ?? stocked.product.price;

  bool get hasChangedPrice => unitPriceOverride != null || usesUtangPrice;
}

const double _priceColumnWidthFraction = 0.3;

class CheckoutItemsCard extends StatelessWidget {
  const CheckoutItemsCard({
    required this.lines,
    required this.total,
    required this.onDecrement,
    required this.onIncrement,
    required this.onEditQuantity,
    required this.onEditPrice,
    super.key,
  });

  final List<CheckoutLine> lines;
  final Money total;
  final ValueChanged<String> onDecrement;
  final ValueChanged<StockedProduct> onIncrement;
  final ValueChanged<CheckoutLine> onEditQuantity;
  final ValueChanged<CheckoutLine> onEditPrice;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return TindaCard(
      backgroundColor: palette.surfaceMuted,
      child: Column(
        children: [
          for (final line in lines) ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onEditQuantity(line),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s8,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: '${line.stocked.product.name} × ',
                          children: [
                            TextSpan(
                              text: formatQuantity(
                                line.quantity,
                                line.stocked.product.unit,
                              ),
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        style: AppTypography.body(palette.text),
                      ),
                    ),
                  ),
                ),
                _LineQuantityButton(
                  icon: Icons.remove,
                  tooltip: localizations.posRemoveFromCart(
                    line.stocked.product.name,
                  ),
                  onPressed: () => onDecrement(line.stocked.product.id),
                  palette: palette,
                ),
                const SizedBox(width: AppSpacing.s4),
                _LineQuantityButton(
                  icon: Icons.add,
                  tooltip: localizations.posAddToCart(
                    line.stocked.product.name,
                  ),
                  onPressed: () => onIncrement(line.stocked),
                  palette: palette,
                ),
                const SizedBox(width: AppSpacing.s8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.sizeOf(context).width *
                        _priceColumnWidthFraction,
                  ),
                  child: InkWell(
                    onTap: () => onEditPrice(line),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s8,
                        horizontal: AppSpacing.s4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (line.usesUtangPrice)
                            MoneyText.text(
                              localizations.checkoutUtangPriceTag,
                              alignment: AlignmentDirectional.centerEnd,
                              style: AppTypography.meta(
                                palette.primary,
                                size: 11,
                                weight: FontWeight.w700,
                              ),
                            ),
                          if (line.hasChangedPrice)
                            MoneyText(
                              SaleMath.lineTotal(
                                line.stocked.product.price,
                                line.quantity,
                              ),
                              alignment: AlignmentDirectional.centerEnd,
                              style:
                                  AppTypography.meta(
                                    palette.textMuted,
                                    size: 12,
                                  ).copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                          MoneyText(
                            line.subtotal,
                            alignment: AlignmentDirectional.centerEnd,
                            style: AppTypography.bodyStrong(
                              line.hasChangedPrice
                                  ? palette.primary
                                  : palette.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          Divider(color: palette.borderStrong),
          const SizedBox(height: AppSpacing.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations.checkoutTotalLabel,
                style: AppTypography.bodyStrong(palette.text, size: 16),
              ),
              const SizedBox(width: AppSpacing.s12),
              Flexible(
                child: MoneyText(
                  total,
                  alignment: AlignmentDirectional.centerEnd,
                  style: AppTypography.display(palette.primary, size: 26),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineQuantityButton extends StatelessWidget {
  const _LineQuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.palette,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            side: BorderSide(color: palette.border),
          ),
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onPressed();
            },
            borderRadius: BorderRadius.circular(AppRadii.button),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              child: Icon(icon, size: 18, color: palette.text),
            ),
          ),
        ),
      ),
    );
  }
}
