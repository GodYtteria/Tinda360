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
import 'package:tinda360/core/sales/cashier_name.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_return_line.dart';

import '../../support/test_repositories.dart';

T _ok<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

void main() {
  late TestRepositories repos;
  late String trackedId;
  late String untrackedId;
  final today = DayRange.single(LocalDay.fromLocal(DateTime(2026, 11, 17)));

  Future<String> createProduct(String name, int stock) async => _ok(
    await repos.products.create(
      ProductDraft(
        name: name,
        unit: ProductUnit.piece,
        price: _php(1000),
        cost: _php(700),
        initialStock: Quantity.whole(stock),
      ),
    ),
  );

  Future<int> movementCount(String productId) async {
    final rows = await repos.db
        .customSelect(
          'SELECT COUNT(*) AS movement_count FROM stock_movements '
          "WHERE product_id = '$productId' AND is_deleted = 0",
        )
        .getSingle();
    return rows.read<int>('movement_count');
  }

  Future<String> sell(
    String productId,
    int quantity, {
    String? cashierName,
  }) async => _ok(
    await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.cash,
        cashTendered: _php(1000000),
        cashierName: cashierName,
        lines: [
          SaleLineDraft(
            productId: productId,
            quantity: Quantity.whole(quantity),
          ),
        ],
      ),
    ),
  );

  setUp(() async {
    repos = TestRepositories(now: DateTime(2026, 11, 17, 10));
    trackedId = await createProduct('Tracked soda', 5);
    untrackedId = await createProduct('Untracked rice meal', 0);
    await repos.db.customStatement(
      "UPDATE products SET tracks_stock = 0 WHERE id = '$untrackedId'",
    );
  });

  tearDown(() => repos.close());

  group('cashier name on sales', () {
    test('stores trimmed name and exposes it on the record', () async {
      await sell(trackedId, 1, cashierName: '  Ana  ');
      final sales = await repos.sales.watchRecentSales(today).first;
      expect(sales.single.cashierName, 'Ana');
    });

    test('blank and missing names are stored as null', () async {
      await sell(trackedId, 1, cashierName: '   ');
      await sell(trackedId, 1);
      final sales = await repos.sales.watchRecentSales(today).first;
      expect(sales.map((sale) => sale.cashierName), [null, null]);
    });

    test('name is capped at the maximum length', () async {
      await sell(trackedId, 1, cashierName: 'B' * 100);
      final sales = await repos.sales.watchRecentSales(today).first;
      expect(sales.single.cashierName, 'B' * cashierNameMaxLength);
    });
  });

  group('cashier name on returns and ledger deletes', () {
    test('return stores trimmed name, blank stores null', () async {
      final saleId = await sell(trackedId, 3);
      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: trackedId,
            quantity: const Quantity.whole(1),
          ),
        ], cashierName: ' Ben '),
      );
      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: trackedId,
            quantity: const Quantity.whole(1),
          ),
        ], cashierName: '  '),
      );
      final rows = await repos.db
          .customSelect(
            'SELECT cashier_name FROM sale_returns ORDER BY created_at, id',
          )
          .get();
      expect(rows.map((row) => row.readNullable<String>('cashier_name')), [
        'Ben',
        null,
      ]);
    });

    test('ledger delete stores capped name and record exposes it', () async {
      final customerId = _ok(
        await repos.customers.create(const CustomerDraft(name: 'Suki Ana')),
      );
      _ok(
        await repos.sales.record(
          SaleDraft(
            method: PaymentMethod.utang,
            customerId: customerId,
            lines: [
              SaleLineDraft(
                productId: untrackedId,
                quantity: const Quantity.whole(3),
              ),
            ],
          ),
        ),
      );
      _ok(await repos.customers.recordPayment(customerId, _php(1000)));
      final ledger = await repos.customers.watchLedger(customerId).first;
      final payment = ledger.firstWhere((record) => record.isPayment);
      _ok(
        await repos.customers.deleteLedgerEntry(
          payment.id,
          reason: 'wrong',
          deletedByName: '  ${'C' * 60}  ',
        ),
      );
      final after = await repos.customers.watchLedger(customerId).first;
      final deleted = after.firstWhere((record) => record.id == payment.id);
      expect(deleted.deletedByName, 'C' * cashierNameMaxLength);
    });

    test('ledger delete without a name stores null', () async {
      final customerId = _ok(
        await repos.customers.create(const CustomerDraft(name: 'Suki Ben')),
      );
      _ok(
        await repos.sales.record(
          SaleDraft(
            method: PaymentMethod.utang,
            customerId: customerId,
            lines: [
              SaleLineDraft(
                productId: untrackedId,
                quantity: const Quantity.whole(3),
              ),
            ],
          ),
        ),
      );
      _ok(await repos.customers.recordPayment(customerId, _php(1000)));
      final ledger = await repos.customers.watchLedger(customerId).first;
      final payment = ledger.firstWhere((record) => record.isPayment);
      _ok(
        await repos.customers.deleteLedgerEntry(
          payment.id,
          deletedByName: '   ',
        ),
      );
      final after = await repos.customers.watchLedger(customerId).first;
      expect(
        after.firstWhere((record) => record.id == payment.id).deletedByName,
        isNull,
      );
    });
  });

  group('untracked stock', () {
    test(
      'selling beyond zero stock never fails and writes no movement',
      () async {
        final before = await movementCount(untrackedId);
        await sell(untrackedId, 50);
        expect(await movementCount(untrackedId), before);
      },
    );

    test('tracked product still rejects insufficient stock', () async {
      final result = await repos.sales.record(
        SaleDraft(
          method: PaymentMethod.cash,
          cashTendered: _php(1000000),
          lines: [
            SaleLineDraft(
              productId: trackedId,
              quantity: const Quantity.whole(6),
            ),
          ],
        ),
      );
      expect(result, isA<Err<String, SaleFailure>>());
      expect(
        (result as Err<String, SaleFailure>).failure,
        isA<SaleInsufficientStock>(),
      );
    });

    test('tracked sale still writes a stock movement', () async {
      final before = await movementCount(trackedId);
      await sell(trackedId, 2);
      expect(await movementCount(trackedId), before + 1);
    });

    test('void leaves untracked stock movements untouched', () async {
      final saleId = await sell(untrackedId, 4);
      final before = await movementCount(untrackedId);
      _ok(await repos.sales.voidSale(saleId));
      expect(await movementCount(untrackedId), before);
    });

    test('return of untracked product adds no stock movement', () async {
      final saleId = await sell(untrackedId, 4);
      final before = await movementCount(untrackedId);
      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: untrackedId,
            quantity: const Quantity.whole(2),
          ),
        ]),
      );
      expect(await movementCount(untrackedId), before);
    });

    test('return of tracked product still adds stock back', () async {
      final saleId = await sell(trackedId, 4);
      final before = await movementCount(trackedId);
      _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: trackedId,
            quantity: const Quantity.whole(2),
          ),
        ]),
      );
      expect(await movementCount(trackedId), before + 1);
    });
  });
}
