import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/features/pos/presentation/checkout_shortfall.dart';

Money pesos(int amount) => Money(amount * 100, Currency.php);

void main() {
  group('cashShortfallOf', () {
    test('cash 30 on total 40 gives shortfall 10', () {
      final shortfall = cashShortfallOf(
        method: PaymentMethod.cash,
        total: pesos(40),
        cashReceived: pesos(30),
      );
      expect(shortfall, pesos(10));
    });

    test('one centavo short is a shortfall of one centavo', () {
      final shortfall = cashShortfallOf(
        method: PaymentMethod.cash,
        total: pesos(40),
        cashReceived: Money(3999, Currency.php),
      );
      expect(shortfall, Money(1, Currency.php));
    });

    test('cash equal to total has no shortfall', () {
      expect(
        cashShortfallOf(
          method: PaymentMethod.cash,
          total: pesos(40),
          cashReceived: pesos(40),
        ),
        isNull,
      );
    });

    test('cash above total has no shortfall so change is shown', () {
      expect(
        cashShortfallOf(
          method: PaymentMethod.cash,
          total: pesos(40),
          cashReceived: pesos(50),
        ),
        isNull,
      );
    });

    test('zero cash has no shortfall option', () {
      expect(
        cashShortfallOf(
          method: PaymentMethod.cash,
          total: pesos(40),
          cashReceived: pesos(0),
        ),
        isNull,
      );
    });

    test('empty cash input has no shortfall option', () {
      expect(
        cashShortfallOf(
          method: PaymentMethod.cash,
          total: pesos(40),
          cashReceived: null,
        ),
        isNull,
      );
    });

    test('negative cash has no shortfall option', () {
      expect(
        cashShortfallOf(
          method: PaymentMethod.cash,
          total: pesos(40),
          cashReceived: Money(-100, Currency.php),
        ),
        isNull,
      );
    });

    test('other methods never offer a shortfall', () {
      for (final method in [PaymentMethod.ewallet, PaymentMethod.utang]) {
        expect(
          cashShortfallOf(
            method: method,
            total: pesos(40),
            cashReceived: pesos(30),
          ),
          isNull,
        );
      }
    });
  });

  group('canRecordCashShortfall', () {
    test('disabled without a chosen suki', () {
      expect(
        canRecordCashShortfall(shortfall: pesos(10), customerId: null),
        isFalse,
      );
    });

    test('enabled with a chosen suki', () {
      expect(
        canRecordCashShortfall(shortfall: pesos(10), customerId: 'suki-1'),
        isTrue,
      );
    });

    test('disabled without a shortfall', () {
      expect(
        canRecordCashShortfall(shortfall: null, customerId: 'suki-1'),
        isFalse,
      );
    });
  });

  group('buildCashShortfallDraft', () {
    test('records utang with paidNow equal to cash and chosen suki', () {
      final lines = [
        const SaleLineDraft(productId: 'p1', quantity: Quantity.whole(2)),
      ];
      final draft = buildCashShortfallDraft(
        lines: lines,
        cashReceived: pesos(30),
        customerId: 'suki-1',
      );
      expect(draft.method, PaymentMethod.utang);
      expect(draft.paidNow, pesos(30));
      expect(draft.customerId, 'suki-1');
      expect(draft.cashTendered, isNull);
      expect(draft.lines, lines);
    });
  });

  group('isNearOrOverCreditLimit', () {
    test('no limit never warns', () {
      expect(
        isNearOrOverCreditLimit(
          balance: pesos(100),
          creditLimit: null,
          additionalUtang: pesos(10),
        ),
        isFalse,
      );
    });

    test('zero balance and zero extra does not warn', () {
      expect(
        isNearOrOverCreditLimit(
          balance: pesos(0),
          creditLimit: pesos(100),
          additionalUtang: pesos(0),
        ),
        isFalse,
      );
    });

    test('shortfall pushing balance to 80 percent warns', () {
      expect(
        isNearOrOverCreditLimit(
          balance: pesos(70),
          creditLimit: pesos(100),
          additionalUtang: pesos(10),
        ),
        isTrue,
      );
    });

    test('shortfall keeping balance under 80 percent does not warn', () {
      expect(
        isNearOrOverCreditLimit(
          balance: pesos(60),
          creditLimit: pesos(100),
          additionalUtang: pesos(10),
        ),
        isFalse,
      );
    });

    test('shortfall larger than the limit warns on empty balance', () {
      expect(
        isNearOrOverCreditLimit(
          balance: pesos(0),
          creditLimit: pesos(5),
          additionalUtang: pesos(10),
        ),
        isTrue,
      );
    });
  });
}
