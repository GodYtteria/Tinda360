/// What the home screen shows. Derived from the product list, never stored.
final class HomeState {
  /// Creates the state.
  const HomeState({required this.productCount, required this.lowStockCount});

  /// Active products.
  final int productCount;

  /// Products at or below their alert level.
  final int lowStockCount;

  @override
  bool operator ==(Object other) =>
      other is HomeState &&
      other.productCount == productCount &&
      other.lowStockCount == lowStockCount;

  @override
  int get hashCode => Object.hash(productCount, lowStockCount);
}
