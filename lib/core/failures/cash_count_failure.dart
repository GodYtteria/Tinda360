import 'package:tinda360/core/failure.dart';

sealed class CashCountFailure extends Failure {
  const new();
}

final class CashCountAmountInvalid extends CashCountFailure {
  const new();

  @override
  String get code => 'cash_count.amount_invalid';
}

final class CashCountUnavailable extends CashCountFailure {
  const new();

  @override
  String get code => 'cash_count.unavailable';
}
