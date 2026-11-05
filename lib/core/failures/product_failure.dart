import 'package:tinda360/core/failure.dart';

sealed class ProductFailure extends Failure {
  const ProductFailure();
}

final class ProductNameRequired extends ProductFailure {
  const ProductNameRequired();

  @override
  String get code => 'product.name_required';
}

final class ProductAmountInvalid extends ProductFailure {
  const ProductAmountInvalid();

  @override
  String get code => 'product.amount_invalid';
}

final class ProductQuantityInvalid extends ProductFailure {
  const ProductQuantityInvalid();

  @override
  String get code => 'product.quantity_invalid';
}

final class ProductBarcodeTaken extends ProductFailure {
  const ProductBarcodeTaken(this.barcode);

  final String barcode;

  @override
  String get code => 'product.barcode_taken';
}

final class ProductNotFound extends ProductFailure {
  const ProductNotFound(this.productId);

  final String productId;

  @override
  String get code => 'product.not_found';
}

final class ProductStoreUnavailable extends ProductFailure {
  const ProductStoreUnavailable();

  @override
  String get code => 'product.store_unavailable';
}
