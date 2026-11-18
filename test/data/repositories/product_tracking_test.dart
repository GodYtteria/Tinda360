import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';

import '../../support/test_repositories.dart';

ProductDraft _draft({
  bool tracksStock = true,
  LocalDay? expiryDay,
  Quantity initialStock = Quantity.zero,
}) => ProductDraft(
  name: 'Load 50',
  unit: ProductUnit.piece,
  price: const Money(5000, Currency.php),
  cost: const Money(4800, Currency.php),
  initialStock: initialStock,
  tracksStock: tracksStock,
  expiryDay: expiryDay,
  lowStockAt: tracksStock ? const Quantity.whole(2) : null,
);

StockedProduct _stocked({
  bool tracksStock = true,
  Quantity stock = Quantity.zero,
  Quantity? lowStockAt,
}) => StockedProduct(
  product: Product(
    id: 'p1',
    name: 'Item',
    unit: ProductUnit.piece,
    price: const Money(100, Currency.php),
    cost: const Money(50, Currency.php),
    lowStockAt: lowStockAt,
    tracksStock: tracksStock,
  ),
  stock: stock,
);

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());
  tearDown(() => repos.close());

  test('tracksStock and expiry round trip through the repository', () async {
    const expiry = LocalDay(20400);
    final created = await repos.products.create(
      _draft(tracksStock: false, expiryDay: expiry),
    );
    expect(created, isA<Ok<String, ProductFailure>>());

    final stored = (await repos.products.watchActive().first).single.product;
    expect(stored.tracksStock, isFalse);
    expect(stored.expiryDay, expiry);

    final id = stored.id;
    final updated = await repos.products.update(id, _draft());
    expect(updated, isA<Ok<void, ProductFailure>>());
    final reloaded = (await repos.products.watchActive().first).single.product;
    expect(reloaded.tracksStock, isTrue);
    expect(reloaded.expiryDay, isNull);
  });

  test('untracked creation writes no stock movement', () async {
    final result = await repos.products.create(
      _draft(tracksStock: false, initialStock: const Quantity.whole(9)),
    );
    final id = (result as Ok<String, ProductFailure>).value;
    final history = await repos.products.watchStockHistory(id).first;
    expect(history, isEmpty);
    expect((await repos.products.watchActive().first).single.stock.milli, 0);
  });

  test('tracked creation still writes the initial movement', () async {
    final result = await repos.products.create(
      _draft(initialStock: const Quantity.whole(9)),
    );
    final id = (result as Ok<String, ProductFailure>).value;
    expect(await repos.products.watchStockHistory(id).first, hasLength(1));
  });

  test('isSellable, sellLimit and isLowOnStock follow tracksStock', () {
    final untracked = _stocked(
      tracksStock: false,
      lowStockAt: const Quantity.whole(5),
    );
    expect(untracked.isSellable, isTrue);
    expect(untracked.sellLimit, isNull);
    expect(untracked.isLowOnStock, isFalse);

    final tracked = _stocked(lowStockAt: const Quantity.whole(5));
    expect(tracked.isSellable, isFalse);
    expect(tracked.sellLimit, Quantity.zero);
    expect(tracked.isLowOnStock, isTrue);

    final inStock = _stocked(stock: const Quantity.whole(3));
    expect(inStock.isSellable, isTrue);
    expect(inStock.sellLimit, const Quantity.whole(3));
  });
}
