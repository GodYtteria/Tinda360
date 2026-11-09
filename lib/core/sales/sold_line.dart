import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

final class SoldLine {
  const new({
    required this.saleId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  final String saleId;

  final Quantity quantity;

  final Money unitPrice;

  final Money unitCost;
}
