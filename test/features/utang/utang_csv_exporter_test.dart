import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/utang/data/utang_csv_exporter.dart';

final DateTime _now = DateTime.utc(2026, 6, 30);

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

LedgerRecord _entry(
  String id,
  String kind,
  int amountMinor,
  DateTime createdAt, {
  bool isDeleted = false,
}) => LedgerRecord(
  id: id,
  createdAtMs: createdAt.millisecondsSinceEpoch,
  kind: kind,
  amount: _php(amountMinor),
  isDeleted: isDeleted,
);

CustomerBalance _balance(
  String name,
  int balanceMinor, {
  String? phone,
  int? interestMinor,
}) => CustomerBalance(
  customer: Customer(id: name, name: name, phone: phone),
  balance: _php(balanceMinor),
  outstandingInterestOrNull: interestMinor == null ? null : _php(interestMinor),
);

void main() {
  const header =
      'suki,phone,balance,utang,interest,last_payment_date,oldest_debt_days';

  test('empty list gives only the header', () {
    final csv = exportUtangCsv(
      balances: const [],
      ledgerByCustomer: const {},
      now: _now,
    );
    expect(csv, header);
  });

  test('row has balance split, last payment date and debt age', () {
    final csv = exportUtangCsv(
      balances: [_balance('Ana', 11050, phone: '0917', interestMinor: 1050)],
      ledgerByCustomer: {
        'Ana': [
          _entry('a', 'debt', 20000, DateTime.utc(2026, 5)),
          _entry('b', 'payment', 5000, DateTime.utc(2026, 5, 10)),
          _entry('c', 'payment', 4000, DateTime(2026, 6, 1, 23)),
          _entry(
            'd',
            'payment',
            9999,
            DateTime.utc(2026, 6, 20),
            isDeleted: true,
          ),
        ],
      },
      now: _now,
    );
    expect(csv.split('\r\n'), [
      header,
      'Ana,0917,110.50,100.00,10.50,2026-06-01,60',
    ]);
  });

  test('customer without payments or debt has empty date and age', () {
    final csv = exportUtangCsv(
      balances: [_balance('Ben', 0)],
      ledgerByCustomer: const {},
      now: _now,
    );
    expect(csv.split('\r\n').last, 'Ben,,0.00,0.00,0.00,,');
  });

  test('last payment date ignores sale-linked payments', () {
    final csv = exportUtangCsv(
      balances: [_balance('Cora', 5000)],
      ledgerByCustomer: {
        'Cora': [
          _entry('a', 'payment', 1000, DateTime(2026, 5, 10, 7)),
          LedgerRecord(
            id: 'b',
            createdAtMs: DateTime(2026, 6, 20, 7).millisecondsSinceEpoch,
            kind: 'payment',
            amount: _php(2000),
            saleId: 'sale-1',
          ),
        ],
      },
      now: _now,
    );
    expect(csv.split('\r\n')[1], contains(',2026-05-10,'));
  });

  test('formula looking names and phones are neutralized', () {
    final csv = exportUtangCsv(
      balances: [
        _balance('=HYPERLINK("x")', 100, phone: '+cmd'),
        _balance('-cmd', 100),
        _balance('@sum', 100),
      ],
      ledgerByCustomer: const {},
      now: _now,
    );
    final rows = csv.split('\r\n');
    expect(rows[1], startsWith('"\'=HYPERLINK(""x"")",\'+cmd,'));
    expect(rows[2], startsWith("'-cmd,"));
    expect(rows[3], startsWith("'@sum,"));
  });

  test('names with commas and quotes are quoted', () {
    final csv = exportUtangCsv(
      balances: [_balance('Cruz, "Mang" Juan', 100)],
      ledgerByCustomer: const {},
      now: _now,
    );
    expect(csv.split('\r\n')[1], startsWith('"Cruz, ""Mang"" Juan",'));
  });
}
