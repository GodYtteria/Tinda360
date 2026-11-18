import 'package:tinda360/core/customers/interest_rate.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

enum InterestInputMode { percent, peso }

enum InterestInputError { invalidPercent, invalidAmount, exceedsUtang }

final class InterestResolution {
  const new({this.interest, this.error});

  final Money? interest;

  final InterestInputError? error;
}

InterestResolution resolveCheckoutInterest({
  required String text,
  required InterestInputMode mode,
  required Money? utangAmount,
  required Currency currency,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const InterestResolution();
  switch (mode) {
    case InterestInputMode.percent:
      final tenths = parseInterestPercentTenths(trimmed);
      if (tenths == null || utangAmount == null) {
        return const InterestResolution(
          error: InterestInputError.invalidPercent,
        );
      }
      final interest = computeInterest(utangAmount, tenths);
      if (!interest.isPositive) {
        return const InterestResolution(
          error: InterestInputError.invalidPercent,
        );
      }
      return InterestResolution(interest: interest);
    case InterestInputMode.peso:
      final interest = parseMoneyInput(trimmed, currency);
      if (interest == null || !interest.isPositive) {
        return const InterestResolution(
          error: InterestInputError.invalidAmount,
        );
      }
      if (utangAmount == null || interest > utangAmount) {
        return const InterestResolution(
          error: InterestInputError.exceedsUtang,
        );
      }
      return InterestResolution(interest: interest);
  }
}

String interestPrefillText(int? percentTenths) =>
    percentTenths != null && isValidInterestPercentTenths(percentTenths)
    ? formatInterestPercent(percentTenths)
    : '';

Money? interestBaseAmount({
  required PaymentMethod method,
  required Money total,
  required Money? paidNow,
  required Money? cashShortfall,
}) {
  if (cashShortfall != null) return cashShortfall;
  if (method != PaymentMethod.utang) return null;
  if (paidNow == null || paidNow.isNegative || paidNow > total) return null;
  final utang = total - paidNow;
  return utang.isPositive ? utang : null;
}

final class InterestPreviewAmounts {
  const new({
    required this.utang,
    required this.interest,
    required this.total,
  });

  final Money utang;

  final Money interest;

  final Money total;
}

InterestPreviewAmounts? interestPreviewAmounts({
  required Money? utangAmount,
  required Money? interest,
}) {
  if (utangAmount == null || interest == null) return null;
  return InterestPreviewAmounts(
    utang: utangAmount,
    interest: interest,
    total: utangAmount + interest,
  );
}
