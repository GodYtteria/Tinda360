import 'package:clock/clock.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';
import 'package:tinda360/data/repositories/sale_return_repository.dart';
import 'package:tinda360/data/repositories/store_profile_repository.dart';

import 'recording_app_log.dart';
import 'sequential_ids.dart';
import 'test_database.dart';

final class TestRepositories {
  TestRepositories({DateTime? now})
    : db = openTestDatabase(),
      clock = Clock.fixed(now ?? DateTime(2026, 11, 17, 10));

  final AppDatabase db;

  final Clock clock;

  final RecordingAppLog log = RecordingAppLog();

  final SequentialIds _ids = SequentialIds();

  late final ProductRepository products = ProductRepository(
    db: db,
    clock: clock,
    ids: _ids,
    log: log,
    currency: Currency.php,
  );

  late final SaleRepository sales = SaleRepository(
    db: db,
    clock: clock,
    ids: _ids,
    log: log,
    currency: Currency.php,
  );

  late final SaleReturnRepository saleReturns = SaleReturnRepository(
    db: db,
    clock: clock,
    ids: _ids,
    log: log,
    currency: Currency.php,
  );

  late final CustomerRepository customers = CustomerRepository(
    db: db,
    clock: clock,
    ids: _ids,
    log: log,
    currency: Currency.php,
  );

  late final StoreProfileRepository store = StoreProfileRepository(
    db: db,
    clock: clock,
    log: log,
  );

  Future<void> close() => db.close();
}
