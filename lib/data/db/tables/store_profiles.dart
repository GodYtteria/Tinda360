import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';

@DataClassName('StoreProfileRow')
class StoreProfiles extends Table with AuditColumns {
  TextColumn get name => text()();

  TextColumn get currencyCode => text()();

  TextColumn get address => text().nullable()();

  TextColumn get phone => text().nullable()();

  BoolColumn get onboardingDone =>
      boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(currency_code) = 3)',
  ];

  @override
  bool get isStrict => true;
}
