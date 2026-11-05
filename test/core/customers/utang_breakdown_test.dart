import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/customers/utang_breakdown.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

LedgerRecord _entry(String id, int createdAtMs, String kind, int minor) =>
    LedgerRecord(
      id: id,
      createdAtMs: createdAtMs,
      kind: kind,
      amount: _php(minor),
    );

UtangBreakdown _breakdown(List<LedgerRecord> entries) =>
    computeUtangBreakdown(entries, Currency.php);

void main() {
  test('empty ledger has no utang and no interest', () {
    expect(
      _breakdown(const []),
      UtangBreakdown(utang: _php(0), interest: _php(0)),
    );
  });

  test('payment of utang plus interest clears both, new utang is clean', () {
    final paidOff = [
      _entry('a', 1, 'debt', 1000),
      _entry('b', 2, 'interest', 50),
      _entry('c', 3, 'payment', 1050),
    ];
    expect(
      _breakdown(paidOff),
      UtangBreakdown(utang: _php(0), interest: _php(0)),
    );
    final withNewUtang = [...paidOff, _entry('d', 4, 'debt', 200)];
    expect(
      _breakdown(withNewUtang),
      UtangBreakdown(utang: _php(200), interest: _php(0)),
    );
  });

  test('small payment only reduces interest', () {
    final entries = [
      _entry('a', 1, 'debt', 100),
      _entry('b', 2, 'interest', 5),
      _entry('c', 3, 'payment', 3),
    ];
    final breakdown = _breakdown(entries);
    expect(breakdown.interest, _php(2));
    expect(breakdown.utang, _php(100));
    expect(breakdown.total, _php(102));
  });

  test('payment larger than interest spills into utang', () {
    final entries = [
      _entry('a', 1, 'debt', 100),
      _entry('b', 2, 'interest', 5),
      _entry('c', 3, 'payment', 20),
    ];
    expect(
      _breakdown(entries),
      UtangBreakdown(utang: _php(85), interest: _php(0)),
    );
  });

  test('return credit tied to a sale reduces utang before interest', () {
    final entries = [
      _entry('a', 1, 'debt', 1000),
      _entry('b', 2, 'interest', 100),
      LedgerRecord(
        id: 'c',
        createdAtMs: 3,
        kind: 'payment',
        amount: _php(1000),
        saleId: 'sale-1',
      ),
    ];
    expect(
      _breakdown(entries),
      UtangBreakdown(utang: _php(0), interest: _php(100)),
    );
  });

  test('interest charged twice adds up until paid', () {
    final entries = [
      _entry('a', 1, 'debt', 1000),
      _entry('b', 2, 'interest', 50),
      _entry('c', 3, 'interest', 55),
      _entry('d', 4, 'payment', 105),
    ];
    expect(
      _breakdown(entries),
      UtangBreakdown(utang: _php(1000), interest: _php(0)),
    );
  });

  test('payment before interest does not erase later interest', () {
    final entries = [
      _entry('a', 1, 'debt', 1000),
      _entry('b', 2, 'payment', 400),
      _entry('c', 3, 'interest', 30),
    ];
    expect(
      _breakdown(entries),
      UtangBreakdown(utang: _php(600), interest: _php(30)),
    );
  });

  test('equal timestamps are ordered by id, input order is ignored', () {
    final entries = [
      _entry('3', 5, 'payment', 5),
      _entry('2', 5, 'interest', 5),
      _entry('1', 5, 'debt', 100),
    ];
    expect(
      _breakdown(entries),
      UtangBreakdown(utang: _php(100), interest: _php(0)),
    );
  });

  test('earlier timestamp wins over id order', () {
    final entries = [
      _entry('a', 9, 'debt', 100),
      _entry('z', 1, 'interest', 5),
      _entry('m', 2, 'payment', 5),
    ];
    expect(
      _breakdown(entries),
      UtangBreakdown(utang: _php(100), interest: _php(0)),
    );
  });
}
