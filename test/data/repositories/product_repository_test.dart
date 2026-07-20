import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';

import '../../support/test_repositories.dart';

ProductDraft _draft({
  String name = 'Kape 3-in-1',
  ProductUnit unit = ProductUnit.sachet,
  int priceMinor = 1000,
  int costMinor = 800,
  String? barcode,
  Quantity? lowStockAt,
  Quantity initialStock = Quantity.zero,
}) => ProductDraft(
  name: name,
  unit: unit,
  price: Money(priceMinor, Currency.php),
  cost: Money(costMinor, Currency.php),
  barcode: barcode,
  lowStockAt: lowStockAt,
  initialStock: initialStock,
);

String _idOf(Result<String, ProductFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
};

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());
  tearDown(() => repos.close());

  test('every ProductUnit value passes the database CHECK', () async {
    for (final unit in ProductUnit.values) {
      final result = await repos.products.create(
        _draft(name: unit.storageName, unit: unit),
      );
      expect(result, isA<Ok<String, ProductFailure>>(), reason: unit.name);
    }
    expect(repos.log.events, isEmpty);
  });

  test('stock is the sum of movements, never a stored number', () async {
    final id = _idOf(
      await repos.products.create(_draft(initialStock: const Quantity.whole(10))),
    );
    expect(
      await repos.products.restock(id, const Quantity.whole(5)),
      isA<Ok<void, ProductFailure>>(),
    );
    expect(
      await repos.products.adjust(id, -const Quantity.whole(2)),
      isA<Ok<void, ProductFailure>>(),
    );

    final products = await repos.products.watchActive().first;
    expect(products.single.stock, const Quantity.whole(13));
  });

  test('low stock follows the alert level', () async {
    await repos.products.create(
      _draft(
        initialStock: const Quantity.whole(3),
        lowStockAt: const Quantity.whole(5),
      ),
    );
    final products = await repos.products.watchActive().first;
    expect(products.single.isLowOnStock, isTrue);
  });

  test('an empty name is rejected', () async {
    final result = await repos.products.create(_draft(name: '   '));
    expect(
      result,
      isA<Err<String, ProductFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<ProductNameRequired>(),
      ),
    );
  });

  test('half a sachet is rejected', () async {
    final result = await repos.products.create(
      _draft(initialStock: const Quantity.milli(500)),
    );
    expect(
      result,
      isA<Err<String, ProductFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<ProductQuantityInvalid>(),
      ),
    );
  });

  test('a barcode can only belong to one active product', () async {
    _idOf(await repos.products.create(_draft(barcode: '4800000000001')));
    final second = await repos.products.create(
      _draft(name: 'Iba', barcode: ' 4800000000001 '),
    );
    expect(
      second,
      isA<Err<String, ProductFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<ProductBarcodeTaken>(),
      ),
    );
  });

  test('a deleted product leaves the list', () async {
    final id = _idOf(await repos.products.create(_draft()));
    expect(await repos.products.softDelete(id), isA<Ok<void, ProductFailure>>());
    expect(await repos.products.watchActive().first, isEmpty);
  });
}
