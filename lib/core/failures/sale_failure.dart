import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/money/money.dart';

sealed class SaleFailure extends Failure {
  const new();
}

final class SaleHasNoLines extends SaleFailure {
  const new();

  @override
  String get code => 'sale.no_lines';
}

final class SaleQuantityInvalid extends SaleFailure {
  const new(this.productId);

  final String productId;

  @override
  String get code => 'sale.quantity_invalid';
}

final class SaleProductNotFound extends SaleFailure {
  const new(this.productId);

  final String productId;

  @override
  String get code => 'sale.product_not_found';
}

final class SaleInsufficientStock extends SaleFailure {
  const new({
    required this.productId,
    required this.available,
  });

  final String productId;

  final Quantity available;

  @override
  String get code => 'sale.insufficient_stock';
}

final class SaleCustomerRequired extends SaleFailure {
  const new();

  @override
  String get code => 'sale.customer_required';
}

final class SaleCustomerNotFound extends SaleFailure {
  const new(this.customerId);

  final String customerId;

  @override
  String get code => 'sale.customer_not_found';
}

final class SalePaymentTooLow extends SaleFailure {
  const new({required this.total, required this.tendered});

  final Money total;

  final Money tendered;

  @override
  String get code => 'sale.payment_too_low';
}

final class SalePaidNowInvalid extends SaleFailure {
  const new({required this.total, required this.paidNow});

  final Money total;

  final Money paidNow;

  @override
  String get code => 'sale.paid_now_invalid';
}

final class SaleInterestInvalid extends SaleFailure {
  const new();

  @override
  String get code => 'sale.interest_invalid';
}

final class SalePriceInvalid extends SaleFailure {
  const new(this.productId);

  final String productId;

  @override
  String get code => 'sale.price_invalid';
}

final class SaleNotFound extends SaleFailure {
  const new();

  @override
  String get code => 'sale.not_found';
}

final class SaleVoidAfterPayment extends SaleFailure {
  const new();

  @override
  String get code => 'sale.void_after_payment';
}

final class SaleVoidAfterReturn extends SaleFailure {
  const new();

  @override
  String get code => 'sale.void_after_return';
}

final class SaleStoreUnavailable extends SaleFailure {
  const new();

  @override
  String get code => 'sale.store_unavailable';
}
