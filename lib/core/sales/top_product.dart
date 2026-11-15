import 'package:meta/meta.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

/// Aggregated sales metrics for a single product over a report period.
@immutable
final class TopProduct {
  /// Creates a top-product entry.
  const TopProduct({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  /// Identifier of the product.
  final String productId;

  /// Display name of the product.
  final String productName;

  /// Unit of measure for [totalQuantity].
  final ProductUnit unit;

  /// Total quantity sold in the period.
  final Quantity totalQuantity;

  /// Total revenue generated in the period.
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
