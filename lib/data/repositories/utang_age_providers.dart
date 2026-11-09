import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/repositories/utang_age_repository.dart';
import 'package:tinda360/services/service_providers.dart';

final utangAgeRepositoryProvider = Provider<UtangAgeRepository>(
  (ref) => UtangAgeRepository(
    db: ref.watch(appDatabaseProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

final StreamProvider<Map<String, int>> utangAgeDaysProvider =
    StreamProvider.autoDispose<Map<String, int>>((
      ref,
    ) {
      final now = ref.watch(clockProvider).now();
      return ref.watch(utangAgeRepositoryProvider).watchLedgerByCustomer().map((
        entriesByCustomer,
      ) {
        final ageDaysByCustomer = <String, int>{};
        for (final entry in entriesByCustomer.entries) {
          final ageDays = oldestOutstandingDebtAgeDays(entry.value, now);
          if (ageDays != null) ageDaysByCustomer[entry.key] = ageDays;
        }
        return ageDaysByCustomer;
      });
    });
