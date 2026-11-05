import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';

import '../../support/recording_app_log.dart';
import '../../support/sequential_ids.dart';
import '../../support/test_database.dart';

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
  late AppDatabase database;
  late DateTime currentTime;
  late ProductRepository products;
  late SaleRepository sales;
  late String productId;

  Future<int> readCost() async {
    final row = await database
        .customSelect(
          'SELECT cost_minor FROM products WHERE id = ?',
          variables: [Variable.withString(productId)],
        )
        .getSingle();
    return row.read<int>('cost_minor');
  }

  Future<List<int>> readSaleUnitCosts() async {
    final rows = await database
        .customSelect('SELECT unit_cost_minor FROM sale_items')
        .get();
    return [for (final row in rows) row.read<int>('unit_cost_minor')];
  }

  setUp(() async {
    database = openTestDatabase();
    currentTime = DateTime(2026, 11, 17, 10);
    final clock = Clock(() => currentTime);
    final ids = SequentialIds();
    final log = RecordingAppLog();
    products = ProductRepository(
      db: database,
      clock: clock,
      ids: ids,
      log: log,
      currency: Currency.php,
    );
    sales = SaleRepository(
      db: database,
      clock: clock,
      ids: ids,
      log: log,
      currency: Currency.php,
    );
    productId = _ok(
      await products.create(
        ProductDraft(
          name: 'Sardines',
          unit: ProductUnit.can,
          price: _php(2500),
          cost: _php(2000),
          initialStock: const Quantity.whole(10),
        ),
      ),
    );
  });

  tearDown(() => database.close());

  test('restock with new cost updates cost; old sale cost unchanged', () async {
    currentTime = currentTime.add(const Duration(minutes: 1));
    _ok(
      await sales.record(
        SaleDraft(
          lines: [
            SaleLineDraft(
              productId: productId,
              quantity: const Quantity.whole(2),
            ),
          ],
          method: PaymentMethod.cash,
          cashTendered: _php(5000),
        ),
      ),
    );
    expect(await readSaleUnitCosts(), [2000]);

    currentTime = currentTime.add(const Duration(minutes: 1));
    _ok(
      await products.restock(
        productId,
        const Quantity.whole(5),
        newCost: _php(2300),
      ),
    );

    expect(await readCost(), 2300);
    expect(await readSaleUnitCosts(), [2000]);
    final stock = (await products.watchActive().first).single.stock;
    expect(stock, const Quantity.whole(13));
  });

  test('restock without cost keeps cost', () async {
    _ok(await products.restock(productId, const Quantity.whole(1)));
    expect(await readCost(), 2000);
  });

  test('restock rejected leaves cost untouched (atomic)', () async {
    expect(
      _err(
        await products.restock(productId, Quantity.zero, newCost: _php(9)),
      ),
      isA<ProductQuantityInvalid>(),
    );
    expect(
      _err(
        await products.restock(
          productId,
          const Quantity.whole(1),
          newCost: _php(-1),
        ),
      ),
      isA<ProductAmountInvalid>(),
    );
    expect(await readCost(), 2000);
    expect(
      (await products.watchActive().first).single.stock,
      const Quantity.whole(10),
    );
  });

  test('adjustStock with new cost updates cost with the movement', () async {
    _ok(
      await products.adjustStock(
        productId,
        const Quantity.whole(3),
        newCost: _php(2100),
      ),
    );
    expect(await readCost(), 2100);
    expect(
      (await products.watchActive().first).single.stock,
      const Quantity.whole(13),
    );
    expect(
      _err(
        await products.adjustStock(
          productId,
          -const Quantity.whole(99),
          newCost: _php(1),
        ),
      ),
      isA<ProductQuantityInvalid>(),
    );
    expect(await readCost(), 2100);
  });

  test('update with restock reason records restock movement', () async {
    currentTime = currentTime.add(const Duration(minutes: 1));
    _ok(
      await products.update(
        productId,
        ProductDraft(
          name: 'Sardines',
          unit: ProductUnit.can,
          price: _php(2500),
          cost: _php(2400),
        ),
        stockChange: const Quantity.whole(4),
        stockReason: 'restock',
      ),
    );
    final history = await products.watchStockHistory(productId).first;
    expect(history.first.reason, 'restock');
    expect(await readCost(), 2400);
  });

  test('stock history is newest first with running totals', () async {
    currentTime = currentTime.add(const Duration(minutes: 1));
    _ok(await products.restock(productId, const Quantity.whole(5)));
    currentTime = currentTime.add(const Duration(minutes: 1));
    _ok(
      await sales.record(
        SaleDraft(
          lines: [
            SaleLineDraft(
              productId: productId,
              quantity: const Quantity.whole(3),
            ),
          ],
          method: PaymentMethod.cash,
          cashTendered: _php(7500),
        ),
      ),
    );
    currentTime = currentTime.add(const Duration(minutes: 1));
    _ok(await products.adjust(productId, -const Quantity.whole(2)));

    final history = await products.watchStockHistory(productId).first;
    expect(
      [for (final entry in history) entry.reason],
      ['adjust', 'sale', 'restock', 'initial'],
    );
    expect(
      [for (final entry in history) entry.change.milli],
      [-2000, -3000, 5000, 10000],
    );
    expect(
      [for (final entry in history) entry.stockAfter.milli],
      [10000, 12000, 15000, 10000],
    );
    expect(
      history.first.stockAfter,
      (await products.watchActive().first).single.stock,
    );
  });

  test('stock history of other product is empty', () async {
    expect(await products.watchStockHistory('other').first, isEmpty);
  });
}
