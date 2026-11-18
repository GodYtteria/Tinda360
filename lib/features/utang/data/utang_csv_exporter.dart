import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/data/repositories/utang_age_repository.dart';

String exportUtangCsv({
  required List<CustomerBalance> balances,
  required Map<String, List<LedgerRecord>> ledgerByCustomer,
  required DateTime now,
}) {
  final lines = <String>[
    'suki,phone,balance,utang,interest,last_payment_date,oldest_debt_days',
  ];
  for (final item in balances) {
    final entries =
        ledgerByCustomer[item.customer.id] ?? const <LedgerRecord>[];
    final oldestDebtDays = oldestOutstandingDebtAgeDays(entries, now);
    lines.add(
      _encodeCsvRow([
        item.customer.name,
        item.customer.phone ?? '',
        _formatDecimalMoney(item.balance),
        _formatDecimalMoney(item.outstandingUtang),
        _formatDecimalMoney(item.outstandingInterest),
        _lastPaymentDate(entries),
        if (oldestDebtDays == null) '' else oldestDebtDays.toString(),
      ]),
    );
  }
  return lines.join('\r\n');
}

String _lastPaymentDate(List<LedgerRecord> entries) {
  int? latestMs;
  for (final entry in entries) {
    if (entry.isDeleted || !entry.isPayment || entry.saleId != null) continue;
    if (latestMs == null || entry.createdAtMs > latestMs) {
      latestMs = entry.createdAtMs;
    }
  }
  if (latestMs == null) return '';
  return DateTime.fromMillisecondsSinceEpoch(
    latestMs,
  ).toIso8601String().substring(0, 10);
}

String _encodeCsvRow(List<String> fields) =>
    fields.map(_escapeCsvField).join(',');

const Set<String> _formulaTriggerCharacters = {'=', '+', '-', '@', '\t', '\r'};

String _neutralizeFormula(String value) {
  if (value.isEmpty || double.tryParse(value) != null) return value;
  return _formulaTriggerCharacters.contains(value[0]) ? "'$value" : value;
}

String _escapeCsvField(String rawValue) {
  final value = _neutralizeFormula(rawValue);
  final needsQuotes =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\r') ||
      value.contains('\n');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}

String _formatDecimalMoney(Money money) {
  final sign = money.isNegative ? '-' : '';
  final absoluteMinor = money.minorUnits.abs();
  final minorPerMajor = money.currency.minorPerMajor;
  final majorUnits = absoluteMinor ~/ minorPerMajor;
  if (money.currency.exponent == 0) return '$sign$majorUnits';
  final paddedMinor = (absoluteMinor % minorPerMajor).toString().padLeft(
    money.currency.exponent,
    '0',
  );
  return '$sign$majorUnits.$paddedMinor';
}
