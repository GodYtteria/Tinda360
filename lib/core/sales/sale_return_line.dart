import 'package:tinda360/core/catalog/quantity.dart';

final class SaleReturnLine {
  const SaleReturnLine({required this.productId, required this.quantity});

  final String productId;

  final Quantity quantity;
}
