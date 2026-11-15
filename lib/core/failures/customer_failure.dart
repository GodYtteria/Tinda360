import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/money/money.dart';

/// Why a customer or utang change could not be saved.
sealed class CustomerFailure extends Failure {
  const CustomerFailure();
}

/// The name is empty.
final class CustomerNameRequired extends CustomerFailure {
  /// Creates the failure.
  const CustomerNameRequired();

  @override
  String get code => 'customer.name_required';
}

/// The customer does not exist or was deleted.
final class CustomerNotFound extends CustomerFailure {
  /// Creates the failure for [customerId].
  const CustomerNotFound(this.customerId);

  /// The missing customer.
  final String customerId;

  @override
  String get code => 'customer.not_found';
}

/// A payment or limit amount is zero or negative.
final class CustomerAmountInvalid extends CustomerFailure {
  /// Creates the failure.
  const CustomerAmountInvalid();

  @override
  String get code => 'customer.amount_invalid';
}

/// The payment is more than what the customer owes.
final class PaymentExceedsBalance extends CustomerFailure {
  /// Creates the failure.
  const PaymentExceedsBalance(this.balance);

  /// What the customer currently owes.
  final Money balance;

  @override
  String get code => 'customer.payment_exceeds_balance';
}

/// The database could not complete the write.
final class CustomerStoreUnavailable extends CustomerFailure {
  /// Creates the failure.
  const CustomerStoreUnavailable();

  @override
  String get code => 'customer.store_unavailable';
}
