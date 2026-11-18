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
import 'package:tinda360/core/sales/sale_return_line.dart';
import 'package:tinda360/data/repositories/cash_count_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';

import '../../support/sequential_ids.dart';
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
  late CashCountRepository cashCounts;
  late String noodlesId;
  late String customerId;
  final today = DayRange.single(LocalDay.fromLocal(DateTime(2026, 11, 17)));

  setUp(() async {
    repos = TestRepositories();
    cashCounts = CashCountRepository(
      db: repos.db,
      clock: repos.clock,
      ids: SequentialIds(),
      log: repos.log,
      currency: Currency.php,
    );
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

  List<SaleLineDraft> noodleLines(int quantity) => [
    SaleLineDraft(productId: noodlesId, quantity: Quantity.whole(quantity)),
  ];

  Future<Result<String, SaleFailure>> utangSale({
    Money? interest,
    Money? paidNow,
    int quantity = 2,
    String? customer,
  }) => repos.sales.record(
    SaleDraft(
      method: PaymentMethod.utang,
      customerId: customer ?? customerId,
      paidNow: paidNow,
      interest: interest,
      lines: noodleLines(quantity),
    ),
  );

  Future<Money> balance() async {
    final balances = await repos.customers.watchBalances().first;
    return balances.single.balance;
  }

  Future<List<String>> ledgerKinds() async {
    final rows = await repos.db
        .customSelect(
          'SELECT kind FROM ledger_entries WHERE is_deleted = 0 ORDER BY kind',
        )
        .get();
    return [for (final row in rows) row.read<String>('kind')];
  }

  test('utang sale with interest writes debt and interest in one go', () async {
    final saleId = _ok(await utangSale(interest: _php(300)));
    expect(await ledgerKinds(), ['debt', 'interest']);
    final interestRows = await repos.db
        .customSelect(
          "SELECT sale_id, amount_minor FROM ledger_entries "
          "WHERE kind = 'interest'",
        )
        .get();
    expect(interestRows.single.read<String>('sale_id'), saleId);
    expect(interestRows.single.read<int>('amount_minor'), 300);
    expect(await balance(), _php(3300));
    final sale = (await repos.sales.watchRecentSales(today).first).single;
    expect(sale.interest, _php(300));
    expect(sale.total, _php(3000));
  });

  test('sale without interest reports zero interest', () async {
    _ok(await utangSale());
    final sale = (await repos.sales.watchRecentSales(today).first).single;
    expect(sale.interest, _php(0));
    expect(await ledgerKinds(), ['debt']);
  });

  test('partly paid utang sale charges interest on top of the rest', () async {
    _ok(await utangSale(paidNow: _php(1000), interest: _php(200)));
    expect(await balance(), _php(2200));
  });

  test('void removes debt and interest and restores stock', () async {
    final saleId = _ok(await utangSale(interest: _php(300)));
    expect(
      await readProductStock(repos.db, noodlesId),
      const Quantity.whole(48),
    );
    _ok(await repos.sales.voidSale(saleId));
    expect(await ledgerKinds(), isEmpty);
    expect(await balance(), _php(0));
    expect(
      await readProductStock(repos.db, noodlesId),
      const Quantity.whole(50),
    );
  });

  test(
    'void after the suki paid more than the debt is still blocked',
    () async {
      final saleId = _ok(await utangSale(interest: _php(300)));
      _ok(await repos.customers.recordPayment(customerId, _php(3300)));
      final failure = _err(await repos.sales.voidSale(saleId));
      expect(failure, isA<SaleVoidAfterPayment>());
      expect(await ledgerKinds(), ['debt', 'interest', 'payment']);
    },
  );

  test('cash sale with interest is rejected and writes nothing', () async {
    final result = await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.cash,
        cashTendered: _php(5000),
        interest: _php(100),
        lines: noodleLines(2),
      ),
    );
    expect(_err(result), isA<SaleInterestInvalid>());
    expect(await repos.sales.watchRecentSales(today).first, isEmpty);
    expect(await ledgerKinds(), isEmpty);
  });

  test('e-wallet sale with interest is rejected', () async {
    final result = await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.ewallet,
        customerId: customerId,
        interest: _php(100),
        lines: noodleLines(2),
      ),
    );
    expect(_err(result), isA<SaleInterestInvalid>());
    expect(await ledgerKinds(), isEmpty);
  });

  test('interest without a customer is rejected', () async {
    final result = await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.utang,
        interest: _php(100),
        lines: noodleLines(2),
      ),
    );
    expect(_err(result), isA<SaleCustomerRequired>());
    expect(await ledgerKinds(), isEmpty);
  });

  test('zero and negative interest are rejected', () async {
    expect(
      _err(await utangSale(interest: _php(0))),
      isA<SaleInterestInvalid>(),
    );
    expect(
      _err(await utangSale(interest: _php(-5))),
      isA<SaleInterestInvalid>(),
    );
    expect(await repos.sales.watchRecentSales(today).first, isEmpty);
  });

  test(
    'interest on a fully paid utang sale is rejected and rolled back',
    () async {
      final result = await utangSale(paidNow: _php(3000), interest: _php(100));
      expect(_err(result), isA<SaleInterestInvalid>());
      expect(await repos.sales.watchRecentSales(today).first, isEmpty);
      expect(await ledgerKinds(), isEmpty);
      expect(
        await readProductStock(repos.db, noodlesId),
        const Quantity.whole(50),
      );
    },
  );

  test('returning goods never credits the interest', () async {
    final saleId = _ok(await utangSale(interest: _php(300)));
    _ok(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(2)),
      ]),
    );
    expect(await balance(), _php(300));
  });

  test('partial return credits only goods value', () async {
    final saleId = _ok(await utangSale(interest: _php(300)));
    _ok(
      await repos.saleReturns.returnItems(saleId, [
        SaleReturnLine(productId: noodlesId, quantity: const Quantity.whole(1)),
      ]),
    );
    expect(await balance(), _php(1800));
  });

  test('interest does not change revenue, profit or cash count', () async {
    _ok(await utangSale(paidNow: _php(1000), interest: _php(300)));
    final summary = await repos.sales.watchSummary(today).first;
    expect(summary.revenue, _php(3000));
    expect(summary.cost, _php(2400));
    final expectedCash = await cashCounts.expectedCashFor(
      LocalDay.fromLocal(DateTime(2026, 11, 17)),
    );
    expect(expectedCash, _php(1000));
    final top = await repos.sales.watchTopProducts(today).first;
    expect(top.single.totalRevenue, _php(3000));
  });
}
