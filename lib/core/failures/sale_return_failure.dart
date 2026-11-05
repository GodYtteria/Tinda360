import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failure.dart';

sealed class SaleReturnFailure extends Failure {
  const SaleReturnFailure();
}

final class SaleReturnNothingSelected extends SaleReturnFailure {
  const SaleReturnNothingSelected();

  @override
  String get code => 'sale_return.nothing_selected';
}

final class SaleReturnQuantityInvalid extends SaleReturnFailure {
  const SaleReturnQuantityInvalid(this.productId);

  final String productId;

  @override
  String get code => 'sale_return.quantity_invalid';
}

final class SaleReturnTooMany extends SaleReturnFailure {
  const SaleReturnTooMany({required this.productId, required this.returnable});

  final String productId;

  final Quantity returnable;

  @override
  String get code => 'sale_return.too_many';
}

final class SaleReturnSaleVoided extends SaleReturnFailure {
  const SaleReturnSaleVoided();

  @override
  String get code => 'sale_return.sale_voided';
}

final class SaleReturnNotFound extends SaleReturnFailure {
  const SaleReturnNotFound();

  @override
  String get code => 'sale_return.not_found';
}

final class SaleReturnStoreUnavailable extends SaleReturnFailure {
  const SaleReturnStoreUnavailable();

  @override
  String get code => 'sale_return.store_unavailable';
}
