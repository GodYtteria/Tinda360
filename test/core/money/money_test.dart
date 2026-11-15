import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';

void main() {
  group('Money', () {
    test('adds and subtracts in minor units', () {
      const a = Money(1250, Currency.php);
      const b = Money(75, Currency.php);
      expect(a + b, const Money(1325, Currency.php));
      expect(a - b, const Money(1175, Currency.php));
    });

    test('compares amounts', () {
      const small = Money(100, Currency.php);
      const big = Money(200, Currency.php);
      expect(small < big, isTrue);
      expect(big > small, isTrue);
    });

    test('scales PHP by its ISO-4217 exponent', () {
      expect(Currency.php.minorPerMajor, 100);
    });

    test('does not default an unknown currency', () {
      expect(Currency.tryParse('XYZ'), isNull);
      expect(Currency.tryParse('PHP'), Currency.php);
    });
  });
}
