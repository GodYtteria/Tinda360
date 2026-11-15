import 'package:tinda360/core/catalog/quantity.dart';

/// One product and quantity in the cart.
///
/// The price is not part of the draft: the repository reads the current
/// price from the database so the cart can never record a stale price.
final class SaleLineDraft {
  /// Creates a cart line.
  const SaleLineDraft({required this.productId, required this.quantity});

  /// The product being sold.
  final String productId;

  /// How much is being sold.
  final Quantity quantity;
}
