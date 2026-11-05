import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
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
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/ulat/presentation/ulat_notifier.dart';
import 'package:tinda360/services/service_providers.dart';

import '../../support/test_repositories.dart';

T _ok<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

Money _php(int minor) => Money(minor, Currency.php);

void main() {
  late TestRepositories repos;
  late ProviderContainer container;

  setUp(() {
    repos = TestRepositories();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(repos.db),
        clockProvider.overrideWithValue(repos.clock),
        appLogProvider.overrideWithValue(repos.log),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await repos.close();
  });

  test('dayRangeForPeriod computes today, week, and month ranges', () {
    final today = LocalDay.fromLocal(DateTime(2026, 11, 17));

    expect(
      dayRangeForPeriod(ReportPeriod.today, today),
      DayRange.single(today),
    );
    expect(
      dayRangeForPeriod(ReportPeriod.week, today),
      DayRange(today.plusDays(-6), today),
    );
    expect(
      dayRangeForPeriod(ReportPeriod.month, today),
      DayRange(today.plusDays(-29), today),
    );
  });

  test(
    'ulatNotifierProvider projects sales summary and utang balances',
    () async {
      final subscription = container.listen(ulatNotifierProvider, (_, _) {});
      addTearDown(subscription.close);

      final initial = await container.read(ulatNotifierProvider.future);
      expect(initial.period, ReportPeriod.today);
      expect(initial.summary.revenue, _php(0));
      expect(initial.summary.saleCount, 0);
      expect(initial.totalUtang, _php(0));

      final productId = _ok(
        await repos.products.create(
          ProductDraft(
            name: 'Coffee sachet',
            unit: ProductUnit.sachet,
            price: _php(1500),
            cost: _php(1000),
            initialStock: const Quantity.whole(30),
          ),
        ),
      );
      final sukiId = _ok(
        await repos.customers.create(const CustomerDraft(name: 'Ate Glo')),
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
            method: PaymentMethod.cash,
            cashTendered: _php(5000),
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
            customerId: sukiId,
          ),
        ),
      );

      await pumpEventQueue();
      final updated = await container.read(ulatNotifierProvider.future);
      expect(updated.summary.saleCount, 2);
      expect(updated.summary.revenue, _php(4500));
      expect(updated.summary.profit, _php(1500));
      expect(updated.totalUtang, _php(1500));
      expect(updated.sukiWithUtangCount, 1);

      container.read(ulatPeriodProvider.notifier).select(ReportPeriod.week);
      await pumpEventQueue();
      final weekState = await container.read(ulatNotifierProvider.future);
      expect(weekState.period, ReportPeriod.week);
      expect(weekState.summary.saleCount, 2);
    },
  );

  test(
    'ulatNotifierProvider projects top 3 products ordered by revenue then quantity',
    () async {
      final subscription = container.listen(ulatNotifierProvider, (_, _) {});
      addTearDown(subscription.close);

      final initial = await container.read(ulatNotifierProvider.future);
      expect(initial.topProducts, isEmpty);

      final coffeeId = _ok(
        await repos.products.create(
          ProductDraft(
            name: 'Coffee sachet',
            unit: ProductUnit.sachet,
            price: _php(1500),
            cost: _php(1000),
            initialStock: const Quantity.whole(30),
          ),
        ),
      );
      final sugarId = _ok(
        await repos.products.create(
          ProductDraft(
            name: 'White sugar',
            unit: ProductUnit.kilo,
            price: _php(6000),
            cost: _php(4500),
            initialStock: const Quantity.whole(10),
          ),
        ),
      );
      final candyId = _ok(
        await repos.products.create(
          ProductDraft(
            name: 'Candy',
            unit: ProductUnit.piece,
            price: _php(200),
            cost: _php(100),
            initialStock: const Quantity.whole(100),
          ),
        ),
      );
      final soapId = _ok(
        await repos.products.create(
          ProductDraft(
            name: 'Bath soap',
            unit: ProductUnit.bar,
            price: _php(3000),
            cost: _php(2000),
            initialStock: const Quantity.whole(20),
          ),
        ),
      );

      _ok(
        await repos.sales.record(
          SaleDraft(
            lines: [
              SaleLineDraft(
                productId: coffeeId,
                quantity: const Quantity.whole(2),
              ),
              SaleLineDraft(
                productId: sugarId,
                quantity: const Quantity.milli(500),
              ),
              SaleLineDraft(
                productId: candyId,
                quantity: const Quantity.whole(5),
              ),
              SaleLineDraft(
                productId: soapId,
                quantity: const Quantity.whole(2),
              ),
            ],
            method: PaymentMethod.cash,
            cashTendered: _php(20000),
          ),
        ),
      );

      await pumpEventQueue();
      final updated = await container.read(ulatNotifierProvider.future);
      expect(updated.topProducts, [
        TopProduct(
          productId: soapId,
          productName: 'Bath soap',
          unit: ProductUnit.bar,
          totalQuantity: const Quantity.whole(2),
          totalRevenue: _php(6000),
        ),
        TopProduct(
          productId: coffeeId,
          productName: 'Coffee sachet',
          unit: ProductUnit.sachet,
          totalQuantity: const Quantity.whole(2),
          totalRevenue: _php(3000),
        ),
        TopProduct(
          productId: sugarId,
          productName: 'White sugar',
          unit: ProductUnit.kilo,
          totalQuantity: const Quantity.milli(500),
          totalRevenue: _php(3000),
        ),
      ]);
    },
  );
}
