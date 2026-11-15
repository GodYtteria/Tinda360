import 'package:tinda360/core/failure.dart';

/// Why a product change could not be saved.
sealed class ProductFailure extends Failure {
  const ProductFailure();
}

/// The name is empty.
final class ProductNameRequired extends ProductFailure {
  /// Creates the failure.
  const ProductNameRequired();

  @override
  String get code => 'product.name_required';
}

/// Price or cost is negative.
final class ProductAmountInvalid extends ProductFailure {
  /// Creates the failure.
  const ProductAmountInvalid();

  @override
  String get code => 'product.amount_invalid';
}

/// A stock quantity is negative or fractional for a whole-unit product.
final class ProductQuantityInvalid extends ProductFailure {
  /// Creates the failure.
  const ProductQuantityInvalid();

  @override
  String get code => 'product.quantity_invalid';
}

/// Another active product already uses this barcode.
final class ProductBarcodeTaken extends ProductFailure {
  /// Creates the failure for [barcode].
  const ProductBarcodeTaken(this.barcode);

  /// The duplicate barcode.
  final String barcode;

  @override
  String get code => 'product.barcode_taken';
}

/// The product does not exist or was deleted.
final class ProductNotFound extends ProductFailure {
  /// Creates the failure for [productId].
  const ProductNotFound(this.productId);

  /// The missing product.
  final String productId;

  @override
  String get code => 'product.not_found';
}

/// The database could not complete the write.
final class ProductStoreUnavailable extends ProductFailure {
  /// Creates the failure.
  const ProductStoreUnavailable();

  @override
  String get code => 'product.store_unavailable';
}
