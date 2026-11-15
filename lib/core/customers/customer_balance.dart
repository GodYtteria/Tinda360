import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/money/money.dart';

/// A customer with their outstanding utang, derived from the ledger.
final class CustomerBalance {
  /// Pairs [customer] with their derived [balance].
  const CustomerBalance({required this.customer, required this.balance});

  /// The customer.
  final Customer customer;

  /// Total debts minus total payments.
  final Money balance;

  /// Whether the customer owes anything.
  bool get owes => balance.isPositive;

  /// Whether the balance is above the customer's credit limit.
  bool get isOverLimit {
    final limit = customer.creditLimit;
    return limit != null && balance > limit;
  }

  @override
  bool operator ==(Object other) =>
      other is CustomerBalance &&
      other.customer == customer &&
      other.balance == balance;

  @override
  int get hashCode => Object.hash(customer, balance);
}
