import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

/// A recorded sale line with the prices that applied at the time of sale.
final class SoldLine {
  /// Creates a sold line.
  const SoldLine({
    required this.saleId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  /// The sale this line belongs to.
  final String saleId;

  /// Quantity sold.
  final Quantity quantity;

  /// Price per unit when sold.
  final Money unitPrice;

  /// Cost per unit when sold.
  final Money unitCost;
}
