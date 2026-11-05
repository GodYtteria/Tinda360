import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/sale_failure.dart';
import 'package:tinda360/core/failures/sale_return_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_return_line.dart';
import 'package:tinda360/data/db/id_generator.dart';
import 'package:tinda360/data/repositories/cash_count_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';

import '../../support/test_repositories.dart';

T _ok<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

Failure _err<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok() => fail('Expected Err'),
      Err(:final failure) => failure,
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
    return products.firstWhere((entry) => entry.product.id == productId).stock;
  }

  Future<String> sellNoodlesAndRice() async => _ok(
    await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.cash,
        cashTendered: _php(100000),
        lines: [
          SaleLineDraft(
            productId: noodlesId,
            quantity: const Quantity.whole(4),
          ),
          SaleLineDraft(productId: riceId, quantity: const Quantity.whole(2)),
        ],
      ),
    ),
  );

  Future<Money> balanceOf(String customerId) async {
    final balances = await repos.customers.watchBalances().first;
    return balances
        .firstWhere((entry) => entry.customer.id == customerId)
        .balance;
  }

  test('partial return refunds the line price and puts stock back', () async {
    final saleId = await sellNoodlesAndRice();
    expect(await stockOf(noodlesId), const Quantity.whole(6));

    final refund = _ok(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(1)),
      ], reason: 'torn pack'),
    );

    expect(refund, _php(1500));
    expect(await stockOf(noodlesId), const Quantity.whole(7));
    expect(await stockOf(riceId), const Quantity.whole(23));
    expect(await repos.saleReturns.watchReturnedQuantities(saleId).first, {
      noodlesId: const Quantity.whole(1),
    });
    expect(repos.log.events, isEmpty);
  });

  test('returning more than sold is rejected and writes nothing', () async {
    final saleId = await sellNoodlesAndRice();

    final failure = _err(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: riceId, quantity: const Quantity.whole(1)),
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(5)),
      ]),
    );

    expect(failure, isA<SaleReturnTooMany>());
    expect((failure as SaleReturnTooMany).productId, noodlesId);
    expect(failure.returnable, const Quantity.whole(4));
    expect(await stockOf(riceId), const Quantity.whole(23));
    expect(await stockOf(noodlesId), const Quantity.whole(6));
    expect(
      await repos.saleReturns.watchReturnedQuantities(saleId).first,
      isEmpty,
    );
  });

  test('repeated returns accumulate and the limit shrinks', () async {
    final saleId = await sellNoodlesAndRice();
    _ok(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(3)),
      ]),
    );
    _ok(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(1)),
      ]),
    );

    expect(await repos.saleReturns.watchReturnedQuantities(saleId).first, {
      noodlesId: const Quantity.whole(4),
    });
    final failure = _err(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(1)),
      ]),
    );
    expect(failure, isA<SaleReturnTooMany>());
    expect((failure as SaleReturnTooMany).returnable, Quantity.zero);
    expect(await stockOf(noodlesId), const Quantity.whole(10));
  });

  test('fractional kilo returns refund the proportional price', () async {
    final saleId = _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.cash,
          cashTendered: _php(100000),
          lines: [
            SaleLineDraft(
              productId: riceId,
              quantity: const Quantity.milli(1500),
            ),
          ],
        ),
      ),
    );

    final refund = _ok(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: riceId, quantity: const Quantity.milli(250)),
      ]),
    );

    expect(refund, _php(1125));
    expect(await stockOf(riceId), const Quantity.milli(23750));
  });

  test('fraction of a piece-unit product is rejected', () async {
    final saleId = await sellNoodlesAndRice();
    final failure = _err(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(
          productId: noodlesId,
          quantity: const Quantity.milli(500),
        ),
      ]),
    );
    expect(failure, isA<SaleReturnQuantityInvalid>());
    expect(await stockOf(noodlesId), const Quantity.whole(6));
  });

  test('zero quantity and empty list are rejected', () async {
    final saleId = await sellNoodlesAndRice();
    expect(
      _err(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(productId: noodlesId, quantity: Quantity.zero),
        ]),
      ),
      isA<SaleReturnQuantityInvalid>(),
    );
    expect(
      _err(await repos.saleReturns.returnItems(saleId, [])),
      isA<SaleReturnNothingSelected>(),
    );
  });

  test('unknown sale and voided sale are rejected', () async {
    expect(
      _err(
        await repos.saleReturns.returnItems('missing', [
          SaleReturnLine(
            productId: noodlesId,
            quantity: const Quantity.whole(1),
          ),
        ]),
      ),
      isA<SaleReturnNotFound>(),
    );

    final saleId = await sellNoodlesAndRice();
    _ok(await repos.sales.voidSale(saleId));
    expect(
      _err(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: noodlesId,
            quantity: const Quantity.whole(1),
          ),
        ]),
      ),
      isA<SaleReturnSaleVoided>(),
    );
    expect(await stockOf(noodlesId), const Quantity.whole(10));
  });

  test(
    'utang sale return lowers the customer balance, cash sale does not',
    () async {
      final customerId = _ok(
        await repos.customers.create(const CustomerDraft(name: 'Ate Maria')),
      );
      final saleId = _ok(
        await repos.sales.record(
          SaleDraft(
            method: PaymentMethod.utang,
            customerId: customerId,
            lines: [
              SaleLineDraft(
                productId: noodlesId,
                quantity: const Quantity.whole(4),
              ),
            ],
          ),
        ),
      );
      expect(await balanceOf(customerId), _php(6000));

      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: noodlesId,
            quantity: const Quantity.whole(2),
          ),
        ]),
      );
      expect(await balanceOf(customerId), _php(3000));
      final ledger = await repos.customers.watchLedger(customerId).first;
      expect(ledger.where((entry) => entry.saleId == saleId), hasLength(2));

      final cashSaleId = await sellNoodlesAndRice();
      _ok(
        await repos.saleReturns.returnItems(cashSaleId, [
          SaleReturnLine(
            productId: noodlesId,
            quantity: const Quantity.whole(1),
          ),
        ]),
      );
      expect(await balanceOf(customerId), _php(3000));
    },
  );

  test('partly paid utang return credits only what is still owed', () async {
    final customerId = _ok(
      await repos.customers.create(const CustomerDraft(name: 'Mang Ben')),
    );
    final saleId = _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.utang,
          customerId: customerId,
          paidNow: _php(2000),
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(4),
            ),
          ],
        ),
      ),
    );
    expect(await balanceOf(customerId), _php(4000));

    final refund = _ok(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(4)),
      ]),
    );

    expect(refund, _php(6000));
    expect(await balanceOf(customerId), _php(0));
  });

  test('return outcome splits utang credit from cash back', () async {
    final customerId = _ok(
      await repos.customers.create(const CustomerDraft(name: 'Ate Lina')),
    );
    final saleId = _ok(
      await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.utang,
          customerId: customerId,
          paidNow: _php(2000),
          lines: [
            SaleLineDraft(
              productId: noodlesId,
              quantity: const Quantity.whole(4),
            ),
          ],
        ),
      ),
    );

    final outcome = _ok(
      await repos.saleReturns.returnItemsWithOutcome(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(4)),
      ]),
    );

    expect(outcome.refund, _php(6000));
    expect(outcome.creditedToUtang, _php(4000));
    expect(outcome.cashBack, _php(2000));
  });

  test('return outcome on a cash sale is all cash back', () async {
    final saleId = await sellNoodlesAndRice();

    final outcome = _ok(
      await repos.saleReturns.returnItemsWithOutcome(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(1)),
      ]),
    );

    expect(outcome.creditedToUtang, _php(0));
    expect(outcome.cashBack, outcome.refund);
  });

  test(
    'return on utang already paid off never pushes the balance below zero',
    () async {
      final customerId = _ok(
        await repos.customers.create(const CustomerDraft(name: 'Aling Nena')),
      );
      final saleId = _ok(
        await repos.sales.record(
          SaleDraft(
            method: PaymentMethod.utang,
            customerId: customerId,
            lines: [
              SaleLineDraft(
                productId: noodlesId,
                quantity: const Quantity.whole(4),
              ),
            ],
          ),
        ),
      );
      _ok(await repos.customers.recordPayment(customerId, _php(6000)));
      expect(await balanceOf(customerId), _php(0));

      final refund = _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: noodlesId,
            quantity: const Quantity.whole(2),
          ),
        ]),
      );

      expect(refund, _php(3000));
      expect(await balanceOf(customerId), _php(0));
    },
  );

  test(
    'split fractional returns never refund more than the line total',
    () async {
      final sugarId = _ok(
        await repos.products.create(
          ProductDraft(
            name: 'Asukal',
            unit: ProductUnit.kilo,
            price: _php(333),
            cost: _php(300),
            initialStock: const Quantity.whole(5),
          ),
        ),
      );
      final saleId = _ok(
        await repos.sales.record(
          SaleDraft(
            method: PaymentMethod.cash,
            cashTendered: _php(500),
            lines: [
              SaleLineDraft(
                productId: sugarId,
                quantity: const Quantity.milli(1500),
              ),
            ],
          ),
        ),
      );

      var refunded = _php(0);
      for (var step = 0; step < 3; step++) {
        refunded += _ok(
          await repos.saleReturns.returnItems(saleId, [
            SaleReturnLine(
              productId: sugarId,
              quantity: const Quantity.milli(500),
            ),
          ]),
        );
      }

      expect(refunded, _php(500));
    },
  );

  test(
    'summary, profit, top products and recent sales reflect returns',
    () async {
      final saleId = await sellNoodlesAndRice();
      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: noodlesId,
            quantity: const Quantity.whole(1),
          ),
          SaleReturnLine(productId: riceId, quantity: const Quantity.whole(2)),
        ]),
      );

      final summary = await repos.sales.watchSummary(today).first;
      expect(summary.saleCount, 1);
      expect(summary.revenue, _php(4 * 1500 + 2 * 4500 - 1500 - 2 * 4500));
      expect(summary.profit, _php((3 * 1500 - 3 * 1200)));

      final top = await repos.sales.watchTopProducts(today).first;
      expect(top, hasLength(1));
      expect(top.single.productId, noodlesId);
      expect(top.single.totalQuantity, const Quantity.whole(3));
      expect(top.single.totalRevenue, _php(4500));

      final record = (await repos.sales.watchRecentSales(today).first).single;
      expect(record.refunded, _php(1500 + 9000));
      expect(record.netTotal, _php(4500));
      final noodlesLine = record.lines.firstWhere(
        (line) => line.productId == noodlesId,
      );
      expect(noodlesLine.returnedQuantity, const Quantity.whole(1));
      expect(noodlesLine.returnableQuantity, const Quantity.whole(3));
      final riceLine = record.lines.firstWhere(
        (line) => line.productId == riceId,
      );
      expect(riceLine.returnableQuantity, Quantity.zero);
    },
  );

  test(
    'voiding a sale that has returns is blocked and nothing changes',
    () async {
      final saleId = await sellNoodlesAndRice();
      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: noodlesId,
            quantity: const Quantity.whole(1),
          ),
        ]),
      );

      expect(
        _err(await repos.sales.voidSale(saleId)),
        isA<SaleVoidAfterReturn>(),
      );
      expect(await stockOf(noodlesId), const Quantity.whole(7));
      expect(await stockOf(riceId), const Quantity.whole(23));
      expect((await repos.sales.watchSummary(today).first).saleCount, 1);
    },
  );

  test('voiding a sale without returns still works', () async {
    final saleId = await sellNoodlesAndRice();
    _ok(await repos.sales.voidSale(saleId));
    expect(await stockOf(noodlesId), const Quantity.whole(10));
  });

  group('return of an earlier day sale', () {
    final saleDay = LocalDay.fromLocal(DateTime(2026, 11, 15));
    final saleRange = DayRange.single(saleDay);
    final bothDays = DayRange(saleDay, today.first);

    Future<String> sellNoodlesAndRiceOnSaleDay() async {
      final earlierSales = SaleRepository(
        db: repos.db,
        clock: Clock.fixed(DateTime(2026, 11, 15, 9)),
        ids: _PrefixedIds('earlier'),
        log: repos.log,
        currency: Currency.php,
      );
      return _ok(
        await earlierSales.record(
          SaleDraft(
            method: PaymentMethod.cash,
            cashTendered: _php(100000),
            lines: [
              SaleLineDraft(
                productId: noodlesId,
                quantity: const Quantity.whole(4),
              ),
              SaleLineDraft(
                productId: riceId,
                quantity: const Quantity.whole(2),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> returnOneNoodlePackToday(String saleId) async {
      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: noodlesId,
            quantity: const Quantity.whole(1),
          ),
        ]),
      );
    }

    test('sale day summary does not change after the return', () async {
      final saleId = await sellNoodlesAndRiceOnSaleDay();
      final before = await repos.sales.watchSummary(saleRange).first;

      await returnOneNoodlePackToday(saleId);

      final after = await repos.sales.watchSummary(saleRange).first;
      expect(after.revenue, before.revenue);
      expect(after.cost, before.cost);
      expect(after.revenue, _php(15000));
      expect(after.profit, _php(15000 - 4800 - 8000));
      expect(after.saleCount, 1);
    });

    test('return day summary shows the negative adjustment', () async {
      final saleId = await sellNoodlesAndRiceOnSaleDay();
      await returnOneNoodlePackToday(saleId);

      final summary = await repos.sales.watchSummary(today).first;
      expect(summary.revenue, _php(-1500));
      expect(summary.cost, _php(-1200));
      expect(summary.profit, _php(-1500 + 1200));
      expect(summary.saleCount, 0);
    });

    test('range covering both days nets the return once', () async {
      final saleId = await sellNoodlesAndRiceOnSaleDay();
      await returnOneNoodlePackToday(saleId);

      final summary = await repos.sales.watchSummary(bothDays).first;
      expect(summary.revenue, _php(15000 - 1500));
      expect(summary.cost, _php(12800 - 1200));
      expect(summary.profit, _php(13500 - 11600));
      expect(summary.saleCount, 1);
    });

    test('top products are adjusted on the return day only', () async {
      final saleId = await sellNoodlesAndRiceOnSaleDay();
      await returnOneNoodlePackToday(saleId);

      final onSaleDay = await repos.sales.watchTopProducts(saleRange).first;
      final noodlesOnSaleDay = onSaleDay.firstWhere(
        (entry) => entry.productId == noodlesId,
      );
      expect(noodlesOnSaleDay.totalQuantity, const Quantity.whole(4));
      expect(noodlesOnSaleDay.totalRevenue, _php(6000));

      expect(await repos.sales.watchTopProducts(today).first, isEmpty);

      final overall = await repos.sales.watchTopProducts(bothDays).first;
      final noodlesOverall = overall.firstWhere(
        (entry) => entry.productId == noodlesId,
      );
      expect(noodlesOverall.totalQuantity, const Quantity.whole(3));
      expect(noodlesOverall.totalRevenue, _php(4500));
    });

    test('return day top products net against that day sales', () async {
      final saleId = await sellNoodlesAndRiceOnSaleDay();
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
      await returnOneNoodlePackToday(saleId);

      final top = await repos.sales.watchTopProducts(today).first;
      expect(top.single.productId, noodlesId);
      expect(top.single.totalQuantity, const Quantity.whole(1));
      expect(top.single.totalRevenue, _php(1500));
    });

    test('recent sales keep the sale returned and refunded amounts', () async {
      final saleId = await sellNoodlesAndRiceOnSaleDay();
      await returnOneNoodlePackToday(saleId);

      final record =
          (await repos.sales.watchRecentSales(saleRange).first).single;
      expect(record.refunded, _php(1500));
      final noodlesLine = record.lines.firstWhere(
        (line) => line.productId == noodlesId,
      );
      expect(noodlesLine.returnedQuantity, const Quantity.whole(1));
      expect(noodlesLine.returnableQuantity, const Quantity.whole(3));
      expect(await repos.sales.watchRecentSales(today).first, isEmpty);
    });

    test('cash count and summary agree on the return day', () async {
      final saleId = await sellNoodlesAndRiceOnSaleDay();
      await returnOneNoodlePackToday(saleId);
      final cashCounts = CashCountRepository(
        db: repos.db,
        clock: repos.clock,
        ids: _PrefixedIds('count'),
        log: repos.log,
        currency: Currency.php,
      );

      final expectedCash = await cashCounts.expectedCashFor(today.first);
      final summary = await repos.sales.watchSummary(today).first;
      expect(expectedCash, _php(-1500));
      expect(summary.revenue, expectedCash);
    });
  });
}

final class _PrefixedIds implements IdGenerator {
  _PrefixedIds(this._prefix);

  final String _prefix;

  var _next = 0;

  @override
  String next() => '$_prefix-${++_next}';
}
