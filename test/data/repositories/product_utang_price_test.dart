import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';

import '../../support/test_repositories.dart';

T _ok<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

Money _php(int minor) => Money(minor, Currency.php);

ProductDraft _draft({Money? utangPrice}) => ProductDraft(
  name: 'Bigas',
  unit: ProductUnit.kilo,
  price: _php(5000),
  cost: _php(4500),
  initialStock: const Quantity.whole(20),
  utangPrice: utangPrice,
);

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());
  tearDown(() => repos.close());

  Future<Money?> storedUtangPrice() async {
    final products = await repos.products.watchActive().first;
    return products.single.product.utangPrice;
  }

  test('no utang price round trips as null', () async {
    _ok(await repos.products.create(_draft()));
    expect(await storedUtangPrice(), isNull);
  });

  test('a utang price round trips', () async {
    _ok(await repos.products.create(_draft(utangPrice: _php(5500))));
    expect(await storedUtangPrice(), _php(5500));
  });

  test('zero is a real utang price, not null', () async {
    _ok(await repos.products.create(_draft(utangPrice: _php(0))));
    expect(await storedUtangPrice(), _php(0));
  });

  test('a negative utang price is rejected on create and update', () async {
    final created = await repos.products.create(_draft(utangPrice: _php(-1)));
    expect(created, isA<Err<String, ProductFailure>>());
    final id = _ok(await repos.products.create(_draft()));
    final updated = await repos.products.update(
      id,
      _draft(utangPrice: _php(-100)),
    );
    expect(updated, isA<Err<void, ProductFailure>>());
    expect(await storedUtangPrice(), isNull);
  });

  test('update sets and then clears the utang price', () async {
    final id = _ok(await repos.products.create(_draft()));
    _ok(await repos.products.update(id, _draft(utangPrice: _php(5500))));
    expect(await storedUtangPrice(), _php(5500));
    _ok(await repos.products.update(id, _draft()));
    expect(await storedUtangPrice(), isNull);
  });

  test('sales record the unit price that the line carries', () async {
    final id = _ok(
      await repos.products.create(_draft(utangPrice: _php(5500))),
    );
    final customerId = _ok(
      await repos.customers.create(const CustomerDraft(name: 'Aling Nena')),
    );
    final cashSaleId = _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.cash,
          cashTendered: _php(10000),
          lines: [
            SaleLineDraft(productId: id, quantity: const Quantity.whole(2)),
          ],
        ),
      ),
    );
    final utangSaleId = _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.utang,
          customerId: customerId,
          paidNow: _php(0),
          lines: [
            SaleLineDraft(
              productId: id,
              quantity: const Quantity.whole(2),
              unitPriceOverride: _php(5500),
            ),
          ],
        ),
      ),
    );

    Future<int> unitPriceOf(String saleId) async {
      final row = await repos.db
          .customSelect(
            'SELECT unit_price_minor FROM sale_items WHERE sale_id = ?',
            variables: [Variable.withString(saleId)],
          )
          .getSingle();
      return row.read<int>('unit_price_minor');
    }

    expect(await unitPriceOf(cashSaleId), 5000);
    expect(await unitPriceOf(utangSaleId), 5500);
    final balances = await repos.customers.watchBalances().first;
    expect(balances.single.balance, _php(11000));
  });
}
