import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/features/pos/data/cart_storage.dart';
import 'package:tinda360/services/service_providers.dart';

final posCartProvider =
    NotifierProvider<PosCartNotifier, Map<String, Quantity>>(
      PosCartNotifier.new,
    );

class PosCartNotifier extends Notifier<Map<String, Quantity>> {
  @override
  Map<String, Quantity> build() {
    final storeId = ref.watch(activeCartStoreIdProvider);
    final storage = ref.watch(cartStorageProvider);
    if (storeId == null) return const {};
    final emptyOnBuild = Map<String, Quantity>.unmodifiable(
      <String, Quantity>{},
    );
    listenSelf((previous, next) {
      if (previous == null ||
          identical(next, emptyOnBuild) ||
          _applyingRestore) {
        return;
      }
      unawaited(
        storage.write(storeId, next).catchError((
          Object error,
          StackTrace stack,
        ) {
          if (ref.mounted) {
            ref.read(appLogProvider).error('cart.save', error, stack);
          }
        }),
      );
    });
    unawaited(_restore(storage, storeId));
    return emptyOnBuild;
  }

  bool _applyingRestore = false;

  Future<void> _restore(CartStorage storage, String storeId) async {
    final restored = await storage.read(storeId);
    if (!ref.mounted || state.isNotEmpty || restored.isEmpty) return;
    if (ref.read(activeCartStoreIdProvider) != storeId) return;
    _applyingRestore = true;
    state = restored;
    _applyingRestore = false;
    final latestProducts = _latestProducts;
    if (latestProducts != null) keepWithinStock(latestProducts);
  }

  List<StockedProduct>? _latestProducts;

  bool increment(String productId, {required Quantity available}) {
    final current = state[productId] ?? Quantity.zero;
    final remaining = available - current;
    if (!remaining.isPositive) return false;
    const oneUnit = Quantity.whole(1);
    final next = remaining.compareTo(oneUnit) < 0
        ? available
        : current + oneUnit;
    state = {
      ...state,
      productId: next,
    };
    return true;
  }

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

  bool setQuantity(
    String productId,
    Quantity quantity, {
    required Quantity available,
  }) {
    if (!quantity.isPositive) {
      final updated = Map<String, Quantity>.of(state)..remove(productId);
      state = Map<String, Quantity>.unmodifiable(updated);
      return true;
    }
    if (quantity.compareTo(available) > 0) return false;
    state = {
      ...state,
      productId: quantity,
    };
    return true;
  }

  void keepWithinStock(List<StockedProduct> products) {
    _latestProducts = products;
    if (state.isEmpty) return;
    final stockByProductId = <String, Quantity>{
      for (final item in products) item.product.id: item.sellCap,
    };
    final adjusted = <String, Quantity>{};
    var changed = false;
    for (final entry in state.entries) {
      final stock = stockByProductId[entry.key];
      if (stock == null || !stock.isPositive) {
        changed = true;
        continue;
      }
      if (entry.value.compareTo(stock) > 0) {
        adjusted[entry.key] = stock;
        changed = true;
      } else {
        adjusted[entry.key] = entry.value;
      }
    }
    if (changed) state = Map<String, Quantity>.unmodifiable(adjusted);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const {};
  }

  int get itemCount {
    var count = 0;
    for (final quantity in state.values) {
      count += (quantity.milli / Quantity.milliPerUnit).ceil();
    }
    return count;
  }

  Money totalFor(
    List<StockedProduct> products,
    Currency currency, {
    Map<String, Money> priceOverrides = const {},
  }) {
    final byId = <String, StockedProduct>{
      for (final item in products) item.product.id: item,
    };
    var total = Money.zero(currency);
    for (final entry in state.entries) {
      final item = byId[entry.key];
      if (item == null) continue;
      total += SaleMath.lineTotal(
        priceOverrides[entry.key] ?? item.product.price,
        entry.value,
      );
    }
    return total;
  }

  List<SaleLineDraft> toSaleLines() => [
    for (final entry in state.entries)
      SaleLineDraft(productId: entry.key, quantity: entry.value),
  ];
}
