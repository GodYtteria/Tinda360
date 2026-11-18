import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/customer_failure.dart';
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

FailureType _err<T, FailureType extends Failure>(
  Result<T, FailureType> result,
) => switch (result) {
  Ok(:final value) => fail('Expected Err, got $value'),
  Err(:final failure) => failure,
};

Money _php(int minor) => Money(minor, Currency.php);

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());
  tearDown(() => repos.close());

  Future<String> createSuki() async => _ok(
    await repos.customers.create(
      CustomerDraft(name: 'Mang Juan', phone: '0917', creditLimit: _php(5000)),
    ),
  );

  test('update changes name, phone and limit', () async {
    final id = await createSuki();
    _ok(
      await repos.customers.update(
        id,
        CustomerDraft(
          name: '  Aling Rosa ',
          phone: ' 0918 ',
          creditLimit: _php(9000),
        ),
      ),
    );
    final customer =
        (await repos.customers.watchBalances().first).single.customer;
    expect(customer.name, 'Aling Rosa');
    expect(customer.phone, '0918');
    expect(customer.creditLimit, _php(9000));
  });

  test('update clears phone and limit when blank', () async {
    final id = await createSuki();
    _ok(
      await repos.customers.update(id, const CustomerDraft(name: 'Mang Juan')),
    );
    final customer =
        (await repos.customers.watchBalances().first).single.customer;
    expect(customer.phone, isNull);
    expect(customer.creditLimit, isNull);
  });

  test(
    'update rejects blank name, non-positive limit and unknown id',
    () async {
      final id = await createSuki();
      expect(
        _err(await repos.customers.update(id, const CustomerDraft(name: '  '))),
        isA<CustomerNameRequired>(),
      );
      expect(
        _err(
          await repos.customers.update(
            id,
            CustomerDraft(name: 'X', creditLimit: _php(0)),
          ),
        ),
        isA<CustomerAmountInvalid>(),
      );
      expect(
        _err(
          await repos.customers.update(
            'missing',
            const CustomerDraft(name: 'X'),
          ),
        ),
        isA<CustomerNotFound>(),
      );
      expect(
        (await repos.customers.watchBalances().first).single.customer.name,
        'Mang Juan',
      );
    },
  );

  test('softDelete refused with balance, allowed at zero', () async {
    final id = await createSuki();
    final productId = _ok(
      await repos.products.create(
        ProductDraft(
          name: 'Sardines',
          unit: ProductUnit.can,
          price: _php(2500),
          cost: _php(2000),
          initialStock: const Quantity.whole(5),
        ),
      ),
    );
    _ok(
      await repos.sales.record(
        SaleDraft(
          lines: [
            SaleLineDraft(
              productId: productId,
              quantity: const Quantity.whole(1),
            ),
          ],
          method: PaymentMethod.utang,
          customerId: id,
        ),
      ),
    );

    final refused = _err(await repos.customers.softDelete(id));
    expect(refused, isA<CustomerHasBalance>());
    expect((refused as CustomerHasBalance).balance, _php(2500));
    expect(await repos.customers.watchBalances().first, hasLength(1));

    _ok(await repos.customers.recordPayment(id, _php(2500)));
    _ok(await repos.customers.softDelete(id));
    expect(await repos.customers.watchBalances().first, isEmpty);
    expect(
      _err(await repos.customers.softDelete(id)),
      isA<CustomerNotFound>(),
    );
  });

  test('deleted suki is hidden and cannot be updated or paid', () async {
    final id = await createSuki();
    _ok(await repos.customers.softDelete(id));
    expect(await repos.customers.watchBalances().first, isEmpty);
    expect(
      _err(
        await repos.customers.update(id, const CustomerDraft(name: 'Back')),
      ),
      isA<CustomerNotFound>(),
    );
  });
}
