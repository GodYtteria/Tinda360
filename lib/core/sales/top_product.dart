import 'package:meta/meta.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

@immutable
final class TopProduct {
  const TopProduct({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  final String productId;

  final String productName;

  final ProductUnit unit;

  final Quantity totalQuantity;

  final Money totalRevenue;

  @override
  bool operator ==(Object other) =>
      other is TopProduct &&
      other.productId == productId &&
      other.productName == productName &&
      other.unit == unit &&
      other.totalQuantity == totalQuantity &&
      other.totalRevenue == totalRevenue;

  @override
  int get hashCode => Object.hash(
    productId,
    productName,
    unit,
    totalQuantity,
    totalRevenue,
  );
}
