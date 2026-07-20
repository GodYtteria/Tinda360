import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';

/// Suki who can buy on credit. Balance is NOT stored; it is derived from
/// ledger_entries.
@DataClassName('CustomerRow')
class Customers extends Table with AuditColumns {
  /// Display name.
  TextColumn get name => text()();

  /// Optional mobile number.
  TextColumn get phone => text().nullable()();

  /// Optional credit limit, in minor units.
  IntColumn get creditLimitMinor => integer().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(name)) > 0)',
    'CHECK (credit_limit_minor IS NULL OR credit_limit_minor > 0)',
  ];

  @override
  bool get isStrict => true;
}
