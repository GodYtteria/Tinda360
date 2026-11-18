import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/customers/interest_rate.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/customers/utang_breakdown.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/customer_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/cash_count_repository.dart';
import 'package:tinda360/features/utang/presentation/suki_ledger_sheet.dart';
import 'package:tinda360/l10n/app_localizations_fil.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

import '../../support/sequential_ids.dart';
import '../../support/test_repositories.dart';

T _ok<T, FailureType extends Failure>(Result<T, FailureType> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
    };

FailureType _err<T, FailureType extends Failure>(
  Result<T, FailureType> result,
) => switch (result) {
  Ok() => fail('Expected Err'),
  Err(:final failure) => failure,
};

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

void main() {
  late TestRepositories repos;
  late CashCountRepository cashCounts;
  late String productId;
  late String customerId;

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
    productId = _ok(
      await repos.products.create(
        ProductDraft(
          name: 'Rice',
          unit: ProductUnit.kilo,
          price: _php(10000),
          cost: _php(6000),
          initialStock: const Quantity.whole(100),
        ),
      ),
    );
    customerId = _ok(
      await repos.customers.create(
        const CustomerDraft(name: 'Ate Glo', interestPercentTenths: 50),
      ),
    );
  });

  tearDown(() => repos.close());

  Future<String> sellOnUtang({int quantity = 1, Money? interest}) async => _ok(
    await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.utang,
        customerId: customerId,
        interest: interest,
        lines: [
          SaleLineDraft(
            productId: productId,
            quantity: Quantity.whole(quantity),
          ),
        ],
      ),
    ),
  );

  Future<List<LedgerRecord>> history() =>
      repos.customers.watchLedger(customerId).first;

  Future<LedgerRecord> latestOfKind(String kind) async =>
      (await history()).firstWhere((record) => record.kind == kind);

  Future<Money> balance() async => (await repos.customers.watchBalances().first)
      .firstWhere((entry) => entry.customer.id == customerId)
      .balance;

  Future<UtangBreakdown> breakdown() async {
    final entry = (await repos.customers.watchBalances().first).firstWhere(
      (candidate) => candidate.customer.id == customerId,
    );
    return UtangBreakdown(
      utang: entry.outstandingUtang,
      interest: entry.outstandingInterest,
    );
  }

  Future<Money> addInterest() async {
    final entry = (await repos.customers.watchBalances().first).single;
    final expected = computeInterest(entry.outstandingUtang, 50);
    return _ok(await repos.customers.addInterest(customerId, expected));
  }

  Future<void> insertSaleLinked(String kind, int amountMinor, String saleId) =>
      repos.db
          .into(repos.db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'linked-$kind',
              createdAt: 1,
              updatedAt: 1,
              customerId: customerId,
              kind: kind,
              amountMinor: amountMinor,
              saleId: Value(saleId),
            ),
          );

  test(
    'deleting a manual payment raises balance and lowers expected cash',
    () async {
      await sellOnUtang();
      _ok(await repos.customers.recordPayment(customerId, _php(4000)));
      final today = LocalDay.fromLocal(DateTime(2026, 11, 17, 10));
      expect(await balance(), _php(6000));
      expect(await cashCounts.expectedCashFor(today), _php(4000));

      final payment = await latestOfKind('payment');
      _ok(await repos.customers.deleteLedgerEntry(payment.id));

      expect(await balance(), _php(10000));
      expect(await cashCounts.expectedCashFor(today), _php(0));
    },
  );

  test(
    'deleting manual interest lowers balance and updates breakdown',
    () async {
      await sellOnUtang();
      final interest = await addInterest();
      expect(await balance(), _php(10000) + interest);
      expect((await breakdown()).interest, interest);

      _ok(
        await repos.customers.deleteLedgerEntry(
          (await latestOfKind('interest')).id,
        ),
      );

      expect(await balance(), _php(10000));
      final view = await breakdown();
      expect(view.interest, _php(0));
      expect(view.utang, _php(10000));
    },
  );

  test('refuses debt line', () async {
    await sellOnUtang();
    final debt = await latestOfKind('debt');
    final failure = _err(await repos.customers.deleteLedgerEntry(debt.id));
    expect(failure, isA<LedgerEntryNotDeletable>());
    expect(await balance(), _php(10000));
  });

  test('refuses sale-linked payment and sale-linked interest', () async {
    final saleId = await sellOnUtang(interest: _php(300));
    final saleInterest = await latestOfKind('interest');
    expect(saleInterest.saleId, saleId);
    expect(
      _err(await repos.customers.deleteLedgerEntry(saleInterest.id)),
      isA<LedgerEntryNotDeletable>(),
    );
    await insertSaleLinked('payment', 100, saleId);
    expect(
      _err(await repos.customers.deleteLedgerEntry('linked-payment')),
      isA<LedgerEntryNotDeletable>(),
    );
    expect(
      (await history()).where((record) => record.isDeleted),
      isEmpty,
    );
  });

  test('refuses already deleted and unknown ids', () async {
    await sellOnUtang();
    _ok(await repos.customers.recordPayment(customerId, _php(500)));
    final payment = await latestOfKind('payment');
    _ok(await repos.customers.deleteLedgerEntry(payment.id));
    expect(
      _err(await repos.customers.deleteLedgerEntry(payment.id)),
      isA<LedgerEntryAlreadyDeleted>(),
    );
    expect(
      _err(await repos.customers.deleteLedgerEntry('missing')),
      isA<LedgerEntryNotFound>(),
    );
  });

  test('refuses interest delete when it would make balance negative', () async {
    await sellOnUtang();
    final interest = await addInterest();
    _ok(
      await repos.customers.recordPayment(
        customerId,
        _php(10000) + interest,
      ),
    );
    final failure = _err(
      await repos.customers.deleteLedgerEntry(
        (await latestOfKind('interest')).id,
      ),
    );
    expect(failure, isA<LedgerDeleteWouldGoNegative>());
    expect(await balance(), _php(0));
    expect((await latestOfKind('interest')).isDeleted, isFalse);
  });

  group('reason', () {
    Future<LedgerRecord> deleteWith(String? reason) async {
      await sellOnUtang();
      _ok(await repos.customers.recordPayment(customerId, _php(500)));
      final payment = await latestOfKind('payment');
      _ok(await repos.customers.deleteLedgerEntry(payment.id, reason: reason));
      return (await history()).firstWhere((record) => record.id == payment.id);
    }

    test('is trimmed', () async {
      final record = await deleteWith('  maling halaga  ');
      expect(record.deleteReason, 'maling halaga');
      expect(record.isDeleted, isTrue);
      expect(record.deletedAtMs, isNotNull);
    });

    test('blank becomes null', () async {
      expect((await deleteWith('   ')).deleteReason, isNull);
    });

    test('null stays null', () async {
      expect((await deleteWith(null)).deleteReason, isNull);
    });

    test('is limited to 120 characters', () async {
      final record = await deleteWith('á' * 200);
      expect(record.deleteReason, 'á' * 120);
    });
  });

  test(
    'deleted lines are listed but excluded from balance and breakdown',
    () async {
      await sellOnUtang();
      final interest = await addInterest();
      _ok(await repos.customers.recordPayment(customerId, _php(5000)));
      final payment = await latestOfKind('payment');
      _ok(
        await repos.customers.deleteLedgerEntry(
          payment.id,
          reason: 'maling halaga',
        ),
      );

      final records = await history();
      expect(records, hasLength(3));
      final deleted = records.firstWhere((record) => record.id == payment.id);
      expect(deleted.isDeleted, isTrue);
      expect(deleted.deleteReason, 'maling halaga');
      expect(records.where((record) => record.isDeleted), hasLength(1));

      expect(await balance(), _php(10000) + interest);
      final view = await breakdown();
      expect(view.utang, _php(10000));
      expect(view.interest, interest);
      expect(computeUtangBreakdown(records, Currency.php), view);

      final entry = (await repos.customers.watchBalances().first).single;
      final message = buildUtangReminderMessage(
        localizations: AppLocalizationsFil(),
        customerName: 'Ate Glo',
        storeName: 'Tindahan',
        formattedBalance: formatMoney(entry.balance),
        formattedUtang: formatMoney(entry.outstandingUtang),
        formattedInterest: formatMoney(entry.outstandingInterest),
      );
      expect(message, contains(formatMoney(_php(10000) + interest)));
      expect(message, isNot(contains(formatMoney(_php(5000)))));
    },
  );

  test(
    'delete wrong payment then enter correct one gives right balance',
    () async {
      await sellOnUtang();
      _ok(await repos.customers.recordPayment(customerId, _php(5000)));
      _ok(
        await repos.customers.deleteLedgerEntry(
          (await latestOfKind('payment')).id,
          reason: 'maling halaga',
        ),
      );
      _ok(await repos.customers.recordPayment(customerId, _php(500)));
      expect(await balance(), _php(9500));
      expect(
        (await history()).where((record) => record.isPayment),
        hasLength(2),
      );
    },
  );

  test('concurrent double delete deletes once', () async {
    await sellOnUtang();
    _ok(await repos.customers.recordPayment(customerId, _php(500)));
    final payment = await latestOfKind('payment');
    final results = await Future.wait([
      repos.customers.deleteLedgerEntry(payment.id),
      repos.customers.deleteLedgerEntry(payment.id),
    ]);
    expect(results.whereType<Ok<void, CustomerFailure>>(), hasLength(1));
    expect(
      results.whereType<Err<void, CustomerFailure>>().single.failure,
      isA<LedgerEntryAlreadyDeleted>(),
    );
    expect(await balance(), _php(10000));
  });
}
