import 'package:meta/meta.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/money/money.dart';

@immutable
final class CustomerBalance {
  const new({
    required this.customer,
    required this.balance,
    this.outstandingInterestOrNull,
  });

  final Customer customer;

  final Money balance;

  final Money? outstandingInterestOrNull;

  bool get owes => balance.isPositive;

  bool get canAddInterest =>
      outstandingUtang.isPositive && customer.interestPercentTenths != null;

  Money get outstandingInterest {
    final interest = outstandingInterestOrNull;
    if (interest == null || !interest.isPositive || !owes) {
      return Money.zero(balance.currency);
    }
    return interest > balance ? balance : interest;
  }

  Money get outstandingUtang => balance - outstandingInterest;

  bool get isOverLimit {
    final limit = customer.creditLimit;
    return limit != null && balance > limit;
  }

  @override
  bool operator ==(Object other) =>
      other is CustomerBalance &&
      other.customer == customer &&
      other.balance == balance &&
      other.outstandingInterestOrNull == outstandingInterestOrNull;

  @override
  int get hashCode => Object.hash(customer, balance, outstandingInterestOrNull);
}
