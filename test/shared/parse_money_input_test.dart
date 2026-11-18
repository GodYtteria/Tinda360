import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

Money? _parse(String input) => parseMoneyInput(input, Currency.php);

void main() {
  test('parses whole and decimal amounts exactly', () {
    expect(_parse('100'), const Money(10000, Currency.php));
    expect(_parse('12.5'), const Money(1250, Currency.php));
    expect(_parse('0.29'), const Money(29, Currency.php));
    expect(_parse(' 7.05 '), const Money(705, Currency.php));
    expect(_parse('12.'), const Money(1200, Currency.php));
    expect(_parse('.50'), const Money(50, Currency.php));
  });

  test('accepts thousands separators', () {
    expect(_parse('1,000'), const Money(100000, Currency.php));
    expect(_parse('1,234,567.89'), const Money(123456789, Currency.php));
  });

  test('rejects ambiguous, negative, and malformed input', () {
    expect(_parse(''), isNull);
    expect(_parse('.'), isNull);
    expect(_parse('   '), isNull);
    expect(_parse('12,50'), isNull);
    expect(_parse('-5'), isNull);
    expect(_parse('1e3'), isNull);
    expect(_parse('1.005'), isNull);
    expect(_parse('abc'), isNull);
    expect(_parse('₱50'), isNull);
    expect(_parse('1234567890123'), isNull);
  });
}
