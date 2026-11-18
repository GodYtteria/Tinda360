import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/customers.dart';

@DataClassName('SaleRow')
class Sales extends Table with AuditColumns {
  TextColumn get method => text()();

  IntColumn get paidMinor => integer()();

  IntColumn get tenderedMinor => integer().nullable()();

  TextColumn get cashierName => text().nullable()();

  TextColumn get customerId => text().nullable().references(
    Customers,
    #id,
    onDelete: KeyAction.restrict,
  )();

  IntColumn get daySerial => integer()();

  TextColumn get ewalletReference => text().nullable()();

  @override
  List<String> get customConstraints => const [
    "CHECK (method IN ('cash', 'ewallet', 'utang'))",
    'CHECK (paid_minor >= 0)',
    'CHECK (tendered_minor IS NULL OR tendered_minor >= paid_minor)',
    "CHECK (method <> 'utang' OR customer_id IS NOT NULL)",
  ];

  @override
  bool get isStrict => true;
}
