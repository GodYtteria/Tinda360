import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';

Money totalUnpaidUtang(
  List<CustomerBalance> balances, {
  Currency currency = Currency.php,
}) {
  var total = Money.zero(currency);
  for (final customerBalance in balances) {
    if (customerBalance.owes) total = total + customerBalance.balance;
  }
  return total;
}
