import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';

/// The single store profile row.
@DataClassName('StoreProfileRow')
class StoreProfiles extends Table with AuditColumns {
  /// Store name; empty until setup.
  TextColumn get name => text()();

  /// ISO-4217 code for every amount in the store.
  TextColumn get currencyCode => text()();

  /// Whether first-run setup is done.
  BoolColumn get onboardingDone =>
      boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(currency_code) = 3)',
  ];

  @override
  bool get isStrict => true;
}
