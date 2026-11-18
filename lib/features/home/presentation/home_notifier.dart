import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/home/presentation/home_state.dart';

final homeNotifierProvider =
    StreamNotifierProvider.autoDispose<HomeNotifier, HomeState>(
      HomeNotifier.new,
    );

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
