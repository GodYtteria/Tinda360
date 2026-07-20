import 'package:clock/clock.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';
import 'package:tinda360/data/repositories/store_profile_repository.dart';

import 'recording_app_log.dart';
import 'sequential_ids.dart';
import 'test_database.dart';

/// Every repository wired to one in-memory database and a fixed clock.
final class TestRepositories {
  /// Opens a fresh database at [now] (default: 17 Nov 2026, 10:00 local).
  TestRepositories({DateTime? now})
    : db = openTestDatabase(),
      clock = Clock.fixed(now ?? DateTime(2026, 11, 17, 10));

  /// The database.
  final AppDatabase db;

  /// The fixed clock.
  final Clock clock;

  /// Logged errors.
  final RecordingAppLog log = RecordingAppLog();

  final SequentialIds _ids = SequentialIds();

  /// Products.
  late final ProductRepository products = ProductRepository(
    db: db,
    clock: clock,
    ids: _ids,
    log: log,
    currency: Currency.php,
  );

  /// Sales.
  late final SaleRepository sales = SaleRepository(
    db: db,
    clock: clock,
    ids: _ids,
    log: log,
    currency: Currency.php,
  );

  /// Customers.
  late final CustomerRepository customers = CustomerRepository(
    db: db,
    clock: clock,
    ids: _ids,
    log: log,
    currency: Currency.php,
  );

  /// Store profile.
  late final StoreProfileRepository store = StoreProfileRepository(
    db: db,
    clock: clock,
    log: log,
  );

  /// Closes the database.
  Future<void> close() => db.close();
}
