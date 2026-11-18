import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/pos/data/cart_storage.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';
import 'package:tinda360/services/service_providers.dart';

final cartPriceOverrideProvider =
    NotifierProvider<CartPriceOverrideNotifier, Map<String, Money>>(
      CartPriceOverrideNotifier.new,
    );

class CartPriceOverrideNotifier extends Notifier<Map<String, Money>> {
  @override
  Map<String, Money> build() {
    final storeId = ref.watch(activeCartStoreIdProvider);
    final storage = ref.watch(cartStorageProvider);
    final currency = ref.watch(storeCurrencyProvider);
    ref.listen(posCartProvider, (previous, cart) {
      final cartJustRestored =
          (previous == null || previous.isEmpty) && cart.isNotEmpty;
      if (cartJustRestored && state.isEmpty) {
        unawaited(restoreSavedPrices());
        return;
      }
      if (state.isEmpty) return;
      if (cart.isEmpty) {
        state = const {};
        return;
      }
      final stillInCart = {
        for (final entry in state.entries)
          if (cart.containsKey(entry.key)) entry.key: entry.value,
      };
      if (stillInCart.length != state.length) state = stillInCart;
    });
    final emptyOnBuild = Map<String, Money>.unmodifiable(<String, Money>{});
    if (storeId != null) {
      listenSelf((previous, next) {
        if (previous == null ||
            identical(next, emptyOnBuild) ||
            _applyingRestore) {
          return;
        }
        unawaited(
          storage
              .writePrices(storeId, {
                for (final entry in next.entries)
                  entry.key: entry.value.minorUnits,
              })
              .catchError((Object error, StackTrace stack) {
                if (ref.mounted) {
                  ref.read(appLogProvider).error('cart.prices', error, stack);
                }
              }),
        );
      });
      _currency = currency;
      _storage = storage;
      _storeId = storeId;
      if (ref.read(posCartProvider).isNotEmpty) {
        unawaited(restoreSavedPrices());
      }
    }
    return emptyOnBuild;
  }

  bool _applyingRestore = false;
  Currency _currency = Currency.php;
  CartStorage? _storage;
  String? _storeId;

  Future<void> restoreSavedPrices() async {
    final storage = _storage;
    final storeId = _storeId;
    if (storage == null || storeId == null) return;
    final savedPrices = await storage.readPrices(storeId);
    if (!ref.mounted || state.isNotEmpty || savedPrices.isEmpty) return;
    final cart = ref.read(posCartProvider);
    _applyingRestore = true;
    state = {
      for (final entry in savedPrices.entries)
        if (cart.containsKey(entry.key))
          entry.key: Money(entry.value, _currency),
    };
    _applyingRestore = false;
  }

  void setPrice(String productId, Money unitPrice) {
    state = {...state, productId: unitPrice};
  }

  void resetPrice(String productId) {
    if (!state.containsKey(productId)) return;
    state = {
      for (final entry in state.entries)
        if (entry.key != productId) entry.key: entry.value,
    };
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}
