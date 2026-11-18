import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/money/money.dart';

sealed class CustomerFailure extends Failure {
  const new();
}

final class CustomerNameRequired extends CustomerFailure {
  const new();

  @override
  String get code => 'customer.name_required';
}

final class CustomerNotFound extends CustomerFailure {
  const new(this.customerId);

  final String customerId;

  @override
  String get code => 'customer.not_found';
}

final class CustomerAmountInvalid extends CustomerFailure {
  const new();

  @override
  String get code => 'customer.amount_invalid';
}

final class PaymentExceedsBalance extends CustomerFailure {
  const new(this.balance);

  final Money balance;

  @override
  String get code => 'customer.payment_exceeds_balance';
}

final class CustomerStoreUnavailable extends CustomerFailure {
  const new();

  @override
  String get code => 'customer.store_unavailable';
}

final class InterestRateNotSet extends CustomerFailure {
  const new();

  @override
  String get code => 'customer.interest_rate_not_set';
}

final class InterestNoBalance extends CustomerFailure {
  const new();

  @override
  String get code => 'customer.interest_no_balance';
}

final class InterestAmountChanged extends CustomerFailure {
  const new(this.currentAmount);

  final Money currentAmount;

  @override
  String get code => 'customer.interest_amount_changed';
}

final class LedgerEntryNotFound extends CustomerFailure {
  const new(this.entryId);

  final String entryId;

  @override
  String get code => 'customer.ledger_entry_not_found';
}

final class LedgerEntryAlreadyDeleted extends CustomerFailure {
  const new(this.entryId);

  final String entryId;

  @override
  String get code => 'customer.ledger_entry_already_deleted';
}

final class LedgerEntryNotDeletable extends CustomerFailure {
  const new(this.entryId);

  final String entryId;

  @override
  String get code => 'customer.ledger_entry_not_deletable';
}

final class LedgerDeleteWouldGoNegative extends CustomerFailure {
  const new(this.balance);

  final Money balance;

  @override
  String get code => 'customer.ledger_delete_would_go_negative';
}

final class CustomerHasBalance extends CustomerFailure {
  const new(this.balance);

  final Money balance;

  @override
  String get code => 'customer.has_balance';
}
