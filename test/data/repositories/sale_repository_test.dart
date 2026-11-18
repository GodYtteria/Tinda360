import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/customer_failure.dart';
import 'package:tinda360/core/failures/sale_failure.dart';
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

void main() {
  late TestRepositories repos;
  late String noodlesId;
  late String riceId;
  final today = DayRange.single(LocalDay.fromLocal(DateTime(2026, 11, 17)));

  setUp(() async {
    repos = TestRepositories();
    noodlesId = _ok(
      await repos.products.create(
        ProductDraft(
          name: 'Instant noodles',
          unit: ProductUnit.pack,
          price: _php(1500),
          cost: _php(1200),
          initialStock: const Quantity.whole(10),
        ),
      ),
    );
    riceId = _ok(
      await repos.products.create(
        ProductDraft(
          name: 'Bigas',
          unit: ProductUnit.kilo,
          price: _php(4500),
          cost: _php(4000),
          initialStock: const Quantity.whole(25),
        ),
      ),
    );
  });

  tearDown(() => repos.close());

  Future<Quantity> stockOf(String productId) async {
    final products = await repos.products.watchActive().first;
    return products.firstWhere((p) => p.product.id == productId).stock;
  }

  test('a cash sale takes stock out and shows in the day summary', () async {
    final result = await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.cash,
        cashTendered: _php(10000),
        lines: [
          SaleLineDraft(
            productId: noodlesId,
            quantity: const Quantity.whole(3),
          ),
          SaleLineDraft(productId: riceId, quantity: const Quantity.milli(250)),
        ],
      ),
    );
    _ok(result);

    expect(await stockOf(noodlesId), const Quantity.whole(7));
    expect(await stockOf(riceId), const Quantity.milli(24750));

    final summary = await repos.sales.watchSummary(today).first;
    expect(summary.saleCount, 1);
    expect(summary.revenue, _php(4500 + 1125));
    expect(summary.profit, _php((4500 - 3600) + (1125 - 1000)));
    expect(repos.log.events, isEmpty);
  });

  test('short cash is rejected and nothing is written', () async {
    final result = await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.cash,
        cashTendered: _php(2000),
        lines: [
          SaleLineDraft(
            productId: noodlesId,
            quantity: const Quantity.whole(3),
          ),
        ],
      ),
    );
    expect(
      result,
      isA<Err<String, SaleFailure>>().having(
        (errorResult) => errorResult.failure,
        'failure',
        isA<SalePaymentTooLow>(),
      ),
    );
    expect(await stockOf(noodlesId), const Quantity.whole(10));
    expect((await repos.sales.watchSummary(today).first).saleCount, 0);
  });

  test(
    'selling more than the stock is rejected and nothing is written',
    () async {
      final result = await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.cash,
          cashTendered: _php(100000),
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(11),
            ),
          ],
        ),
      );
      expect(
        result,
        isA<Err<String, SaleFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SaleInsufficientStock>()
              .having((failure) => failure.productId, 'productId', noodlesId)
              .having(
                (failure) => failure.available,
                'available',
                const Quantity.whole(10),
              ),
        ),
      );
      expect(await stockOf(noodlesId), const Quantity.whole(10));
      expect((await repos.sales.watchSummary(today).first).saleCount, 0);
    },
  );

  test(
    'repeated lines of one product are checked against stock together',
    () async {
      final result = await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.ewallet,
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(6),
            ),
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(6),
            ),
          ],
        ),
      );
      expect(
        result,
        isA<Err<String, SaleFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SaleInsufficientStock>(),
        ),
      );
      expect(await stockOf(noodlesId), const Quantity.whole(10));
    },
  );

  test(
    'selling exactly the stock succeeds and a second sale is rejected',
    () async {
      final first = await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.ewallet,
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(10),
            ),
          ],
        ),
      );
      expect(first, isA<Ok<String, SaleFailure>>());
      expect(await stockOf(noodlesId), Quantity.zero);

      final second = await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.ewallet,
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(1),
            ),
          ],
        ),
      );
      expect(
        second,
        isA<Err<String, SaleFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SaleInsufficientStock>(),
        ),
      );
      expect(await stockOf(noodlesId), Quantity.zero);
    },
  );

  test('an empty cart is rejected', () async {
    final result = await repos.sales.record(
      const SaleDraft(method: PaymentMethod.ewallet, lines: []),
    );
    expect(
      result,
      isA<Err<String, SaleFailure>>().having(
        (errorResult) => errorResult.failure,
        'failure',
        isA<SaleHasNoLines>(),
      ),
    );
  });

  test('half a pack is rejected', () async {
    final result = await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.ewallet,
        lines: [
          SaleLineDraft(
            productId: noodlesId,
            quantity: const Quantity.milli(500),
          ),
        ],
      ),
    );
    expect(
      result,
      isA<Err<String, SaleFailure>>().having(
        (errorResult) => errorResult.failure,
        'failure',
        isA<SaleQuantityInvalid>(),
      ),
    );
    expect(await stockOf(noodlesId), const Quantity.whole(10));
  });

  test('utang needs a customer', () async {
    final result = await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.utang,
        lines: [
          SaleLineDraft(
            productId: noodlesId,
            quantity: const Quantity.whole(1),
          ),
        ],
      ),
    );
    expect(
      result,
      isA<Err<String, SaleFailure>>().having(
        (errorResult) => errorResult.failure,
        'failure',
        isA<SaleCustomerRequired>(),
      ),
    );
  });

  test('utang adds to the balance and payments reduce it', () async {
    final customerId = _ok(
      await repos.customers.create(const CustomerDraft(name: 'Mang Ben')),
    );
    _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.utang,
          customerId: customerId,
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(2),
            ),
          ],
        ),
      ),
    );

    var balances = await repos.customers.watchBalances().first;
    expect(balances.single.balance, _php(3000));

    _ok(await repos.customers.recordPayment(customerId, _php(1000)));
    balances = await repos.customers.watchBalances().first;
    expect(balances.single.balance, _php(2000));
  });

  test(
    'voiding a partly paid utang sale is refused and changes nothing',
    () async {
      final customerId = _ok(
        await repos.customers.create(const CustomerDraft(name: 'Mang Tonyo')),
      );
      final saleId = _ok(
        await repos.sales.record(
          SaleDraft(
            method: PaymentMethod.utang,
            customerId: customerId,
            lines: [
              SaleLineDraft(
                productId: noodlesId,
                quantity: const Quantity.whole(2),
              ),
            ],
          ),
        ),
      );
      _ok(await repos.customers.recordPayment(customerId, _php(1000)));

      final result = await repos.sales.voidSale(saleId);

      expect(
        result,
        isA<Err<void, SaleFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SaleVoidAfterPayment>(),
        ),
      );
      final balances = await repos.customers.watchBalances().first;
      expect(balances.single.balance, _php(2000));
      expect(await stockOf(noodlesId), const Quantity.whole(8));
    },
  );

  test(
    'voiding an unpaid utang sale works once, then reports not found',
    () async {
      final customerId = _ok(
        await repos.customers.create(const CustomerDraft(name: 'Aling Puring')),
      );
      final saleId = _ok(
        await repos.sales.record(
          SaleDraft(
            method: PaymentMethod.utang,
            customerId: customerId,
            lines: [
              SaleLineDraft(
                productId: noodlesId,
                quantity: const Quantity.whole(1),
              ),
            ],
          ),
        ),
      );

      expect(await repos.sales.voidSale(saleId), isA<Ok<void, SaleFailure>>());
      expect(
        await repos.sales.voidSale(saleId),
        isA<Err<void, SaleFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SaleNotFound>(),
        ),
      );
      final balances = await repos.customers.watchBalances().first;
      expect(balances.single.balance, _php(0));
      expect(await stockOf(noodlesId), const Quantity.whole(10));
    },
  );

  test('a payment above the balance is rejected', () async {
    final customerId = _ok(
      await repos.customers.create(const CustomerDraft(name: 'Aling Rosa')),
    );
    final result = await repos.customers.recordPayment(customerId, _php(500));
    expect(
      result,
      isA<Err<void, CustomerFailure>>().having(
        (errorResult) => errorResult.failure,
        'failure',
        isA<PaymentExceedsBalance>(),
      ),
    );
  });

  test('a fresh database has an unfinished store profile', () async {
    final profile = await repos.store.watch().first;
    expect(profile.onboardingDone, isFalse);
    expect(profile.currency, Currency.php);

    _ok(await repos.store.completeOnboarding('Tindahan ni Aling Rosa'));
    final updated = await repos.store.watch().first;
    expect(updated.onboardingDone, isTrue);
    expect(updated.name, 'Tindahan ni Aling Rosa');
  });

  test(
    'watchRecentSales and voidSale restore stock and reverse utang',
    () async {
      final productId = _ok(
        await repos.products.create(
          ProductDraft(
            name: 'Sardinas',
            unit: ProductUnit.can,
            price: Money(2500, Currency.php),
            cost: Money(2000, Currency.php),
            initialStock: Quantity.whole(10),
          ),
        ),
      );
      final customerId = _ok(
        await repos.customers.create(const CustomerDraft(name: 'Mang Ben')),
      );
      final saleId = _ok(
        await repos.sales.record(
          SaleDraft(
            lines: [
              SaleLineDraft(
                productId: productId,
                quantity: Quantity.whole(3),
              ),
            ],
            method: PaymentMethod.utang,
            customerId: customerId,
          ),
        ),
      );

      final today = DayRange.single(LocalDay.fromLocal(repos.clock.now()));
      final beforeVoid = await repos.sales.watchRecentSales(today).first;
      expect(beforeVoid.length, 1);
      expect(beforeVoid.first.id, saleId);
      expect(beforeVoid.first.customerName, 'Mang Ben');
      expect(beforeVoid.first.total.minorUnits, 7500);

      _ok(await repos.sales.voidSale(saleId));

      final afterVoid = await repos.sales.watchRecentSales(today).first;
      expect(afterVoid, isEmpty);

      final products = await repos.products.watchActive().first;
      final restoredProduct = products.firstWhere(
        (item) => item.product.id == productId,
      );
      expect(restoredProduct.stock.milli, 10000);

      final balances = await repos.customers.watchBalances().first;
      expect(balances.single.balance.minorUnits, 0);
    },
  );

  test('a cash sale keeps the cash handed over for reprints', () async {
    _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.cash,
          cashTendered: _php(10000),
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(2),
            ),
          ],
        ),
      ),
    );

    final sale = (await repos.sales.watchRecentSales(today).first).single;

    expect(sale.paid, sale.total);
    expect(sale.tendered, _php(10000));
    expect(sale.received, _php(10000));
    expect(sale.change, _php(10000) - sale.total);
  });

  test('a non-cash sale has no tendered amount and no change', () async {
    _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.ewallet,
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(1),
            ),
          ],
        ),
      ),
    );

    final sale = (await repos.sales.watchRecentSales(today).first).single;

    expect(sale.tendered, isNull);
    expect(sale.received, sale.total);
    expect(sale.change, _php(0));
  });
}
