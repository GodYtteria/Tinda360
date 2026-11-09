import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/repositories/product_popularity_repository.dart';
import 'package:tinda360/services/service_providers.dart';

final productPopularityRepositoryProvider =
    Provider<ProductPopularityRepository>(
      (ref) => ProductPopularityRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
      ),
    );

final StreamProvider<Map<String, int>> productPopularityProvider =
    StreamProvider.autoDispose<Map<String, int>>(
      (ref) => ref
          .watch(productPopularityRepositoryProvider)
          .watchUnitsSoldMilliByProductId(),
    );
