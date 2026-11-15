import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/customers.dart';

/// One completed sale. The total is NOT stored; it is derived from
/// sale_items.
@DataClassName('SaleRow')
class Sales extends Table with AuditColumns {
  /// `PaymentMethod.storageName`.
  TextColumn get method => text()();

  /// What was paid at the counter, in minor units (0 for utang).
  IntColumn get paidMinor => integer()();

  /// The customer, required for utang.
  TextColumn get customerId => text().nullable().references(
    Customers,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// The local calendar day of the sale (`LocalDay.serial`).
  IntColumn get daySerial => integer()();

  /// Optional e-wallet reference number.
  TextColumn get ewalletReference => text().nullable()();

  @override
  List<String> get customConstraints => const [
    "CHECK (method IN ('cash', 'ewallet', 'utang'))",
    'CHECK (paid_minor >= 0)',
    "CHECK (method <> 'utang' OR customer_id IS NOT NULL)",
  ];

  @override
  bool get isStrict => true;
}
