import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/unpaid_utang.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';

CustomerBalance _balance(String name, int minorUnits) => CustomerBalance(
  customer: Customer(id: name, name: name),
  balance: Money(minorUnits, Currency.php),
);

void main() {
  test('sums only balances that owe and ignores credits', () {
    final total = totalUnpaidUtang([
      _balance('Ana', 5000),
      _balance('Ben', -2000),
      _balance('Cora', 1500),
      _balance('Dan', 0),
    ]);
    expect(total, const Money(6500, Currency.php));
  });

  test('empty list is zero', () {
    expect(totalUnpaidUtang(const []), const Money.zero(Currency.php));
  });
}
