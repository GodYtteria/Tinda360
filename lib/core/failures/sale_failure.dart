import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/money/money.dart';

/// Why a sale could not be recorded.
sealed class SaleFailure extends Failure {
  const SaleFailure();
}

/// The cart is empty.
final class SaleHasNoLines extends SaleFailure {
  /// Creates the failure.
  const SaleHasNoLines();

  @override
  String get code => 'sale.no_lines';
}

/// A line's quantity is zero, negative, or fractional for a whole-unit item.
final class SaleQuantityInvalid extends SaleFailure {
  /// Creates the failure for [productId].
  const SaleQuantityInvalid(this.productId);

  /// The offending product.
  final String productId;

  @override
  String get code => 'sale.quantity_invalid';
}

/// A product in the cart no longer exists.
final class SaleProductNotFound extends SaleFailure {
  /// Creates the failure for [productId].
  const SaleProductNotFound(this.productId);

  /// The missing product.
  final String productId;

  @override
  String get code => 'sale.product_not_found';
}

/// Utang was chosen without a customer.
final class SaleCustomerRequired extends SaleFailure {
  /// Creates the failure.
  const SaleCustomerRequired();

  @override
  String get code => 'sale.customer_required';
}

/// The chosen customer no longer exists.
final class SaleCustomerNotFound extends SaleFailure {
  /// Creates the failure for [customerId].
  const SaleCustomerNotFound(this.customerId);

  /// The missing customer.
  final String customerId;

  @override
  String get code => 'sale.customer_not_found';
}

/// Cash tendered is missing or less than the total.
final class SalePaymentTooLow extends SaleFailure {
  /// Creates the failure.
  const SalePaymentTooLow({required this.total, required this.tendered});

  /// The sale total.
  final Money total;

  /// What was handed over.
  final Money tendered;

  @override
  String get code => 'sale.payment_too_low';
}

/// The database could not complete the write.
final class SaleStoreUnavailable extends SaleFailure {
  /// Creates the failure.
  const SaleStoreUnavailable();

  @override
  String get code => 'sale.store_unavailable';
}
