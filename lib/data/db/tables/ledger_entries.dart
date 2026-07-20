import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/customers.dart';
import 'package:tinda360/data/db/tables/sales.dart';

/// Every utang and payment. A customer's balance is debts minus payments.
@DataClassName('LedgerEntryRow')
class LedgerEntries extends Table with AuditColumns {
  /// The customer.
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();

  /// `debt` or `payment`.
  TextColumn get kind => text()();

  /// Always positive, in minor units; [kind] gives the direction.
  IntColumn get amountMinor => integer()();

  /// The sale that created this debt, if any.
  TextColumn get saleId => text().nullable().references(
    Sales,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  List<String> get customConstraints => const [
    "CHECK (kind IN ('debt', 'payment'))",
    'CHECK (amount_minor > 0)',
  ];

  @override
  bool get isStrict => true;
}
