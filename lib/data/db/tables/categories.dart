import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';

@DataClassName('CategoryRow')
class Categories extends Table with AuditColumns {
  TextColumn get name => text()();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(name)) > 0)',
  ];

  @override
  bool get isStrict => true;
}
