import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_math.dart';

/// Holds the active POS cart as a map of `productId -> Quantity`.
final posCartProvider =
    NotifierProvider<PosCartNotifier, Map<String, Quantity>>(
      PosCartNotifier.new,
    );

/// Manages POS cart quantities and totals.
class PosCartNotifier extends Notifier<Map<String, Quantity>> {
  @override
  Map<String, Quantity> build() => const {};

  /// Adds one whole unit of [productId] to the cart.
  void increment(String productId) {
    final current = state[productId] ?? Quantity.zero;
    state = {
      ...state,
      productId: current + const Quantity.whole(1),
    };
  }

  /// Removes one whole unit of [productId], deleting the line at zero.
  void decrement(String productId) {
    final current = state[productId];
    if (current == null) return;
    final next = current - const Quantity.whole(1);
    if (!next.isPositive) {
      final updated = Map<String, Quantity>.of(state)..remove(productId);
      state = Map<String, Quantity>.unmodifiable(updated);
      return;
    }
    state = {
      ...state,
      productId: next,
    };
  }

  /// Sets an explicit [quantity] for [productId], removing the line if <= 0.
  void setQuantity(String productId, Quantity quantity) {
    if (!quantity.isPositive) {
      final updated = Map<String, Quantity>.of(state)..remove(productId);
      state = Map<String, Quantity>.unmodifiable(updated);
      return;
    }
    state = {
      ...state,
      productId: quantity,
    };
  }

  /// Empties the cart.
  void clear() {
    if (state.isEmpty) return;
    state = const {};
  }

  /// Total item count displayed on the cart bar.
  int get itemCount {
    var count = 0;
    for (final quantity in state.values) {
      count += (quantity.milli / Quantity.milliPerUnit).ceil();
    }
    return count;
  }

  /// Computes the cart total using [SaleMath.lineTotal] for each matching
  /// product in [products].
  Money totalFor(List<StockedProduct> products, Currency currency) {
    final byId = <String, StockedProduct>{
      for (final item in products) item.product.id: item,
    };
    var total = Money.zero(currency);
    for (final entry in state.entries) {
      final item = byId[entry.key];
      if (item == null) continue;
      total += SaleMath.lineTotal(item.product.price, entry.value);
    }
    return total;
  }

  /// Converts the current cart into [SaleLineDraft] entries for checkout.
  List<SaleLineDraft> toSaleLines() => [
        for (final entry in state.entries)
          SaleLineDraft(productId: entry.key, quantity: entry.value),
      ];
}
