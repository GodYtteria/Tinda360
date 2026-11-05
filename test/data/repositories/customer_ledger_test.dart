import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull;
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
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';

import '../../support/recording_app_log.dart';
import '../../support/sequential_ids.dart';
import '../../support/test_database.dart';

T _requireOk<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

void main() {
  late AppDatabase database;
  late DateTime currentTime;
  late ProductRepository productRepository;
  late SaleRepository saleRepository;
  late CustomerRepository customerRepository;

  setUp(() {
    database = openTestDatabase();
    currentTime = DateTime(2026, 11, 17, 10);
    final clock = Clock(() => currentTime);
    final ids = SequentialIds();
    final log = RecordingAppLog();

    productRepository = ProductRepository(
      db: database,
      clock: clock,
      ids: ids,
      log: log,
      currency: Currency.php,
    );
    saleRepository = SaleRepository(
      db: database,
      clock: clock,
      ids: ids,
      log: log,
      currency: Currency.php,
    );
    customerRepository = CustomerRepository(
      db: database,
      clock: clock,
      ids: ids,
      log: log,
      currency: Currency.php,
    );
  });

  tearDown(() => database.close());

  test('watchLedger emits debt and payment entries newest first', () async {
    final productId = _requireOk(
      await productRepository.create(
        ProductDraft(
          name: 'Sardines',
          unit: ProductUnit.can,
          price: _php(2500),
          cost: _php(2000),
          initialStock: const Quantity.whole(10),
        ),
      ),
    );
    final customerId = _requireOk(
      await customerRepository.create(
        const CustomerDraft(name: 'Ate Maria'),
      ),
    );
    final otherCustomerId = _requireOk(
      await customerRepository.create(
        const CustomerDraft(name: 'Kuya Ben'),
      ),
    );

    final saleId = _requireOk(
      await saleRepository.record(
        SaleDraft(
          method: PaymentMethod.utang,
          customerId: customerId,
          lines: [
            SaleLineDraft(
              productId: productId,
              quantity: const Quantity.whole(2),
            ),
          ],
        ),
      ),
    );

    final afterSale = await customerRepository.watchLedger(customerId).first;
    expect(afterSale, hasLength(1));
    expect(afterSale.first.kind, 'debt');
    expect(afterSale.first.amount, _php(5000));
    expect(afterSale.first.saleId, saleId);
    expect(
      afterSale.first.createdAtMs,
      currentTime.toUtc().millisecondsSinceEpoch,
    );

    currentTime = currentTime.add(const Duration(minutes: 5));
    _requireOk(await customerRepository.recordPayment(customerId, _php(2000)));

    final afterPayment = await customerRepository.watchLedger(customerId).first;
    expect(afterPayment, hasLength(2));
    expect(afterPayment[0].kind, 'payment');
    expect(afterPayment[0].amount, _php(2000));
    expect(afterPayment[0].saleId, isNull);
    expect(afterPayment[1].kind, 'debt');
    expect(afterPayment[1].amount, _php(5000));
    expect(afterPayment[1].saleId, saleId);

    await (database.update(database.ledgerEntries)
          ..where((entry) => entry.id.equals(afterPayment[0].id)))
        .write(const LedgerEntriesCompanion(isDeleted: Value(true)));

    final afterSoftDelete = await customerRepository
        .watchLedger(customerId)
        .first;
    expect(afterSoftDelete, hasLength(2));
    expect(afterSoftDelete[0].kind, 'payment');
    expect(afterSoftDelete[0].isDeleted, isTrue);
    expect(afterSoftDelete[1].kind, 'debt');
    expect(afterSoftDelete[1].isDeleted, isFalse);
    expect(
      await customerRepository.watchLedger(otherCustomerId).first,
      isEmpty,
    );
  });
}
