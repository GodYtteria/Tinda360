import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';

@DataClassName('CustomerRow')
class Customers extends Table with AuditColumns {
  TextColumn get name => text()();

  TextColumn get phone => text().nullable()();

  IntColumn get creditLimitMinor => integer().nullable()();

  IntColumn get interestPercentTenths => integer().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(name)) > 0)',
    'CHECK (credit_limit_minor IS NULL OR credit_limit_minor > 0)',
    'CHECK (interest_percent_tenths IS NULL OR '
        'interest_percent_tenths BETWEEN 1 AND 500)',
  ];

  @override
  bool get isStrict => true;
}
