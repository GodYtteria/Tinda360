import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/failures/expense_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/id_generator.dart';

final class ExpenseRepository {
  ExpenseRepository({
    required AppDatabase db,
    required Clock clock,
    required IdGenerator ids,
    required AppLog log,
    required Currency currency,
  }) : _database = db,
       _clock = clock,
       _ids = ids,
       _log = log,
       _currency = currency;

  final AppDatabase _database;
  final Clock _clock;
  final IdGenerator _ids;
  final AppLog _log;
  final Currency _currency;
  bool _tableEnsured = false;
  final Set<void Function()> _listeners = {};

  static const String _createTableSql = '''
CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  day_serial INTEGER NOT NULL,
  title TEXT NOT NULL,
  amount_minor INTEGER NOT NULL
)
''';

  static const String _createDayIndexSql =
      'CREATE INDEX IF NOT EXISTS idx_expenses_day ON expenses (day_serial)';

  static const String _selectInRangeSql = '''
SELECT id, created_at, day_serial, title, amount_minor
FROM expenses
WHERE is_deleted = 0 AND day_serial BETWEEN ? AND ?
ORDER BY created_at DESC
''';

  static const String _insertExpenseSql = '''
INSERT INTO expenses (
  id,
  created_at,
  updated_at,
  is_deleted,
  day_serial,
  title,
  amount_minor
) VALUES (?, ?, ?, 0, ?, ?, ?)
''';

  static const String _softDeleteExpenseSql = '''
UPDATE expenses
SET is_deleted = 1, updated_at = ?
WHERE id = ? AND is_deleted = 0
''';

  Future<void> _ensureTable() async {
    if (_tableEnsured) return;
    await _database.customStatement(_createTableSql);
    await _database.customStatement(_createDayIndexSql);
    _tableEnsured = true;
  }

  void _notifyChange() {
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  Stream<List<ExpenseEntry>> watchInRange(DayRange range) {
    return Stream<List<ExpenseEntry>>.multi((controller) {
      var isClosed = false;

      Future<void> emit() async {
        try {
          await _ensureTable();
          final entries = await _queryInRange(range);
          if (!isClosed) {
            controller.add(entries);
          }
        } on Object catch (error, stackTrace) {
          if (!isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      }

      void onChange() {
        unawaited(emit());
      }

      _listeners.add(onChange);
      controller.onCancel = () {
        isClosed = true;
        _listeners.remove(onChange);
      };

      unawaited(emit());
    });
  }

  Future<List<ExpenseEntry>> _queryInRange(DayRange range) async {
    final rows = await _database
        .customSelect(
          _selectInRangeSql,
          variables: [
            Variable.withInt(range.first.serial),
            Variable.withInt(range.last.serial),
          ],
        )
        .get();
    return rows
        .map(
          (row) => ExpenseEntry(
            id: row.read<String>('id'),
            createdAtMs: row.read<int>('created_at'),
            daySerial: row.read<int>('day_serial'),
            title: row.read<String>('title'),
            amount: Money(row.read<int>('amount_minor'), _currency),
          ),
        )
        .toList();
  }

  @useResult
  Future<Result<String, ExpenseFailure>> addExpense({
    required String title,
    required Money amount,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return const Err(ExpenseTitleRequired());
    }
    if (!amount.isPositive || amount.currency != _currency) {
      return const Err(ExpenseAmountInvalid());
    }

    final expenseId = _ids.next();
    final currentTime = _clock.now();
    final nowMs = currentTime.toUtc().millisecondsSinceEpoch;
    final currentDay = LocalDay.fromLocal(currentTime);

    try {
      await _ensureTable();
      await _database.customStatement(_insertExpenseSql, [
        expenseId,
        nowMs,
        nowMs,
        currentDay.serial,
        trimmedTitle,
        amount.minorUnits,
      ]);
      _notifyChange();
      return Ok(expenseId);
    } on Exception catch (error, stackTrace) {
      _log.error('expense.add', error, stackTrace);
      return const Err(ExpenseUnavailable());
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    try {
      await _ensureTable();
      final nowMs = _clock.now().toUtc().millisecondsSinceEpoch;
      await _database.customStatement(_softDeleteExpenseSql, [
        nowMs,
        expenseId,
      ]);
    } on Exception catch (error, stack) {
      _log.error('expense.delete', error, stack);
      return false;
    }
    _notifyChange();
    return true;
  }
}
