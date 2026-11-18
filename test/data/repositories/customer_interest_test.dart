import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/customers/interest_rate.dart';
import 'package:tinda360/core/customers/utang_breakdown.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/customer_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_return_line.dart';
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
  late String productId;

  setUp(() async {
    repos = TestRepositories();
    productId = _ok(
      await repos.products.create(
        ProductDraft(
          name: 'Rice',
          unit: ProductUnit.kilo,
          price: _php(3333),
          cost: _php(2000),
          initialStock: const Quantity.whole(100),
        ),
      ),
    );
  });

  tearDown(() => repos.close());

  Future<String> createSuki({int? tenths}) async => _ok(
    await repos.customers.create(
      CustomerDraft(name: 'Ate Glo', interestPercentTenths: tenths),
    ),
  );

  Future<String> sellOnUtang(String customerId, int quantity) async => _ok(
    await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.utang,
        customerId: customerId,
        lines: [
          SaleLineDraft(
            productId: productId,
            quantity: Quantity.whole(quantity),
          ),
        ],
      ),
    ),
  );

  Future<Money> balanceOf(String customerId) async {
    final balances = await repos.customers.watchBalances().first;
    return balances
        .firstWhere((balanceEntry) => balanceEntry.customer.id == customerId)
        .balance;
  }

  Future<Result<Money, CustomerFailure>> addConfirmedInterest(
    String customerId,
  ) async {
    final balances = await repos.customers.watchBalances().first;
    final matches = balances.where(
      (balanceEntry) => balanceEntry.customer.id == customerId,
    );
    final rateTenths = matches.isEmpty
        ? null
        : matches.single.customer.interestPercentTenths;
    final expectedAmount = rateTenths == null
        ? _php(0)
        : computeInterest(matches.single.outstandingUtang, rateTenths);
    return repos.customers.addInterest(customerId, expectedAmount);
  }

  Future<UtangBreakdown> breakdownOf(String customerId) async {
    final balances = await repos.customers.watchBalances().first;
    final entry = balances.firstWhere(
      (balanceEntry) => balanceEntry.customer.id == customerId,
    );
    return UtangBreakdown(
      interest: entry.outstandingInterest,
      utang: entry.outstandingUtang,
    );
  }

  group('interest first payments', () {
    test('paid off in full then new utang leaves no interest', () async {
      final customerId = await createSuki(tenths: 50);
      await sellOnUtang(customerId, 1);
      _ok(await addConfirmedInterest(customerId));
      _ok(await repos.customers.recordPayment(customerId, _php(3500)));
      await sellOnUtang(customerId, 1);
      final view = await breakdownOf(customerId);
      expect(view.interest, _php(0));
      expect(view.utang, _php(3333));
    });

    test('reminder after partial payment shows remaining interest', () async {
      final customerId = await createSuki(tenths: 50);
      await sellOnUtang(customerId, 1);
      _ok(await addConfirmedInterest(customerId));
      _ok(await repos.customers.recordPayment(customerId, _php(100)));
      final entry = (await repos.customers.watchBalances().first).single;
      final message = buildUtangReminderMessage(
        localizations: AppLocalizationsFil(),
        customerName: 'Ate Glo',
        storeName: 'Tindahan',
        formattedBalance: formatMoney(entry.balance),
        formattedUtang: formatMoney(entry.outstandingUtang),
        formattedInterest: formatMoney(entry.outstandingInterest),
      );
      expect(
        message,
        contains(
          'Utang ${formatMoney(_php(3333))} + interes '
          '${formatMoney(_php(67))} = ${formatMoney(_php(3400))}',
        ),
      );
    });

    test('partial payment clears interest first', () async {
      final customerId = await createSuki(tenths: 50);
      await sellOnUtang(customerId, 1);
      _ok(await addConfirmedInterest(customerId));
      _ok(await repos.customers.recordPayment(customerId, _php(100)));
      final view = await breakdownOf(customerId);
      expect(view.interest, _php(67));
      expect(view.utang, _php(3333));
      expect(await balanceOf(customerId), _php(3400));
    });

    test(
      'interest is charged on utang only, never on earlier interest',
      () async {
        final customerId = await createSuki(tenths: 100);
        await sellOnUtang(customerId, 3);

        final first = _ok(await addConfirmedInterest(customerId));
        final second = _ok(await addConfirmedInterest(customerId));

        expect(first, _php(1000));
        expect(second, _php(1000));
        final view = await breakdownOf(customerId);
        expect(view.utang, _php(9999));
        expect(view.interest, _php(2000));
      },
    );

    test('interest is refused once everything is paid', () async {
      final customerId = await createSuki(tenths: 100);
      await sellOnUtang(customerId, 3);
      _ok(await addConfirmedInterest(customerId));
      _ok(await repos.customers.recordPayment(customerId, _php(10999)));

      final failure = _err(await addConfirmedInterest(customerId));

      expect(failure, isA<InterestNoBalance>());
      expect(await balanceOf(customerId), _php(0));
    });

    test('interest charged twice then payment equal to interest', () async {
      final customerId = await createSuki(tenths: 100);
      await sellOnUtang(customerId, 3);
      _ok(await addConfirmedInterest(customerId));
      _ok(await addConfirmedInterest(customerId));
      _ok(await repos.customers.recordPayment(customerId, _php(2000)));
      final view = await breakdownOf(customerId);
      expect(view.interest, _php(0));
      expect(view.utang, _php(9999));
    });
  });

  group('interest amount confirmation', () {
    test('refuses when expected amount differs from current amount', () async {
      final customerId = await createSuki(tenths: 50);
      await sellOnUtang(customerId, 1);
      final staleAmount = computeInterest(_php(3333), 50);
      await sellOnUtang(customerId, 1);

      final failure = _err(
        await repos.customers.addInterest(customerId, staleAmount),
      );

      expect(failure, isA<InterestAmountChanged>());
      expect(
        (failure as InterestAmountChanged).currentAmount,
        computeInterest(_php(6666), 50),
      );
      expect(await balanceOf(customerId), _php(6666));
      final ledger = await repos.customers.watchLedger(customerId).first;
      expect(ledger.where((row) => row.isInterest), isEmpty);
    });
  });

  group('rate parsing', () {
    test('accepts bounds and one decimal', () {
      expect(parseInterestPercentTenths('0.1'), 1);
      expect(parseInterestPercentTenths('50.0'), 500);
      expect(parseInterestPercentTenths('50'), 500);
      expect(parseInterestPercentTenths('2,5'), 25);
    });

    test('rejects zero, above max, blank and extra decimals', () {
      expect(parseInterestPercentTenths('0'), isNull);
      expect(parseInterestPercentTenths('0.0'), isNull);
      expect(parseInterestPercentTenths('50.1'), isNull);
      expect(parseInterestPercentTenths(''), isNull);
      expect(parseInterestPercentTenths('5.55'), isNull);
      expect(parseInterestPercentTenths('abc'), isNull);
    });

    test('repository rejects out of range rate on create and update', () async {
      final tooHigh = await repos.customers.create(
        const CustomerDraft(name: 'A', interestPercentTenths: 501),
      );
      expect(_err(tooHigh), isA<CustomerAmountInvalid>());
      final zero = await repos.customers.create(
        const CustomerDraft(name: 'B', interestPercentTenths: 0),
      );
      expect(_err(zero), isA<CustomerAmountInvalid>());
      final customerId = await createSuki();
      final update = await repos.customers.update(
        customerId,
        const CustomerDraft(name: 'Ate Glo', interestPercentTenths: 501),
      );
      expect(_err(update), isA<CustomerAmountInvalid>());
    });

    test('rate persists and blank update clears it', () async {
      final customerId = await createSuki(tenths: 50);
      var balances = await repos.customers.watchBalances().first;
      expect(balances.single.customer.interestPercentTenths, 50);
      _ok(
        await repos.customers.update(
          customerId,
          const CustomerDraft(name: 'Ate Glo'),
        ),
      );
      balances = await repos.customers.watchBalances().first;
      expect(balances.single.customer.interestPercentTenths, isNull);
    });
  });

  group('interest amount', () {
    test('rounds half up', () {
      expect(computeInterest(_php(3333), 50), _php(167));
      expect(computeInterest(_php(10000), 50), _php(500));
      expect(computeInterest(_php(100), 5), _php(1));
      expect(computeInterest(_php(99), 5), _php(0));
    });

    test('addInterest writes one interest entry and raises balance', () async {
      final customerId = await createSuki(tenths: 50);
      await sellOnUtang(customerId, 1);

      final amount = _ok(await addConfirmedInterest(customerId));

      expect(amount, _php(167));
      expect(await balanceOf(customerId), _php(3500));
      final ledger = await repos.customers.watchLedger(customerId).first;
      final interestRows = ledger.where((row) => row.isInterest).toList();
      expect(interestRows, hasLength(1));
      expect(interestRows.single.saleId, isNull);
      expect(interestRows.single.amount, _php(167));
      expect(repos.log.events, isEmpty);
    });

    test(
      'second add is charged on the utang again, never on the earlier interest',
      () async {
        final customerId = await createSuki(tenths: 100);
        await sellOnUtang(customerId, 3);
        _ok(await addConfirmedInterest(customerId));
        expect(await balanceOf(customerId), _php(9999 + 1000));
        _ok(await addConfirmedInterest(customerId));
        expect(await balanceOf(customerId), _php(9999 + 1000 + 1000));
      },
    );

    test('payment after interest reduces total including tubo', () async {
      final customerId = await createSuki(tenths: 50);
      await sellOnUtang(customerId, 1);
      _ok(await addConfirmedInterest(customerId));
      _ok(await repos.customers.recordPayment(customerId, _php(3500)));
      expect(await balanceOf(customerId), _php(0));
    });

    test('balances expose interest breakdown', () async {
      final customerId = await createSuki(tenths: 50);
      await sellOnUtang(customerId, 1);
      _ok(await addConfirmedInterest(customerId));
      final entry = (await repos.customers.watchBalances().first).single;
      expect(entry.outstandingInterest, _php(167));
      expect(entry.outstandingUtang, _php(3333));
      expect(entry.canAddInterest, isTrue);
    });
  });

  group('refusals', () {
    test('no rate set', () async {
      final customerId = await createSuki();
      await sellOnUtang(customerId, 1);
      expect(
        _err(await addConfirmedInterest(customerId)),
        isA<InterestRateNotSet>(),
      );
      expect(await balanceOf(customerId), _php(3333));
    });

    test('zero balance', () async {
      final customerId = await createSuki(tenths: 50);
      expect(
        _err(await addConfirmedInterest(customerId)),
        isA<InterestNoBalance>(),
      );
      final ledger = await repos.customers.watchLedger(customerId).first;
      expect(ledger, isEmpty);
    });

    test('deleted suki', () async {
      final customerId = await createSuki(tenths: 50);
      _ok(await repos.customers.softDelete(customerId));
      expect(
        _err(await addConfirmedInterest(customerId)),
        isA<CustomerNotFound>(),
      );
    });

    test('unknown suki', () async {
      expect(
        _err(await repos.customers.addInterest('missing', _php(1))),
        isA<CustomerNotFound>(),
      );
    });
  });

  group('other repositories', () {
    test('return on utang sale does not credit interest', () async {
      final customerId = await createSuki(tenths: 100);
      final saleId = await sellOnUtang(customerId, 2);
      _ok(await addConfirmedInterest(customerId));
      expect(await balanceOf(customerId), _php(6666 + 667));

      final refund = _ok(
        await repos.saleReturns.returnItems(saleId, [
          SaleReturnLine(
            productId: productId,
            quantity: const Quantity.whole(2),
          ),
        ]),
      );

      expect(refund, _php(6666));
      expect(await balanceOf(customerId), _php(667));
    });

    test('cash count excludes interest', () async {
      final customerId = await createSuki(tenths: 100);
      await sellOnUtang(customerId, 3);
      final cashCounts = CashCountRepository(
        db: repos.db,
        clock: repos.clock,
        ids: SequentialIds(),
        log: repos.log,
        currency: Currency.php,
      );
      final day = LocalDay.fromLocal(repos.clock.now());
      final before = await cashCounts.expectedCashFor(day);
      _ok(await addConfirmedInterest(customerId));
      expect(await cashCounts.expectedCashFor(day), before);
    });
  });
}
