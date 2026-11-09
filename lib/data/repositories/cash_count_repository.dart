import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/failures/cash_count_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/id_generator.dart';

final class CashCountEntry {
  const new({
    required this.id,
    required this.createdAtMs,
    required this.day,
    required this.expected,
    required this.counted,
    required this.note,
  });

  final String id;

  final int createdAtMs;

  final LocalDay day;

  final Money expected;

  final Money counted;

  final String? note;

  Money get difference => counted - expected;
}

int startOfLocalDayMs(LocalDay day) =>
    day.toLocalDate().toUtc().millisecondsSinceEpoch;

final class CashCountRepository {
  new({
    required this._db,
    required this._clock,
    required this._ids,
    required this._log,
    required this._currency,
  });

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;
  final AppLog _log;
  final Currency _currency;

  static const String _expectedCashSql = '''
SELECT
  (SELECT COALESCE(SUM(paid_minor), 0) FROM sales
    WHERE is_deleted = 0 AND method IN ('cash', 'utang') AND day_serial = ?1)
  + (SELECT COALESCE(SUM(amount_minor), 0) FROM ledger_entries
    WHERE is_deleted = 0 AND kind = 'payment' AND sale_id IS NULL
      AND created_at >= ?2 AND created_at < ?3)
  - (SELECT COALESCE(SUM(r.refund_minor), 0) FROM sale_returns r
    JOIN sales s ON s.id = r.sale_id
    WHERE r.is_deleted = 0 AND s.is_deleted = 0
      AND s.method IN ('cash', 'utang')
      AND r.created_at >= ?2 AND r.created_at < ?3)
  + (SELECT COALESCE(SUM(l.amount_minor), 0) FROM ledger_entries l
    JOIN sales s ON s.id = l.sale_id
    WHERE l.is_deleted = 0 AND s.is_deleted = 0 AND l.kind = 'payment'
      AND s.method = 'utang'
      AND l.created_at >= ?2 AND l.created_at < ?3)
  AS expected_minor
''';

  Future<Money> expectedCashFor(LocalDay day) async {
    final rows = await _expectedCashQuery(day).get();
    return _expectedFromRows(rows);
  }

  Stream<Money> watchExpectedCash(LocalDay day) =>
      _expectedCashQuery(day).watch().map(_expectedFromRows);

  Selectable<QueryRow> _expectedCashQuery(LocalDay day) => _db.customSelect(
    _expectedCashSql,
    variables: [
      Variable.withInt(day.serial),
      Variable.withInt(startOfLocalDayMs(day)),
      Variable.withInt(startOfLocalDayMs(day.plusDays(1))),
    ],
    readsFrom: {_db.sales, _db.ledgerEntries, _db.saleReturns},
  );

  Money _expectedFromRows(List<QueryRow> rows) =>
      Money(rows.single.read<int>('expected_minor'), _currency);

  Stream<List<CashCountEntry>> watchInRange(DayRange range) {
    final query = _db.select(_db.cashCounts)
      ..where(
        (row) =>
            row.isDeleted.equals(false) &
            row.daySerial.isBetweenValues(
              range.first.serial,
              range.last.serial,
            ),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.daySerial),
        (row) => OrderingTerm.desc(row.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_toEntry).toList());
  }

  CashCountEntry _toEntry(CashCountRow row) => CashCountEntry(
    id: row.id,
    createdAtMs: row.createdAt,
    day: LocalDay(row.daySerial),
    expected: Money(row.expectedMinor, _currency),
    counted: Money(row.countedMinor, _currency),
    note: row.note,
  );

  @useResult
  Future<Result<String, CashCountFailure>> saveCount({
    required Money counted,
    String? note,
  }) async {
    if (counted.isNegative || counted.currency != _currency) {
      return const Err(CashCountAmountInvalid());
    }
    final currentTime = _clock.now();
    final nowMs = currentTime.toUtc().millisecondsSinceEpoch;
    final today = LocalDay.fromLocal(currentTime);
    final trimmedNote = note?.trim();
    final countId = _ids.next();
    try {
      await _db.transaction(() async {
        final expected = await expectedCashFor(today);
        await _db
            .into(_db.cashCounts)
            .insert(
              CashCountsCompanion.insert(
                id: countId,
                createdAt: nowMs,
                updatedAt: nowMs,
                daySerial: today.serial,
                expectedMinor: expected.minorUnits,
                countedMinor: counted.minorUnits,
                note: Value(
                  trimmedNote == null || trimmedNote.isEmpty
                      ? null
                      : trimmedNote,
                ),
              ),
            );
      });
      return Ok(countId);
    } on Object catch (error, stack) {
      _log.error('cash_count.save', error, stack);
      return const Err(CashCountUnavailable());
    }
  }
}
