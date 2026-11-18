import 'package:tinda360/core/failure.dart';

sealed class CashCountFailure extends Failure {
  const CashCountFailure();
}

final class CashCountAmountInvalid extends CashCountFailure {
  const CashCountAmountInvalid();

  @override
  String get code => 'cash_count.amount_invalid';
}

final class CashCountUnavailable extends CashCountFailure {
  const CashCountUnavailable();

  @override
  String get code => 'cash_count.unavailable';
}
