import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/features/inventory/presentation/product_form_logic.dart';

import '../../support/test_repositories.dart';

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());
  tearDown(() => repos.close());

  test('computeProfitPerSale calculates positive and negative margins', () {
    expect(
      ProductFormLogic.computeProfitPerSale(
        priceInput: '15.00',
        costInput: '11.50',
        currency: Currency.php,
      ),
      const Money(350, Currency.php),
    );
    expect(
      ProductFormLogic.computeProfitPerSale(
        priceInput: '10',
        costInput: '12',
        currency: Currency.php,
      ),
      const Money(-200, Currency.php),
    );
    expect(
      ProductFormLogic.computeProfitPerSale(
        priceInput: 'abc',
        costInput: '10',
        currency: Currency.php,
      ),
      isNull,
    );
  });

  test(
    'buildDraft integrates with ProductRepository create, update, delete',
    () async {
      final invalidDraft = ProductFormLogic.buildDraft(
        name: '',
        unit: ProductUnit.piece,
        priceInput: '10',
        costInput: '8',
        currency: Currency.php,
      );
      final invalidResult = await repos.products.create(invalidDraft);
      expect(
        invalidResult,
        isA<Err<String, ProductFailure>>().having(
          (errorResult) => errorResult.failure,
          'failure',
          isA<ProductNameRequired>(),
        ),
      );

      final validDraft = ProductFormLogic.buildDraft(
        name: 'Sardinas',
        unit: ProductUnit.can,
        priceInput: '24.50',
        costInput: '20.00',
        currency: Currency.php,
        lowStockInput: '5',
        initialStock: const Quantity.whole(12),
      );
      final created = await repos.products.create(validDraft);
      final productId = switch (created) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
      };

      var active = await repos.products.watchActive().first;
      expect(active, hasLength(1));
      expect(active.first.product.lowStockAt, const Quantity.whole(5));
      expect(active.first.stock, const Quantity.whole(12));

      final updatedDraft = ProductFormLogic.buildDraft(
        name: 'Sardinas Spicy',
        unit: ProductUnit.can,
        priceInput: '25.00',
        costInput: '20.00',
        currency: Currency.php,
      );
      final updated = await repos.products.update(productId, updatedDraft);
      expect(updated, isA<Ok<void, ProductFailure>>());

      final deleted = await repos.products.softDelete(productId);
      expect(deleted, isA<Ok<void, ProductFailure>>());

      active = await repos.products.watchActive().first;
      expect(active, isEmpty);
    },
  );

  test('a product with a typed category saves and updates', () async {
    final draft = ProductFormLogic.buildDraft(
      name: 'Sardinas',
      unit: ProductUnit.can,
      priceInput: '24.50',
      costInput: '20.00',
      currency: Currency.php,
      categoryInput: 'Snacks',
    );
    final created = await repos.products.create(draft);
    final productId = switch (created) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };
    final active = await repos.products.watchActive().first;
    expect(active.single.product.categoryId, 'Snacks');

    final updatedDraft = ProductFormLogic.buildDraft(
      name: 'Sardinas',
      unit: ProductUnit.can,
      priceInput: '24.50',
      costInput: '20.00',
      currency: Currency.php,
      categoryInput: 'Canned goods',
    );
    final updated = await repos.products.update(productId, updatedDraft);
    expect(updated, isA<Ok<void, ProductFailure>>());
    final refreshed = await repos.products.watchActive().first;
    expect(refreshed.single.product.categoryId, 'Canned goods');
  });

  test('parseQuantity accepts decimals only for fraction units', () {
    expect(
      ProductFormLogic.parseQuantity('2.5', allowsFraction: true),
      const Quantity.milli(2500),
    );
    expect(
      ProductFormLogic.parseQuantity('0.25', allowsFraction: true),
      const Quantity.milli(250),
    );
    expect(
      ProductFormLogic.parseQuantity('2.5', allowsFraction: false),
      isNull,
    );
    expect(
      ProductFormLogic.parseQuantity('3', allowsFraction: false),
      const Quantity.whole(3),
    );
    expect(ProductFormLogic.parseQuantity('', allowsFraction: true), isNull);
    expect(
      ProductFormLogic.parseQuantity('1..5', allowsFraction: true),
      isNull,
    );
    expect(ProductFormLogic.parseQuantity('-1', allowsFraction: true), isNull);
    expect(
      ProductFormLogic.parseQuantity('1.2345', allowsFraction: true),
      isNull,
    );
  });

  test('a kilo product keeps a fractional low-stock alert', () {
    final draft = ProductFormLogic.buildDraft(
      name: 'Bigas',
      unit: ProductUnit.kilo,
      priceInput: '55',
      costInput: '45',
      currency: Currency.php,
      lowStockInput: '2.5',
    );
    expect(draft.lowStockAt, const Quantity.milli(2500));
  });
}
