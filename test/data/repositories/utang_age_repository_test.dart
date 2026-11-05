import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/data/repositories/utang_age_repository.dart';

const int _millisPerDay = 24 * 60 * 60 * 1000;

final DateTime _now = DateTime.utc(2026, 6, 30);

int _daysAgoMs(int days) => _now.millisecondsSinceEpoch - days * _millisPerDay;

LedgerRecord _entry(
  String id,
  String kind,
  int amountMinor,
  int daysAgo, {
  bool isDeleted = false,
}) => LedgerRecord(
  id: id,
  createdAtMs: _daysAgoMs(daysAgo),
  kind: kind,
  amount: Money(amountMinor, Currency.php),
  isDeleted: isDeleted,
);

void main() {
  group('oldestOutstandingDebtAgeDays', () {
    test('no entries gives null', () {
      expect(oldestOutstandingDebtAgeDays(const [], _now), isNull);
    });

    test('single unpaid debt gives its age', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 12),
      ], _now);
      expect(age, 12);
    });

    test('fully paid debt gives null', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 12),
        _entry('b', 'payment', 1000, 5),
      ], _now);
      expect(age, isNull);
    });

    test('payment clears oldest debt first', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 40),
        _entry('b', 'debt', 500, 10),
        _entry('c', 'payment', 1000, 5),
      ], _now);
      expect(age, 10);
    });

    test('partial payment keeps the oldest debt outstanding', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 40),
        _entry('b', 'debt', 500, 10),
        _entry('c', 'payment', 999, 5),
      ], _now);
      expect(age, 40);
    });

    test('payment spills over into the next debt', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 40),
        _entry('b', 'debt', 500, 20),
        _entry('c', 'debt', 500, 10),
        _entry('d', 'payment', 1200, 5),
      ], _now);
      expect(age, 20);
    });

    test('deleted payment does not clear debt', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 40),
        _entry('b', 'payment', 1000, 5, isDeleted: true),
      ], _now);
      expect(age, 40);
    });

    test('deleted debt is ignored', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 40, isDeleted: true),
        _entry('b', 'debt', 500, 3),
      ], _now);
      expect(age, 3);
    });

    test('interest entries do not create or clear debt age', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 15),
        _entry('b', 'interest', 100, 2),
      ], _now);
      expect(age, 15);
    });

    test('a manual payment settles interest before the debt', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 1000, 15),
        _entry('b', 'interest', 100, 2),
        _entry('c', 'payment', 1000, 1),
      ], _now);
      expect(age, 15);
    });

    test('entries are applied by time, not list order', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('c', 'payment', 1000, 5),
        _entry('b', 'debt', 500, 10),
        _entry('a', 'debt', 1000, 40),
      ], _now);
      expect(age, 10);
    });

    test('29 days is below and 30 days reaches the overdue boundary', () {
      final young = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 100, 29),
      ], _now);
      final old = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 100, 30),
      ], _now);
      expect(young! >= utangOverdueDays, isFalse);
      expect(old! >= utangOverdueDays, isTrue);
    });

    test('debt in the future clamps to zero days', () {
      final age = oldestOutstandingDebtAgeDays([
        _entry('a', 'debt', 100, -2),
      ], _now);
      expect(age, 0);
    });
  });
}
