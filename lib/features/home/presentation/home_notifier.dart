import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/home/presentation/home_state.dart';

/// The home screen's view model: a live projection of the product list.
final homeNotifierProvider =
    StreamNotifierProvider.autoDispose<HomeNotifier, HomeState>(
      HomeNotifier.new,
    );

/// Re-emits whenever a product or stock movement is committed.
class HomeNotifier extends StreamNotifier<HomeState> {
  @override
  Stream<HomeState> build() => ref
      .watch(productRepositoryProvider)
      .watchActive()
      .map(
        (products) => HomeState(
          productCount: products.length,
          lowStockCount: products.where((p) => p.isLowOnStock).length,
        ),
      );
}
