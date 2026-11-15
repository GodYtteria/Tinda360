import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

/// A product the store sells.
final class Product {
  /// Creates a product.
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.cost,
    this.categoryId,
    this.barcode,
    this.lowStockAt,
  });

  /// Stable identifier.
  final String id;

  /// Display name, as the owner typed it.
  final String name;

  /// How the product is counted.
  final ProductUnit unit;

  /// Selling price per one [unit].
  final Money price;

  /// Cost (puhunan) per one [unit].
  final Money cost;

  /// Optional category link.
  final String? categoryId;

  /// Optional barcode.
  final String? barcode;

  /// Stock level at or below which the product counts as low; null = no alert.
  final Quantity? lowStockAt;

  /// Profit per one [unit] (may be negative if priced below cost).
  Money get marginPerUnit => price - cost;

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.name == name &&
      other.unit == unit &&
      other.price == price &&
      other.cost == cost &&
      other.categoryId == categoryId &&
      other.barcode == barcode &&
      other.lowStockAt == lowStockAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    unit,
    price,
    cost,
    categoryId,
    barcode,
    lowStockAt,
  );
}
