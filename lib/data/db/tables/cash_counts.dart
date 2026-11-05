import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';

@DataClassName('CashCountRow')
class CashCounts extends Table with AuditColumns {
  IntColumn get daySerial => integer()();

  IntColumn get expectedMinor => integer()();

  IntColumn get countedMinor => integer()();

  TextColumn get note => text().nullable()();

  @override
  List<String> get customConstraints => const ['CHECK (counted_minor >= 0)'];

  @override
  bool get isStrict => true;
}
