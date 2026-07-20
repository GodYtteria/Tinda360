import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

/// The fields the owner enters to add or edit a product.
final class ProductDraft {
  /// Creates a draft.
  const ProductDraft({
    required this.name,
    required this.unit,
    required this.price,
    required this.cost,
    this.categoryId,
    this.barcode,
    this.lowStockAt,
    this.initialStock = Quantity.zero,
  });

  /// Display name.
  final String name;

  /// How the product is counted.
  final ProductUnit unit;

  /// Selling price per unit.
  final Money price;

  /// Cost per unit.
  final Money cost;

  /// Optional category link.
  final String? categoryId;

  /// Optional barcode.
  final String? barcode;

  /// Optional low-stock alert level.
  final Quantity? lowStockAt;

  /// Stock on hand when the product is first added. Ignored on edit.
  final Quantity initialStock;
}
