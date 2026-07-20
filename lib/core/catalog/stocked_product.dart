import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/quantity.dart';

/// A product together with its current stock, derived from stock movements.
final class StockedProduct {
  /// Pairs [product] with its derived [stock].
  const StockedProduct({required this.product, required this.stock});

  /// The product.
  final Product product;

  /// Current stock; can be negative if sales were recorded beyond stock.
  final Quantity stock;

  /// Whether stock is at or below the product's alert level.
  bool get isLowOnStock {
    final threshold = product.lowStockAt;
    return threshold != null && stock.compareTo(threshold) <= 0;
  }

  @override
  bool operator ==(Object other) =>
      other is StockedProduct &&
      other.product == product &&
      other.stock == stock;

  @override
  int get hashCode => Object.hash(product, stock);
}
