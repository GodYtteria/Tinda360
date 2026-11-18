import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/data/cart_storage.dart';
import 'package:tinda360/features/pos/presentation/cart_price_override_provider.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';

final _storeIdProvider = NotifierProvider<_StoreId, String?>(_StoreId.new);

class _StoreId extends Notifier<String?> {
  @override
  String? build() => 'store-a';
  void set(String id) => state = id;
}

Future<void> waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 250; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('switching stores in place keeps each store cart and prices', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cart_store_switch_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final storage = CartStorage(directoryProvider: () async => directory);
    await storage.write('store-b', {'oil': const Quantity.whole(2)});
    await storage.writePrices('store-b', {'oil': 900});
    final container = ProviderContainer(
      overrides: [
        cartStorageProvider.overrideWithValue(storage),
        activeCartStoreIdProvider.overrideWith(
          (ref) => ref.watch(_storeIdProvider),
        ),
      ],
    );
    container.listen(posCartProvider, (previous, next) {});
    container.listen(cartPriceOverrideProvider, (previous, next) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    container
        .read(posCartProvider.notifier)
        .setQuantity(
          'rice',
          const Quantity.whole(1),
          available: const Quantity.whole(10),
        );
    container
        .read(cartPriceOverrideProvider.notifier)
        .setPrice('rice', const Money(700, Currency.php));
    await waitUntil(() => container.read(posCartProvider).containsKey('rice'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    container.read(_storeIdProvider.notifier).set('store-b');
    await waitUntil(
      () =>
          container.read(posCartProvider).containsKey('oil') &&
          container.read(cartPriceOverrideProvider).containsKey('oil'),
    );
    expect(container.read(posCartProvider), {'oil': const Quantity.whole(2)});
    expect(await storage.read('store-b'), {'oil': const Quantity.whole(2)});
    expect(await storage.readPrices('store-b'), {'oil': 900});
    expect(container.read(cartPriceOverrideProvider), {
      'oil': const Money(900, Currency.php),
    });
    expect(await storage.read('store-a'), {'rice': const Quantity.whole(1)});
    expect(await storage.readPrices('store-a'), {'rice': 700});
    container.dispose();
  });
}
