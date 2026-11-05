import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

final class SaleLineDraft {
  const SaleLineDraft({
    required this.productId,
    required this.quantity,
    this.unitPriceOverride,
  });

  final String productId;

  final Quantity quantity;

  final Money? unitPriceOverride;
}
