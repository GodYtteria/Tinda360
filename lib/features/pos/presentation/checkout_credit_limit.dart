import 'package:tinda360/core/money/money.dart';

final class CreditLimitDecision {
  const CreditLimitDecision({
    required this.isBlocked,
    required this.projectedBalance,
    this.creditLimit,
  });

  final bool isBlocked;
  final Money projectedBalance;
  final Money? creditLimit;
}

CreditLimitDecision decideCreditLimit({
  required Money currentBalance,
  required Money? creditLimit,
  required Money saleUtang,
  required Money saleInterest,
  required bool ownerApproved,
}) {
  final projectedBalance = currentBalance + saleUtang + saleInterest;
  final exceedsLimit =
      creditLimit != null &&
      saleUtang.isPositive &&
      projectedBalance > creditLimit;
  return CreditLimitDecision(
    isBlocked: exceedsLimit && !ownerApproved,
    projectedBalance: projectedBalance,
    creditLimit: creditLimit,
  );
}
