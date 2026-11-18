final class HomeState {
  const HomeState({required this.productCount, required this.lowStockCount});

  final int productCount;

  final int lowStockCount;

  @override
  bool operator ==(Object other) =>
      other is HomeState &&
      other.productCount == productCount &&
      other.lowStockCount == lowStockCount;

  @override
  int get hashCode => Object.hash(productCount, lowStockCount);
}
