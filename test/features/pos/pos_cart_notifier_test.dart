import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/failures/sale_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';

import '../../support/test_repositories.dart';

String _productIdOf(Result<String, ProductFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
};

void main() {
  late TestRepositories repos;
  late ProviderContainer container;

  setUp(() {
    repos = TestRepositories();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await repos.close();
  });

  test('increment, decrement, setQuantity, and clear update cart', () {
    final notifier = container.read(posCartProvider.notifier);

    expect(container.read(posCartProvider), isEmpty);

    notifier.increment('p1');
    notifier.increment('p1');
    expect(container.read(posCartProvider)['p1'], const Quantity.whole(2));
    expect(notifier.itemCount, 2);

    notifier.decrement('p1');
    expect(container.read(posCartProvider)['p1'], const Quantity.whole(1));

    notifier.decrement('p1');
    expect(container.read(posCartProvider), isEmpty);

    notifier.setQuantity('p2', const Quantity.milli(500));
    expect(notifier.itemCount, 1);

    notifier.clear();
    expect(container.read(posCartProvider), isEmpty);
  });

  test('totalFor and toSaleLines integrate with SaleRepository', () async {
    final riceId = _productIdOf(
      await repos.products.create(
        const ProductDraft(
          name: 'Bigas',
          unit: ProductUnit.kilo,
          price: Money(5500, Currency.php),
          cost: Money(4500, Currency.php),
          initialStock: Quantity.whole(10),
        ),
      ),
    );
    final coffeeId = _productIdOf(
      await repos.products.create(
        const ProductDraft(
          name: 'Kape',
          unit: ProductUnit.sachet,
          price: Money(1000, Currency.php),
          cost: Money(800, Currency.php),
          initialStock: Quantity.whole(20),
        ),
      ),
    );

    final active = await repos.products.watchActive().first;
    final notifier = container.read(posCartProvider.notifier)
      ..setQuantity(riceId, const Quantity.milli(500))
      ..increment(coffeeId)
      ..increment(coffeeId);

    final total = notifier.totalFor(active, Currency.php);
    expect(total, const Money(4750, Currency.php));

    final saleResult = await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.cash,
        lines: notifier.toSaleLines(),
        cashTendered: const Money(5000, Currency.php),
      ),
    );
    expect(saleResult, isA<Ok<String, SaleFailure>>());

    notifier.clear();
    expect(container.read(posCartProvider), isEmpty);
  });

  test('ProductRepository.adjustStock validates and records movements', () async {
    final coffeeId = _productIdOf(
      await repos.products.create(
        const ProductDraft(
          name: 'Kape',
          unit: ProductUnit.piece,
          price: Money(1000, Currency.php),
          cost: Money(800, Currency.php),
          initialStock: Quantity.whole(5),
        ),
      ),
    );

    final zeroResult = await repos.products.adjustStock(coffeeId, Quantity.zero);
    expect(zeroResult, isA<Err<void, ProductFailure>>());

    final missingResult = await repos.products.adjustStock(
      'missing-id',
      const Quantity.whole(1),
    );
    expect(missingResult, isA<Err<void, ProductFailure>>());

    final fractionResult = await repos.products.adjustStock(
      coffeeId,
      const Quantity.milli(500),
    );
    expect(fractionResult, isA<Err<void, ProductFailure>>());

    final addResult = await repos.products.adjustStock(
      coffeeId,
      const Quantity.whole(3),
    );
    expect(addResult, isA<Ok<void, ProductFailure>>());

    final subtractResult = await repos.products.adjustStock(
      coffeeId,
      const Quantity.whole(-2),
    );
    expect(subtractResult, isA<Ok<void, ProductFailure>>());

    final products = await repos.products.watchActive().first;
    final updated = products.singleWhere((item) => item.product.id == coffeeId);
    expect(updated.stock, const Quantity.whole(6));
  });
}
