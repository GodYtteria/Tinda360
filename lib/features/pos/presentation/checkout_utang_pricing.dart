import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/features/pos/presentation/checkout_items_card.dart';
import 'package:tinda360/features/pos/presentation/checkout_shortfall.dart';

bool usesUtangPrices({
  required PaymentMethod method,
  required bool cashShortfallDetected,
  required bool customerSelected,
}) =>
    method == PaymentMethod.utang ||
    (cashShortfallDetected && customerSelected);

Money effectiveUnitPrice({
  required Money normalPrice,
  required Money? utangPrice,
  required Money? manualOverride,
  required bool useUtangPrices,
}) {
  if (manualOverride != null) return manualOverride;
  if (useUtangPrices && utangPrice != null) return utangPrice;
  return normalPrice;
}

List<CheckoutLine> resolveCheckoutLines({
  required Map<String, Quantity> cart,
  required List<StockedProduct> products,
  required Map<String, Money> manualOverrides,
  required bool useUtangPrices,
}) {
  final productsById = <String, StockedProduct>{
    for (final item in products) item.product.id: item,
  };
  final lines = <CheckoutLine>[];
  for (final entry in cart.entries) {
    final item = productsById[entry.key];
    if (item == null) continue;
    final manualOverride = manualOverrides[entry.key];
    final unitPrice = effectiveUnitPrice(
      normalPrice: item.product.price,
      utangPrice: item.product.utangPrice,
      manualOverride: manualOverride,
      useUtangPrices: useUtangPrices,
    );
    lines.add(
      CheckoutLine(
        stocked: item,
        quantity: entry.value,
        unitPriceOverride: manualOverride,
        usesUtangPrice:
            manualOverride == null && unitPrice != item.product.price,
        subtotal: SaleMath.lineTotal(unitPrice, entry.value),
      ),
    );
  }
  return lines;
}

Money sumCheckoutLines(List<CheckoutLine> lines, Currency currency) {
  var total = Money.zero(currency);
  for (final line in lines) {
    total += line.subtotal;
  }
  return total;
}

Money? utangShortageOf({
  required Money utangTotal,
  required Money? cashReceived,
}) {
  if (cashReceived == null || !cashReceived.isPositive) return null;
  if (!(cashReceived < utangTotal)) return null;
  return utangTotal - cashReceived;
}

Money? resolveCashShortfall({
  required PaymentMethod method,
  required Money cashTotal,
  required Money utangTotal,
  required Money? cashReceived,
}) {
  final detected = cashShortfallOf(
    method: method,
    total: cashTotal,
    cashReceived: cashReceived,
  );
  if (detected == null) return null;
  return utangShortageOf(utangTotal: utangTotal, cashReceived: cashReceived);
}
