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
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/data/db/id_generator.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';

import '../../support/test_repositories.dart';

final class _PrefixedIds implements IdGenerator {
  new(this._prefix);

  final String _prefix;
  var _next = 0;

  @override
  String next() => '$_prefix-${++_next}';
}

T _ok<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

Money _php(int minor) => Money(minor, Currency.php);

void main() {
  late TestRepositories repos;
  late String noodlesId;
  late String customerId;
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
          initialStock: const Quantity.whole(50),
        ),
      ),
    );
    customerId = _ok(
      await repos.customers.create(const CustomerDraft(name: 'Ate Maria')),
    );
  });

  tearDown(() => repos.close());

  Future<Result<String, SaleFailure>> utangSale({
    Money? paidNow,
    int quantity = 2,
  }) => repos.sales.record(
    SaleDraft(
      method: PaymentMethod.utang,
      customerId: customerId,
      paidNow: paidNow,
      lines: [
        SaleLineDraft(
          productId: noodlesId,
          quantity: Quantity.whole(quantity),
        ),
      ],
    ),
  );

  Future<int> debtLedgerTotal() async {
    final ledger = await repos.customers.watchLedger(customerId).first;
    return ledger
        .where((entry) => entry.isDebt)
        .fold<int>(0, (sum, entry) => sum + entry.amount.minorUnits);
  }

  group('split payment', () {
    test('no paid now writes the whole total as debt', () async {
      _ok(await utangSale());
      final sale = (await repos.sales.watchRecentSales(today).first).single;
      expect(sale.paid, _php(0));
      expect(await debtLedgerTotal(), 3000);
    });

    test('partial paid now stores paid and debts only the rest', () async {
      _ok(await utangSale(paidNow: _php(1000)));
      final sale = (await repos.sales.watchRecentSales(today).first).single;
      expect(sale.total, _php(3000));
      expect(sale.paid, _php(1000));
      expect(await debtLedgerTotal(), 2000);
    });

    test('paid now equal to total writes no debt entry', () async {
      _ok(await utangSale(paidNow: _php(3000)));
      final sale = (await repos.sales.watchRecentSales(today).first).single;
      expect(sale.paid, _php(3000));
      expect(await repos.customers.watchLedger(customerId).first, isEmpty);
    });

    test('paid now above total is rejected and nothing is written', () async {
      final result = await utangSale(paidNow: _php(3001));
      expect(
        result,
        isA<Err<String, SaleFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SalePaidNowInvalid>(),
        ),
      );
      expect(await repos.sales.watchRecentSales(today).first, isEmpty);
      expect(await repos.customers.watchLedger(customerId).first, isEmpty);
    });

    test('negative paid now is rejected', () async {
      final result = await utangSale(paidNow: _php(-1));
      expect(
        result,
        isA<Err<String, SaleFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SalePaidNowInvalid>(),
        ),
      );
    });

    test('voiding a split sale removes its partial debt', () async {
      final saleId = _ok(await utangSale(paidNow: _php(1000)));
      _ok(await repos.sales.voidSale(saleId));
      expect(await debtLedgerTotal(), 0);
    });
  });

  group('line price override', () {
    Future<Result<String, SaleFailure>> cashSale(Money? override) =>
        repos.sales.record(
          SaleDraft(
            method: PaymentMethod.cash,
            cashTendered: _php(10000),
            lines: [
              SaleLineDraft(
                productId: noodlesId,
                quantity: const Quantity.whole(3),
                unitPriceOverride: override,
              ),
            ],
          ),
        );

    test('override drives unit price, total and profit', () async {
      _ok(await cashSale(_php(1300)));
      final sale = (await repos.sales.watchRecentSales(today).first).single;
      expect(sale.lines.single.unitPrice, _php(1300));
      expect(sale.total, _php(3900));
      final summary = await repos.sales.watchSummary(today).first;
      expect(summary.revenue, _php(3900));
      expect(summary.profit, _php(3900 - 3600));
    });

    test('free line (zero price) is allowed and loses the cost', () async {
      _ok(await cashSale(_php(0)));
      final summary = await repos.sales.watchSummary(today).first;
      expect(summary.revenue, _php(0));
      expect(summary.profit, _php(-3600));
    });

    test('negative override is rejected', () async {
      final result = await cashSale(_php(-1));
      expect(
        result,
        isA<Err<String, SaleFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SalePriceInvalid>(),
        ),
      );
      expect(await repos.sales.watchRecentSales(today).first, isEmpty);
    });

    test('product saved price never changes', () async {
      _ok(await cashSale(_php(1300)));
      final products = await repos.products.watchActive().first;
      expect(products.single.product.price, _php(1500));
    });
  });

  group('receipt number', () {
    test('counts per day in created_at order across days', () async {
      var now = DateTime(2026, 11, 17, 9);
      final ids = _PrefixedIds('receipt');
      final sales = SaleRepository(
        db: repos.db,
        clock: Clock(() => now),
        ids: ids,
        log: repos.log,
        currency: Currency.php,
      );
      Future<String> sell() async => _ok(
        await sales.record(
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

      final firstId = await sell();
      now = DateTime(2026, 11, 17, 10);
      final secondId = await sell();
      now = DateTime(2026, 11, 18, 8);
      final thirdId = await sell();

      expect(await sales.receiptNumberOf(firstId), '20261117-001');
      expect(await sales.receiptNumberOf(secondId), '20261117-002');
      expect(await sales.receiptNumberOf(thirdId), '20261118-001');

      final range = DayRange(
        LocalDay.fromLocal(DateTime(2026, 11, 17)),
        LocalDay.fromLocal(DateTime(2026, 11, 18)),
      );
      final records = await sales.watchRecentSales(range).first;
      expect(
        {
          for (final record in records) record.id: record.receiptNumber,
        },
        {
          firstId: '20261117-001',
          secondId: '20261117-002',
          thirdId: '20261118-001',
        },
      );

      final newestTwo = await sales.watchRecentSales(range, limit: 2).first;
      expect(newestTwo.map((record) => record.id), [thirdId, secondId]);
      expect(newestTwo.map((record) => record.receiptNumber), [
        '20261118-001',
        '20261117-002',
      ]);
      final newestOne = await sales.watchRecentSales(range, limit: 1).first;
      expect(newestOne.single.id, thirdId);
    });

    test('record carries the suki name and e-wallet reference', () async {
      _ok(await utangSale(paidNow: _php(500)));
      _ok(
        await repos.sales.record(
          SaleDraft(
            method: PaymentMethod.ewallet,
            ewalletReference: 'GC-1234',
            lines: [
              SaleLineDraft(
                productId: noodlesId,
                quantity: const Quantity.whole(1),
              ),
            ],
          ),
        ),
      );
      final records = await repos.sales.watchRecentSales(today).first;
      final utang = records.firstWhere(
        (record) => record.method == PaymentMethod.utang,
      );
      final ewallet = records.firstWhere(
        (record) => record.method == PaymentMethod.ewallet,
      );
      expect(utang.customerName, 'Ate Maria');
      expect(ewallet.customerName, isNull);
      expect(ewallet.ewalletReference, 'GC-1234');
      expect(ewallet.receiptNumber, '20261117-002');
      expect(utang.receiptNumber, '20261117-001');
    });
  });
}
