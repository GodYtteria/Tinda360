import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_return_line.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';
import 'package:tinda360/data/repositories/expense_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';
import 'package:tinda360/data/repositories/sale_return_repository.dart';
import 'package:tinda360/data/repositories/store_profile_repository.dart';
import 'package:tinda360/features/chat/data/yumi_tool_executor.dart';

import '../../support/recording_app_log.dart';
import '../../support/sequential_ids.dart';
import '../../support/test_database.dart';

T _requireOk<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

SaleLineDraft _line(String productId, int milliQuantity) => SaleLineDraft(
  productId: productId,
  quantity: Quantity.milli(milliQuantity),
);

SaleReturnLine _returnLine(String productId, int milliQuantity) =>
    SaleReturnLine(
      productId: productId,
      quantity: Quantity.milli(milliQuantity),
    );

const int _unit = Quantity.milliPerUnit;
const int _noodlesPrice = 1500;
const int _noodlesCost = 1200;
const int _ricePrice = 4500;
const int _riceCost = 4000;
const int _kapePrice = 800;
const int _kapeCost = 600;
const int _soapPrice = 2500;
const int _soapCost = 2000;
const int _candyPrice = 500;
const int _candyCost = 300;
const int _largeTender = 1000000;
const int _anaPaidNow = 1000;

