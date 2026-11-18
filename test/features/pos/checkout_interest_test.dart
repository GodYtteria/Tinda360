import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/features/pos/presentation/checkout_interest.dart';
import 'package:tinda360/features/pos/presentation/checkout_utang_pricing.dart';

Money _php(int minor) => Money(minor, Currency.php);

InterestResolution _resolve(
  String text,
  InterestInputMode mode, {
  Money? utang,
}) => resolveCheckoutInterest(
  text: text,
  mode: mode,
  utangAmount: utang ?? _php(10000),
  currency: Currency.php,
);

void main() {
  group('percent mode', () {
    test('blank means no interest and no error', () {
      for (final blank in ['', '   ']) {
        final result = _resolve(blank, InterestInputMode.percent);
        expect(result.interest, isNull);
        expect(result.error, isNull);
      }
    });

    test('10 percent of 100 pesos is 10 pesos', () {
      expect(_resolve('10', InterestInputMode.percent).interest, _php(1000));
    });

    test('one decimal and comma decimal are accepted', () {
      expect(_resolve('2.5', InterestInputMode.percent).interest, _php(250));
      expect(_resolve('2,5', InterestInputMode.percent).interest, _php(250));
    });

    test('bounds are 0.1 to 50.0', () {
      expect(_resolve('0.1', InterestInputMode.percent).interest, _php(10));
      expect(_resolve('50.0', InterestInputMode.percent).interest, _php(5000));
      expect(_resolve('50', InterestInputMode.percent).interest, _php(5000));
      for (final bad in ['0', '0.0', '0.09', '50.1', '51', '100']) {
        expect(
          _resolve(bad, InterestInputMode.percent).error,
          InterestInputError.invalidPercent,
          reason: bad,
        );
      }
    });

    test('garbage, two decimals, negative, unicode and huge are errors', () {
      for (final bad in [
        'abc',
        '1.25',
        '-5',
        '５',
        '१०',
        '1e1',
        '99999999999999999999',
        '5%',
      ]) {
        final result = _resolve(bad, InterestInputMode.percent);
        expect(result.interest, isNull, reason: bad);
        expect(result.error, InterestInputError.invalidPercent, reason: bad);
      }
    });

    test('a percent that rounds to zero centavos is an error', () {
      final result = _resolve(
        '0.1',
        InterestInputMode.percent,
        utang: _php(4),
      );
      expect(result.error, InterestInputError.invalidPercent);
    });

    test('percent without an utang amount is an error', () {
      final result = resolveCheckoutInterest(
        text: '5',
        mode: InterestInputMode.percent,
        utangAmount: null,
        currency: Currency.php,
      );
      expect(result.error, InterestInputError.invalidPercent);
    });
  });

  group('peso mode', () {
    test('blank means no interest', () {
      final result = _resolve('', InterestInputMode.peso);
      expect(result.interest, isNull);
      expect(result.error, isNull);
    });

    test('amount up to and including the utang is accepted', () {
      expect(_resolve('25.50', InterestInputMode.peso).interest, _php(2550));
      expect(_resolve('100', InterestInputMode.peso).interest, _php(10000));
      expect(_resolve('100.00', InterestInputMode.peso).interest, _php(10000));
      expect(_resolve('0.01', InterestInputMode.peso).interest, _php(1));
    });

    test('amount above the utang is rejected as too much', () {
      expect(
        _resolve('100.01', InterestInputMode.peso).error,
        InterestInputError.exceedsUtang,
      );
      expect(
        _resolve('1,000', InterestInputMode.peso).error,
        InterestInputError.exceedsUtang,
      );
    });

    test('zero, negative, garbage, unicode and huge are invalid amounts', () {
      for (final bad in [
        '0',
        '0.00',
        '-1',
        'abc',
        '1.234',
        '１０',
        '1,5',
        '9999999999999999',
      ]) {
        final result = _resolve(bad, InterestInputMode.peso);
        expect(result.interest, isNull, reason: bad);
        expect(result.error, InterestInputError.invalidAmount, reason: bad);
      }
    });

    test('any amount is too much when nothing goes on utang', () {
      final result = resolveCheckoutInterest(
        text: '1',
        mode: InterestInputMode.peso,
        utangAmount: null,
        currency: Currency.php,
      );
      expect(result.error, InterestInputError.exceedsUtang);
    });
  });

  group('prefill from suki rate', () {
    test('uses the rate as a percent text', () {
      expect(interestPrefillText(50), '5');
      expect(interestPrefillText(25), '2.5');
      expect(interestPrefillText(1), '0.1');
      expect(interestPrefillText(500), '50');
    });

    test('no rate or out of range rate gives an empty field', () {
      expect(interestPrefillText(null), '');
      expect(interestPrefillText(0), '');
      expect(interestPrefillText(501), '');
    });

    test('prefilled text resolves to the same interest as the rate', () {
      final result = _resolve(
        interestPrefillText(25),
        InterestInputMode.percent,
      );
      expect(result.interest, _php(250));
    });
  });

  group('interest base amount', () {
    test('utang method uses total minus paid now', () {
      expect(
        interestBaseAmount(
          method: PaymentMethod.utang,
          total: _php(10000),
          paidNow: _php(2500),
          cashShortfall: null,
        ),
        _php(7500),
      );
    });

    test('utang with nothing paid uses the whole total', () {
      expect(
        interestBaseAmount(
          method: PaymentMethod.utang,
          total: _php(10000),
          paidNow: _php(0),
          cashShortfall: null,
        ),
        _php(10000),
      );
    });

    test('fully paid, over paid, negative or invalid paid now has no base', () {
      for (final paid in [_php(10000), _php(10001), _php(-1), null]) {
        expect(
          interestBaseAmount(
            method: PaymentMethod.utang,
            total: _php(10000),
            paidNow: paid,
            cashShortfall: null,
          ),
          isNull,
        );
      }
    });

    test('cash and e-wallet never have a base', () {
      for (final method in [PaymentMethod.cash, PaymentMethod.ewallet]) {
        expect(
          interestBaseAmount(
            method: method,
            total: _php(10000),
            paidNow: null,
            cashShortfall: null,
          ),
          isNull,
        );
      }
    });

    test('cash shortfall flow uses the shortfall on utang prices', () {
      final shortfall = resolveCashShortfall(
        method: PaymentMethod.cash,
        cashTotal: _php(10000),
        utangTotal: _php(11000),
        cashReceived: _php(4000),
      );
      expect(shortfall, _php(7000));
      expect(
        interestBaseAmount(
          method: PaymentMethod.cash,
          total: _php(10000),
          paidNow: null,
          cashShortfall: shortfall,
        ),
        _php(7000),
      );
    });
  });

  group('preview amounts', () {
    test('adds interest to the utang', () {
      final preview = interestPreviewAmounts(
        utangAmount: _php(10000),
        interest: _php(1000),
      );
      expect(preview?.utang, _php(10000));
      expect(preview?.interest, _php(1000));
      expect(preview?.total, _php(11000));
    });

    test('no preview without interest or base', () {
      expect(
        interestPreviewAmounts(utangAmount: _php(1), interest: null),
        isNull,
      );
      expect(
        interestPreviewAmounts(utangAmount: null, interest: _php(1)),
        isNull,
      );
    });
  });
}
