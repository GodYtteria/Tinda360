import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/pos/data/suggested_cash_amounts.dart';
import 'package:tinda360/features/pos/presentation/cash_quick_amounts_row.dart';

void main() {
  test('whole peso total shows exact then next three round amounts', () {
    expect(suggestedCashAmounts(3500), [35, 50, 100, 200]);
  });

  test('total exactly 100 pesos skips duplicate and goes strictly above', () {
    expect(suggestedCashAmounts(10000), [100, 200, 500, 1000]);
  });

  test('total of 1 peso', () {
    expect(suggestedCashAmounts(100), [1, 50, 100, 200]);
  });

  test('cents total has no exact chip amount', () {
    expect(suggestedCashAmounts(4050), [50, 100, 200]);
  });

  test('huge total has no round amounts above', () {
    expect(suggestedCashAmounts(500000000), [5000000]);
  });

  test('zero total gives round amounts only', () {
    expect(suggestedCashAmounts(0), [50, 100, 200]);
  });

  test('never more than five chips', () {
    expect(suggestedCashAmounts(100).length, lessThanOrEqualTo(5));
  });

  test('exact tendered text keeps cents', () {
    expect(formatExactTenderedText(4050), '40.50');
    expect(formatExactTenderedText(4005), '40.05');
    expect(formatExactTenderedText(4000), '40');
    expect(formatExactTenderedText(50), '0.50');
  });
}
