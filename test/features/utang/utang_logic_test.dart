import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/customer_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/features/utang/presentation/utang_pay_sheet.dart';
import 'package:tinda360/features/utang/presentation/utang_screen.dart';

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
  late String productId;

  setUp(() async {
    repos = TestRepositories();
    productId = _ok(
      await repos.products.create(
        ProductDraft(
          name: 'Sardines',
          unit: ProductUnit.can,
          price: _php(2500),
          cost: _php(2000),
          initialStock: const Quantity.whole(20),
        ),
      ),
    );
  });

  tearDown(() async {
    await repos.close();
  });

  test('create suki rejects empty name and non-positive limit', () async {
    final emptyName = _err(
      await repos.customers.create(const CustomerDraft(name: '   ')),
    );
    expect(emptyName, isA<CustomerNameRequired>());

    final zeroLimit = _err(
      await repos.customers.create(
        CustomerDraft(name: 'Aling Rosa', creditLimit: _php(0)),
      ),
    );
    expect(zeroLimit, isA<CustomerAmountInvalid>());
  });

  test('utang sale, partial payment, full payment, and over-limit', () async {
    final sukiId = _ok(
      await repos.customers.create(
        CustomerDraft(
          name: 'Mang Juan',
          phone: '09171234567',
          creditLimit: _php(4000),
        ),
      ),
    );

    _ok(
      await repos.sales.record(
        SaleDraft(
          lines: [
            SaleLineDraft(
              productId: productId,
              quantity: const Quantity.whole(2),
            ),
          ],
          method: PaymentMethod.utang,
          customerId: sukiId,
        ),
      ),
    );

    final afterSale = await repos.customers.watchBalances().first;
    expect(afterSale, hasLength(1));
    expect(afterSale.single.balance, _php(5000));
    expect(afterSale.single.isOverLimit, isTrue);

    final tooMuch = _err(
      await repos.customers.recordPayment(sukiId, _php(6000)),
    );
    expect(tooMuch, isA<PaymentExceedsBalance>());

    _ok(await repos.customers.recordPayment(sukiId, _php(2000)));
    final afterPartial = await repos.customers.watchBalances().first;
    expect(afterPartial.single.balance, _php(3000));
    expect(afterPartial.single.isOverLimit, isFalse);

    _ok(await repos.customers.recordPayment(sukiId, _php(3000)));
    final afterFull = await repos.customers.watchBalances().first;
    expect(afterFull.single.balance, _php(0));
    expect(afterFull.single.owes, isFalse);
  });

  test('utang screen helpers compute total, filter, and preview', () {
    final balances = [
      CustomerBalance(
        customer: const Customer(
          id: '1',
          name: 'Maria Santos',
          phone: '09180001111',
        ),
        balance: _php(1500),
      ),
      CustomerBalance(
        customer: const Customer(id: '2', name: 'Pedro Cruz'),
        balance: _php(2500),
      ),
    ];

    expect(computeTotalUtang(balances, Currency.php), _php(4000));
    expect(filterUtangBalances(balances, 'maria'), hasLength(1));
    expect(filterUtangBalances(balances, '0918'), hasLength(1));
    expect(filterUtangBalances(balances, ''), hasLength(2));

    expect(computeRemainingBalance(_php(2500), _php(1000)), _php(1500));
    expect(computeRemainingBalance(_php(2500), _php(3000)), _php(2500));
    expect(computeRemainingBalance(_php(2500), _php(2500)), _php(0));
    expect(computeRemainingBalance(_php(2500), null), _php(2500));
  });
}
