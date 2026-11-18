import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/cash_count_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_return_line.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/cash_count_repository.dart';

import '../../support/sequential_ids.dart';
import '../../support/test_repositories.dart';

T _ok<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

Money _php(int minor) => Money(minor, Currency.php);

void main() {
  late TestRepositories repos;
  late CashCountRepository cashCounts;
  late String productId;
  late String customerId;
  late LocalDay today;

  Future<String> recordSale(
    PaymentMethod method, {
    int quantity = 1,
    Money? tendered,
    String? customer,
    String? reference,
  }) async => _ok(
    await repos.sales.record(
      SaleDraft(
        lines: [
          SaleLineDraft(
            productId: productId,
            quantity: Quantity.whole(quantity),
          ),
        ],
        method: method,
        cashTendered: tendered,
        customerId: customer,
        ewalletReference: reference,
      ),
    ),
  );

  setUp(() async {
    final now = DateTime(2026, 11, 17, 10);
    repos = TestRepositories(now: now);
    cashCounts = CashCountRepository(
      db: repos.db,
      clock: repos.clock,
      ids: SequentialIds(),
      log: repos.log,
      currency: Currency.php,
    );
    today = LocalDay.fromLocal(now);
    productId = _ok(
      await repos.products.create(
        ProductDraft(
          name: 'Coffee sachet',
          unit: ProductUnit.sachet,
          price: _php(1500),
          cost: _php(1000),
          initialStock: const Quantity.whole(100),
        ),
      ),
    );
    customerId = _ok(
      await repos.customers.create(const CustomerDraft(name: 'Ate Glo')),
    );
  });

  tearDown(() async {
    await repos.close();
  });

  test('expected cash is zero with no activity', () async {
    expect(await cashCounts.expectedCashFor(today), _php(0));
  });

  test('expected cash counts only cash sales, not ewallet or utang', () async {
    await recordSale(PaymentMethod.cash, quantity: 2, tendered: _php(5000));
    await recordSale(PaymentMethod.ewallet, quantity: 4, reference: 'REF1');
    await recordSale(
      PaymentMethod.utang,
      quantity: 3,
      customer: customerId,
    );

    expect(await cashCounts.expectedCashFor(today), _php(3000));
  });

  test('voided cash sale is excluded', () async {
    final saleId = await recordSale(
      PaymentMethod.cash,
      quantity: 2,
      tendered: _php(5000),
    );
    await recordSale(PaymentMethod.cash, tendered: _php(1500));
    _ok(await repos.sales.voidSale(saleId));

    expect(await cashCounts.expectedCashFor(today), _php(1500));
  });

  test('utang payments received today are added', () async {
    await recordSale(PaymentMethod.utang, quantity: 4, customer: customerId);
    _ok(await repos.customers.recordPayment(customerId, _php(2500)));

    expect(await cashCounts.expectedCashFor(today), _php(2500));
  });

  test('cash refunds are subtracted but ewallet refunds are not', () async {
    final cashSaleId = await recordSale(
      PaymentMethod.cash,
      quantity: 2,
      tendered: _php(5000),
    );
    final ewalletSaleId = await recordSale(
      PaymentMethod.ewallet,
      quantity: 2,
      reference: 'REF2',
    );
    final nowMs = repos.clock.now().toUtc().millisecondsSinceEpoch;
    for (final entry in [
      (cashSaleId, 'r-1', 1500),
      (ewalletSaleId, 'r-2', 1500),
    ]) {
      await repos.db
          .into(repos.db.saleReturns)
          .insert(
            SaleReturnsCompanion.insert(
              id: entry.$2,
              createdAt: nowMs,
              updatedAt: nowMs,
              saleId: entry.$1,
              productId: productId,
              qtyMilli: 1000,
              refundMinor: entry.$3,
            ),
          );
    }

    expect(await cashCounts.expectedCashFor(today), _php(1500));
  });

  test(
    'utang paid-now cash counts and only its refund leaves the drawer',
    () async {
      final saleId = _ok(
        await repos.sales.record(
          SaleDraft(
            lines: [
              SaleLineDraft(
                productId: productId,
                quantity: const Quantity.whole(4),
              ),
            ],
            method: PaymentMethod.utang,
            customerId: customerId,
            paidNow: _php(2000),
          ),
        ),
      );
      expect(await cashCounts.expectedCashFor(today), _php(2000));

      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: productId,
            quantity: const Quantity.whole(4),
          ),
        ]),
      );

      expect(await cashCounts.expectedCashFor(today), _php(0));
    },
  );

  test('refund made on another day does not affect today', () async {
    final saleId = await recordSale(
      PaymentMethod.cash,
      quantity: 2,
      tendered: _php(5000),
    );
    final yesterdayMs = DateTime(
      2026,
      11,
      16,
      12,
    ).toUtc().millisecondsSinceEpoch;
    await repos.db
        .into(repos.db.saleReturns)
        .insert(
          SaleReturnsCompanion.insert(
            id: 'r-old',
            createdAt: yesterdayMs,
            updatedAt: yesterdayMs,
            saleId: saleId,
            productId: productId,
            qtyMilli: 1000,
            refundMinor: 1500,
          ),
        );

    expect(await cashCounts.expectedCashFor(today), _php(3000));
  });

  test('saveCount stores expected, counted and difference sign', () async {
    await recordSale(PaymentMethod.cash, quantity: 2, tendered: _php(5000));

    _ok(await cashCounts.saveCount(counted: _php(3200), note: '  ok  '));
    _ok(await cashCounts.saveCount(counted: _php(2800)));
    _ok(await cashCounts.saveCount(counted: _php(3000), note: '   '));

    final entries = await cashCounts.watchInRange(DayRange.single(today)).first;
    expect(entries, hasLength(3));
    final byCounted = {
      for (final entry in entries) entry.counted.minorUnits: entry,
    };
    expect(byCounted[3200]!.expected, _php(3000));
    expect(byCounted[3200]!.difference, _php(200));
    expect(byCounted[3200]!.note, 'ok');
    expect(byCounted[2800]!.difference, _php(-200));
    expect(byCounted[3000]!.difference, _php(0));
    expect(byCounted[3000]!.note, isNull);
  });

  test('saveCount rejects negative amount and saves nothing', () async {
    final result = await cashCounts.saveCount(counted: _php(-1));

    expect(result, isA<Err<String, CashCountFailure>>());
    final entries = await cashCounts
        .watchInRange(DayRange(today.plusDays(-7), today))
        .first;
    expect(entries, isEmpty);
  });

  test('saveCount accepts zero counted', () async {
    await recordSale(PaymentMethod.cash, tendered: _php(1500));

    _ok(await cashCounts.saveCount(counted: _php(0)));

    final entries = await cashCounts.watchInRange(DayRange.single(today)).first;
    expect(entries.single.difference, _php(-1500));
  });

  test('history is newest day first, then newest entry first', () async {
    final nowMs = repos.clock.now().toUtc().millisecondsSinceEpoch;
    Future<void> insertCount(String id, int daySerial, int createdAt) => repos
        .db
        .into(repos.db.cashCounts)
        .insert(
          CashCountsCompanion.insert(
            id: id,
            createdAt: createdAt,
            updatedAt: createdAt,
            daySerial: daySerial,
            expectedMinor: 100,
            countedMinor: 100,
            note: const Value(null),
          ),
        );
    await insertCount('older-day', today.plusDays(-2).serial, nowMs + 9000);
    await insertCount('today-first', today.serial, nowMs + 1);
    await insertCount('today-second', today.serial, nowMs + 2);
    await insertCount('outside-range', today.plusDays(-30).serial, nowMs);

    final entries = await cashCounts
        .watchInRange(DayRange(today.plusDays(-6), today))
        .first;

    expect(entries.map((entry) => entry.id).toList(), [
      'today-second',
      'today-first',
      'older-day',
    ]);
  });

  test('startOfLocalDayMs is local midnight', () {
    final midnight = DateTime.fromMillisecondsSinceEpoch(
      startOfLocalDayMs(today),
    );
    expect(midnight, DateTime(2026, 11, 17));
  });
}
