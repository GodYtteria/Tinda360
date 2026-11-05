import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/customers/utang_breakdown.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';

const int utangOverdueDays = 30;

int? oldestOutstandingDebtAgeDays(
  Iterable<LedgerRecord> entries,
  DateTime now,
) {
  final ordered = entries.where((entry) => !entry.isDeleted).toList()
    ..sort(compareLedgerOrder);
  final outstandingDebts = <({int createdAtMs, int remainingMinor})>[];
  var interestMinor = 0;
  for (final entry in ordered) {
    if (entry.isDebt) {
      outstandingDebts.add((
        createdAtMs: entry.createdAtMs,
        remainingMinor: entry.amount.minorUnits,
      ));
    } else if (entry.isInterest) {
      interestMinor += entry.amount.minorUnits;
    } else if (entry.isPayment) {
      var unappliedMinor = entry.amount.minorUnits;
      if (entry.saleId == null) {
        final paidToInterest = unappliedMinor < interestMinor
            ? unappliedMinor
            : interestMinor;
        interestMinor -= paidToInterest;
        unappliedMinor -= paidToInterest;
      }
      while (unappliedMinor > 0 && outstandingDebts.isNotEmpty) {
        final oldest = outstandingDebts.first;
        if (oldest.remainingMinor <= unappliedMinor) {
          unappliedMinor -= oldest.remainingMinor;
          outstandingDebts.removeAt(0);
        } else {
          outstandingDebts[0] = (
            createdAtMs: oldest.createdAtMs,
            remainingMinor: oldest.remainingMinor - unappliedMinor,
          );
          unappliedMinor = 0;
        }
      }
      interestMinor -= unappliedMinor < interestMinor
          ? unappliedMinor
          : interestMinor;
    }
  }
  if (outstandingDebts.isEmpty) return null;
  final ageDays = Duration(
    milliseconds:
        now.toUtc().millisecondsSinceEpoch - outstandingDebts.first.createdAtMs,
  ).inDays;
  return ageDays < 0 ? 0 : ageDays;
}

final class UtangAgeRepository {
  UtangAgeRepository({required AppDatabase db, required Currency currency})
    : _db = db,
      _currency = currency;

  final AppDatabase _db;
  final Currency _currency;

  static const String _allLedgerSql = '''
SELECT l.id, l.created_at, l.kind, l.amount_minor, l.sale_id, l.customer_id,
       l.is_deleted, l.deleted_at, l.delete_reason, l.deleted_by_name
FROM ledger_entries l
JOIN customers c ON c.id = l.customer_id
WHERE l.is_deleted = 0 AND c.is_deleted = 0
''';

  Stream<Map<String, List<LedgerRecord>>> watchLedgerByCustomer() => _db
      .customSelect(
        _allLedgerSql,
        readsFrom: {_db.ledgerEntries, _db.customers},
      )
      .watch()
      .map((rows) {
        final entriesByCustomer = <String, List<LedgerRecord>>{};
        for (final row in rows) {
          entriesByCustomer
              .putIfAbsent(row.read<String>('customer_id'), () => [])
              .add(ledgerRecordFromRow(row, _currency));
        }
        return entriesByCustomer;
      });

  Future<Map<String, List<LedgerRecord>>> loadLedgerByCustomer() =>
      watchLedgerByCustomer().first;
}
