import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/presentation/checkout_credit_limit.dart';

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

CreditLimitDecision _decide({
  int balance = 0,
  int? limit,
  int saleUtang = 0,
  int interest = 0,
  bool approved = false,
}) => decideCreditLimit(
  currentBalance: _php(balance),
  creditLimit: limit == null ? null : _php(limit),
  saleUtang: _php(saleUtang),
  saleInterest: _php(interest),
  ownerApproved: approved,
);

void main() {
  test('no limit never blocks', () {
    expect(_decide(balance: 1000000, saleUtang: 999999).isBlocked, isFalse);
  });

  test('exactly at the limit is allowed', () {
    expect(
      _decide(balance: 5000, limit: 10000, saleUtang: 5000).isBlocked,
      isFalse,
    );
  });

  test('one centavo over the limit is blocked', () {
    final decision = _decide(balance: 5000, limit: 10000, saleUtang: 5001);
    expect(decision.isBlocked, isTrue);
    expect(decision.creditLimit, _php(10000));
    expect(decision.projectedBalance, _php(10001));
  });

  test('interest counts toward the limit', () {
    expect(
      _decide(
        balance: 5000,
        limit: 10000,
        saleUtang: 4800,
        interest: 201,
      ).isBlocked,
      isTrue,
    );
    expect(
      _decide(
        balance: 5000,
        limit: 10000,
        saleUtang: 4800,
        interest: 200,
      ).isBlocked,
      isFalse,
    );
  });

  test('owner approval lifts the block', () {
    final decision = _decide(
      balance: 5000,
      limit: 10000,
      saleUtang: 6000,
      approved: true,
    );
    expect(decision.isBlocked, isFalse);
  });

  test('sale without utang is never blocked even when already over limit', () {
    expect(_decide(balance: 20000, limit: 10000).isBlocked, isFalse);
  });

  test('already over limit with new utang is blocked', () {
    expect(
      _decide(balance: 20000, limit: 10000, saleUtang: 1).isBlocked,
      isTrue,
    );
  });
}
