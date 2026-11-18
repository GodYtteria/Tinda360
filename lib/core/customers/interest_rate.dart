import 'package:tinda360/core/money/money.dart';

const int minInterestPercentTenths = 1;

const int maxInterestPercentTenths = 500;

bool isValidInterestPercentTenths(int tenths) =>
    tenths >= minInterestPercentTenths && tenths <= maxInterestPercentTenths;

final RegExp _percentInputPattern = RegExp(r'^(\d{1,2})(?:[.,](\d))?$');

int? parseInterestPercentTenths(String input) {
  final match = _percentInputPattern.firstMatch(input.trim());
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = int.parse(match.group(2) ?? '0');
  final tenths = whole * 10 + fraction;
  return isValidInterestPercentTenths(tenths) ? tenths : null;
}

String formatInterestPercent(int tenths) =>
    tenths % 10 == 0 ? '${tenths ~/ 10}' : '${tenths ~/ 10}.${tenths % 10}';

Money computeInterest(Money balance, int percentTenths) => Money(
  (balance.minorUnits * percentTenths + 500) ~/ 1000,
  balance.currency,
);
