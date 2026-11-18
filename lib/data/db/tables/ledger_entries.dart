import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/customers.dart';
import 'package:tinda360/data/db/tables/sales.dart';

@DataClassName('LedgerEntryRow')
class LedgerEntries extends Table with AuditColumns {
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();

  TextColumn get kind => text()();

  IntColumn get amountMinor => integer()();

  TextColumn get deleteReason => text().nullable()();

  TextColumn get deletedByName => text().nullable()();

  TextColumn get saleId => text().nullable().references(
    Sales,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  List<String> get customConstraints => const [
    "CHECK (kind IN ('debt', 'payment', 'interest'))",
    'CHECK (amount_minor > 0)',
  ];

  @override
  bool get isStrict => true;
}
