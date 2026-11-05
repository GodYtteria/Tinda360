import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/repositories/sale_return_repository.dart';
import 'package:tinda360/services/service_providers.dart';

final saleReturnRepositoryProvider = Provider<SaleReturnRepository>(
  (ref) => SaleReturnRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);
