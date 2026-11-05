import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/repositories/cash_count_repository.dart';
import 'package:tinda360/services/service_providers.dart';

final cashCountRepositoryProvider = Provider<CashCountRepository>(
  (ref) => CashCountRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);
