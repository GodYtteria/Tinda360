import 'package:meta/meta.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';

@immutable
final class UtangBreakdown {
  const new({required this.utang, required this.interest});

  final Money utang;

  final Money interest;

  Money get total => utang + interest;

  @override
  bool operator ==(Object other) =>
      other is UtangBreakdown &&
      other.utang == utang &&
      other.interest == interest;

  @override
  int get hashCode => Object.hash(utang, interest);
}

int compareLedgerOrder(LedgerRecord first, LedgerRecord second) {
  final byTime = first.createdAtMs.compareTo(second.createdAtMs);
  return byTime != 0 ? byTime : first.id.compareTo(second.id);
}

UtangBreakdown computeUtangBreakdown(
  Iterable<LedgerRecord> entries,
  Currency currency,
) {
  var utangMinor = 0;
  var interestMinor = 0;
  final ordered = entries.where((entry) => !entry.isDeleted).toList()
    ..sort(compareLedgerOrder);
  for (final entry in ordered) {
    final amountMinor = entry.amount.minorUnits;
    if (entry.isDebt) {
      utangMinor += amountMinor;
    } else if (entry.isInterest) {
      interestMinor += amountMinor;
    } else if (entry.saleId != null) {
      final creditedToUtang = amountMinor < utangMinor
          ? amountMinor
          : utangMinor;
      utangMinor -= creditedToUtang;
      final creditedToInterest = amountMinor - creditedToUtang;
      interestMinor -= creditedToInterest < interestMinor
          ? creditedToInterest
          : interestMinor;
    } else {
      final paidToInterest = amountMinor < interestMinor
          ? amountMinor
          : interestMinor;
      interestMinor -= paidToInterest;
      final paidToUtang = amountMinor - paidToInterest;
      utangMinor -= paidToUtang < utangMinor ? paidToUtang : utangMinor;
    }
  }
  return UtangBreakdown(
    utang: Money(utangMinor, currency),
    interest: Money(interestMinor, currency),
  );
}
