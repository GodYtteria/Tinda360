import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/data/repositories/product_popularity_repository.dart';

import '../../support/test_repositories.dart';

T _ok<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

void main() {
  late TestRepositories repos;
  late ProductPopularityRepository popularity;
  late String riceId;
  late String sodaId;

  Future<String> createProduct(String name) async => _ok(
    await repos.products.create(
      ProductDraft(
        name: name,
        unit: ProductUnit.piece,
        price: const Money(1000, Currency.php),
        cost: const Money(800, Currency.php),
        initialStock: const Quantity.whole(100),
      ),
    ),
  );

  Future<void> sell(String productId, int quantity) async {
    _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.cash,
          cashTendered: const Money(100000, Currency.php),
          lines: [
            SaleLineDraft(
              productId: productId,
              quantity: Quantity.whole(quantity),
            ),
          ],
        ),
      ),
    );
  }

  setUp(() async {
    repos = TestRepositories();
    popularity = ProductPopularityRepository(
      db: repos.db,
      clock: repos.clock,
    );
    riceId = await createProduct('Rice');
    sodaId = await createProduct('Soda');
  });

  tearDown(() => repos.close());

  test('sums units sold per product inside the window', () async {
    await sell(riceId, 2);
    await sell(riceId, 3);
    await sell(sodaId, 1);

    final sold = await popularity.unitsSoldMilliByProductId();

    expect(sold[riceId], 5000);
    expect(sold[sodaId], 1000);
  });

  test('a product that never sold is absent', () async {
    await sell(riceId, 1);

    final sold = await popularity.unitsSoldMilliByProductId();

    expect(sold.containsKey(sodaId), isFalse);
  });

  test('the watch emits again after a new sale', () async {
    await sell(riceId, 1);
    final emissions = <Map<String, int>>[];
    final subscription = popularity.watchUnitsSoldMilliByProductId().listen(
      emissions.add,
    );
    addTearDown(subscription.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(emissions.last, {riceId: 1000});

    await sell(sodaId, 4);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(emissions.last, {riceId: 1000, sodaId: 4000});
  });
}
