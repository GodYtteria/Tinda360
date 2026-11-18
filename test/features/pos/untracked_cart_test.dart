import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';

StockedProduct _stocked({
  required String id,
  required bool tracksStock,
  required Quantity stock,
}) => StockedProduct(
  product: Product(
    id: id,
    name: id,
    unit: ProductUnit.piece,
    price: const Money(1000, Currency.php),
    cost: const Money(800, Currency.php),
    tracksStock: tracksStock,
  ),
  stock: stock,
);

void main() {
  test('an untracked product can be sold with zero stock recorded', () {
    final load = _stocked(
      id: 'load',
      tracksStock: false,
      stock: Quantity.zero,
    );
    expect(load.isSellable, isTrue);
    expect(load.sellCap.compareTo(const Quantity.whole(1000)), greaterThan(0));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(posCartProvider.notifier);
    for (var tap = 0; tap < 30; tap++) {
      expect(notifier.increment('load', available: load.sellCap), isTrue);
    }
    expect(container.read(posCartProvider)['load'], const Quantity.whole(30));
  });

  test('a tracked product with zero stock is still not sellable', () {
    final soldOut = _stocked(
      id: 'soda',
      tracksStock: true,
      stock: Quantity.zero,
    );
    expect(soldOut.isSellable, isFalse);
    expect(soldOut.sellCap, Quantity.zero);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container
          .read(posCartProvider.notifier)
          .increment('soda', available: soldOut.sellCap),
      isFalse,
    );
  });

  test('keepWithinStock keeps untracked lines and drops sold out tracked', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(posCartProvider.notifier)
      ..setQuantity(
        'load',
        const Quantity.whole(5),
        available: StockedProduct.untrackedSellCap,
      )
      ..setQuantity(
        'soda',
        const Quantity.whole(2),
        available: const Quantity.whole(9),
      );

    notifier.keepWithinStock([
      _stocked(id: 'load', tracksStock: false, stock: Quantity.zero),
      _stocked(id: 'soda', tracksStock: true, stock: Quantity.zero),
    ]);

    expect(container.read(posCartProvider), {'load': const Quantity.whole(5)});
  });
}
