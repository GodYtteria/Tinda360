import 'package:tinda360/core/failure.dart';

sealed class ExpenseFailure extends Failure {
  const new();
}

final class ExpenseTitleRequired extends ExpenseFailure {
  const new();

  @override
  String get code => 'expense.title_required';
}

final class ExpenseAmountInvalid extends ExpenseFailure {
  const new();

  @override
  String get code => 'expense.amount_invalid';
}

final class ExpenseUnavailable extends ExpenseFailure {
  const new();

  @override
  String get code => 'expense.unavailable';
}
