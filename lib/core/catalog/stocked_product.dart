import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

final class StockedProduct {
  const StockedProduct({required this.product, required this.stock});

  final Product product;

  final Quantity stock;

  Money? get utangPrice => product.utangPrice;

  bool get tracksStock => product.tracksStock;

  bool get isSellable => !tracksStock || stock.isPositive;

  Quantity? get sellLimit => tracksStock ? stock : null;

  static const Quantity untrackedSellCap = Quantity.whole(999999);

  Quantity get sellCap => tracksStock ? stock : untrackedSellCap;

  bool get isLowOnStock {
    if (!tracksStock) return false;
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