void main() {
  late AppDatabase database;
  late DateTime currentTime;
  late ProductRepository products;
  late SaleRepository sales;
  late SaleReturnRepository saleReturns;
  late CustomerRepository customers;
  late ExpenseRepository expenses;
  late YumiToolExecutor executor;
  late String noodlesId;
  late String riceId;
  late String kapeId;
  late String soapId;
  late String anaId;
  late String benId;

  Future<String> sellCash(List<SaleLineDraft> lines) async => _requireOk(
    await sales.record(
      SaleDraft(
        method: PaymentMethod.cash,
        cashTendered: _php(_largeTender),
        lines: lines,
      ),
    ),
  );

  Future<String> createProduct({
    required String name,
    required ProductUnit unit,
    required int price,
    required int cost,
    required int stockUnits,
    Quantity? lowStockAt,
  }) async => _requireOk(
    await products.create(
      ProductDraft(
        name: name,
        unit: unit,
        price: _php(price),
        cost: _php(cost),
        initialStock: Quantity.whole(stockUnits),
        lowStockAt: lowStockAt,
      ),
    ),
  );

  setUp(() async {
    database = openTestDatabase();
    currentTime = DateTime(2026, 11, 16, 15);
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
    saleReturns = SaleReturnRepository(
      db: database,
      clock: clock,
      ids: ids,
      log: log,
      currency: Currency.php,
    );
    customers = CustomerRepository(
      db: database,
      clock: clock,
      ids: ids,
      log: log,
      currency: Currency.php,
    );
    expenses = ExpenseRepository(
      db: database,
      clock: clock,
      ids: ids,
      log: log,
      currency: Currency.php,
    );
    executor = YumiToolExecutor(
      db: database,
      products: products,
      sales: sales,
      customers: customers,
      expenses: expenses,
      storeProfile: StoreProfileRepository(
        db: database,
        clock: clock,
        log: log,
      ),
      clock: clock,
      currency: Currency.php,
    );

    noodlesId = await createProduct(
      name: 'Instant noodles',
      unit: ProductUnit.pack,
      price: _noodlesPrice,
      cost: _noodlesCost,
      stockUnits: 100,
    );
    riceId = await createProduct(
      name: 'Bigas',
      unit: ProductUnit.kilo,
      price: _ricePrice,
      cost: _riceCost,
      stockUnits: 50,
    );
    kapeId = await createProduct(
      name: 'Kape sachet',
      unit: ProductUnit.piece,
      price: _kapePrice,
      cost: _kapeCost,
      stockUnits: 10,
      lowStockAt: const Quantity.whole(5),
    );
    soapId = await createProduct(
      name: 'Sabon',
      unit: ProductUnit.piece,
      price: _soapPrice,
      cost: _soapCost,
      stockUnits: 20,
    );
    await createProduct(
      name: 'Candy',
      unit: ProductUnit.piece,
      price: _candyPrice,
      cost: _candyCost,
      stockUnits: 10,
    );
    anaId = _requireOk(
      await customers.create(const CustomerDraft(name: 'Ana')),
    );
    benId = _requireOk(
      await customers.create(const CustomerDraft(name: 'Ben')),
    );
    _requireOk(await customers.create(const CustomerDraft(name: 'Cara')));

    _requireOk(await expenses.addExpense(title: 'Yelo', amount: _php(1000)));

    await sellCash([_line(noodlesId, 3 * _unit)]);
    currentTime = DateTime(2026, 11, 17, 10);

    final firstSaleId = await sellCash([
      _line(noodlesId, 4 * _unit),
      _line(riceId, 2500),
      _line(kapeId, 9 * _unit),
      _line(soapId, _unit),
    ]);
    _requireOk(
      await saleReturns.returnItems(firstSaleId, [
        _returnLine(noodlesId, _unit),
        _returnLine(kapeId, 2 * _unit),
        _returnLine(soapId, _unit),
      ]),
    );

    _requireOk(
      await sales.record(
        SaleDraft(
          method: PaymentMethod.utang,
          customerId: anaId,
          paidNow: _php(_anaPaidNow),
          lines: [_line(noodlesId, 2 * _unit)],
        ),
      ),
    );
    _requireOk(
      await sales.record(
        SaleDraft(
          method: PaymentMethod.utang,
          customerId: benId,
          paidNow: _php(0),
          lines: [_line(noodlesId, _unit)],
        ),
      ),
    );
    _requireOk(await customers.recordPayment(benId, _php(_noodlesPrice)));

    final voidedSaleId = await sellCash([_line(noodlesId, 10 * _unit)]);
    _requireOk(await sales.voidSale(voidedSaleId));

    _requireOk(await expenses.addExpense(title: 'Yelo', amount: _php(5000)));
    _requireOk(await expenses.addExpense(title: 'Gas', amount: _php(2500)));
    final scratchId = _requireOk(
      await expenses.addExpense(title: 'Mali', amount: _php(700)),
    );
    expect(await expenses.deleteExpense(scratchId), isTrue);
  });

  tearDown(() => database.close());

  test('sales summary nets returns and ignores voided sales', () async {
    final result = await executor.execute('get_sales_summary', {
      'timeframe': 'today',
    });

    expect(result['revenue_minor'], 25850);
    expect(result['cost_minor'], 21400);
    expect(result['profit_minor'], 4450);
    expect(result['sale_count'], 3);
    expect(result['items_sold_milli'], 15500);
  });

  test('week summary adds yesterday and excludes the voided sale', () async {
    final result = await executor.execute('get_sales_summary', {
      'timeframe': 'week',
    });

    expect(result['revenue_minor'], 30350);
    expect(result['cost_minor'], 25000);
    expect(result['sale_count'], 4);
  });

  test('sales compare reports the day over day delta', () async {
    final result = await executor.execute('get_sales_compare', {
      'period': 'day',
    });

    final previous = result['previous'] as Map<String, dynamic>;
    final delta = result['delta'] as Map<String, dynamic>;
    expect(previous['revenue_minor'], 4500);
    expect(delta['revenue_minor'], 21350);
    expect(delta['sale_count'], 2);
  });

  test('sales trend lists each day in order', () async {
    final result = await executor.execute('get_sales_trend', {'days': 2});

    final series = result['series'] as List<dynamic>;
    expect((series.first as Map<String, dynamic>)['revenue_minor'], 4500);
    expect((series.last as Map<String, dynamic>)['revenue_minor'], 25850);
  });

  test('top products net returned quantity and revenue', () async {
    final result = await executor.execute('get_top_products', {
      'timeframe': 'today',
    });

    final rows = (result['products'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(rows.map((row) => row['product_name']), [
      'Bigas',
      'Instant noodles',
      'Kape sachet',
    ]);
    expect(rows[0]['total_qty_milli'], 2500);
    expect(rows[0]['total_revenue_minor'], 11250);
    expect(rows[1]['total_qty_milli'], 6000);
    expect(rows[1]['total_revenue_minor'], 9000);
    expect(rows[2]['total_qty_milli'], 7000);
    expect(rows[2]['total_revenue_minor'], 5600);
  });

  test('payment breakdown and busiest hours use net sale totals', () async {
    final payments = await executor.execute('get_payment_breakdown', {
      'timeframe': 'today',
    });
    final methods = (payments['methods'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      methods.firstWhere((row) => row['method'] == 'cash')['amount_minor'],
      21350,
    );
    expect(
      methods.firstWhere((row) => row['method'] == 'utang')['amount_minor'],
      4500,
    );
    expect(payments['total_amount_minor'], 25850);
    expect(payments['total_count'], 3);

    final hours = await executor.execute('get_busiest_hours', {
      'timeframe': 'today',
    });
    final bucket =
        (hours['hours'] as List<dynamic>).single as Map<String, dynamic>;
    expect(bucket['transaction_count'], 3);
    expect(bucket['revenue_minor'], 25850);
  });

  test('suki loyalty sums net spend per named customer', () async {
    final result = await executor.execute('get_suki_loyalty', {});

    final rows = (result['customers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(rows.map((row) => row['customer_name']), ['Ana', 'Ben']);
    expect(rows[0]['total_spend_minor'], 3000);
    expect(rows[1]['total_spend_minor'], 1500);
  });

  test('expenses total excludes deleted entries and other days', () async {
    final today = await executor.execute('get_expenses', {
      'timeframe': 'today',
    });
    expect(today['total_minor'], 7500);
    expect(today['count'], 2);

    final week = await executor.execute('get_expenses', {'timeframe': 'week'});
    expect(week['total_minor'], 8500);
    expect(week['count'], 3);
  });

  test('utang list holds only customers who still owe', () async {
    final result = await executor.execute('get_utang_list', {});

    expect(result['count'], 1);
    expect(result['total_balance_minor'], 2000);
    final customer =
        (result['customers'] as List<dynamic>).single as Map<String, dynamic>;
    expect(customer['name'], 'Ana');
    expect(customer['balance_minor'], 2000);
  });

  test('utang list converts the peso minimum to centavos', () async {
    final included = await executor.execute('get_utang_list', {
      'min_balance': 20,
    });
    expect(included['min_balance_minor'], 2000);
    expect(included['count'], 1);

    final excluded = await executor.execute('get_utang_list', {
      'min_balance': 20.01,
    });
    expect(excluded['min_balance_minor'], 2001);
    expect(excluded['count'], 0);
  });

  test('utang risk skips paid-up customers', () async {
    final recent = await executor.execute('get_utang_risk', {
      'days_overdue': 0,
    });
    expect(recent['count'], 1);
    expect(recent['total_at_risk_minor'], 2000);

    final overdue = await executor.execute('get_utang_risk', {
      'days_overdue': 30,
    });
    expect(overdue['count'], 0);
    expect(overdue['total_at_risk_minor'], 0);
  });

  test('stock forecast treats returned units as not sold', () async {
    final result = await executor.execute('get_stock_forecast', {
      'product_name': 'Instant noodles',
    });

    expect(result['current_stock_milli'], 91 * _unit);
    expect(result['sold_qty_milli_window'], 9 * _unit);
    expect(result['avg_daily_sales_units'], 0.6429);
    expect(result['days_remaining'], 141.5556);
  });

  test('stock forecast has no days remaining for an unsold product', () async {
    final result = await executor.execute('get_stock_forecast', {
      'product_name': 'Candy',
    });

    expect(result['sold_qty_milli_window'], 0);
    expect(result['avg_daily_sales_units'], 0.0);
    expect(result['days_remaining'], isNull);
  });

  test('slow moving includes a product whose only sale was returned', () async {
    final result = await executor.execute('get_slow_moving', {});

    final names = (result['items'] as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['name'])
        .toSet();
    expect(names, {'Candy', 'Sabon'});
  });

  test('restock orders from net demand and totals in centavos', () async {
    final result = await executor.execute('get_restock_suggestions', {});

    final suggestion =
        (result['suggestions'] as List<dynamic>).single as Map<String, dynamic>;
    expect(suggestion['name'], 'Kape sachet');
    expect(suggestion['current_stock_milli'], 3 * _unit);
    expect(suggestion['qty_to_order'], 1);
    expect(suggestion['unit_cost_minor'], _kapeCost);
    expect(suggestion['total_minor'], _kapeCost);
    expect(result['total_cost_minor'], _kapeCost);
  });

  test('restock budget is read in pesos and compared in centavos', () async {
    final tooSmall = await executor.execute('get_restock_suggestions', {
      'budget': 5,
    });
    expect(tooSmall['budget_minor'], 500);
    expect(tooSmall['suggestions'], isEmpty);
    expect(tooSmall['total_cost_minor'], 0);

    final exact = await executor.execute('get_restock_suggestions', {
      'budget': 6,
    });
    expect(exact['budget_minor'], 600);
    expect((exact['suggestions'] as List<dynamic>).length, 1);
    expect(exact['remaining_budget_minor'], 0);
  });

  test('profit margins use per unit price and cost', () async {
    final highest = await executor.execute('get_profit_margins', {'limit': 2});
    final highestRows = (highest['products'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(highestRows.map((row) => row['name']), ['Candy', 'Kape sachet']);
    expect(highestRows[0]['margin_minor'], 200);
    expect(highestRows[0]['margin_pct'], 40.0);
    expect(highestRows[1]['margin_pct'], 25.0);

    final lowest = await executor.execute('get_profit_margins', {
      'sort': 'lowest',
      'limit': 1,
    });
    final lowestRow =
        (lowest['products'] as List<dynamic>).single as Map<String, dynamic>;
    expect(lowestRow['name'], 'Bigas');
    expect(lowestRow['margin_minor'], 500);
    expect(lowestRow['margin_pct'], 11.11);
  });

  test('low stock and product info report milli quantities', () async {
    final low = await executor.execute('get_low_stock', {});
    expect(low['count'], 1);
    final item = (low['items'] as List<dynamic>).single as Map<String, dynamic>;
    expect(item['stock_milli'], 3 * _unit);

    final wide = await executor.execute('get_low_stock', {'threshold': 10});
    final wideNames = (wide['items'] as List<dynamic>)
        .map((entry) => (entry as Map<String, dynamic>)['name'])
        .toSet();
    expect(wideNames, {'Kape sachet', 'Candy'});

    final info = await executor.execute('get_product_info', {
      'product_name': 'Bigas',
    });
    final product = info['product'] as Map<String, dynamic>;
    expect(product['price_minor'], _ricePrice);
    expect(product['cost_minor'], _riceCost);
    expect(product['stock_milli'], 47500);
  });

  test('overview reports net sales today and unpaid utang', () async {
    final result = await executor.execute('get_overview', {});

    final salesToday = result['sales_today'] as Map<String, dynamic>;
    expect(salesToday['revenue_minor'], 25850);
    expect(salesToday['profit_minor'], 4450);
    expect(result['utang_total_minor'], 2000);
    expect(result['low_stock_count'], 1);
  });

  test('product lookup ignores accents in the asked name', () async {
    await createProduct(
      name: 'Piña Juice',
      unit: ProductUnit.piece,
      price: _candyPrice,
      cost: _candyCost,
      stockUnits: 4,
    );
    final info = await executor.execute('get_product_info', {
      'product_name': 'pina juice',
    });
    expect(info['found'], isNot(false));
    final product = info['product'] as Map<String, dynamic>;
    expect(product['name'], 'Piña Juice');
  });
}
