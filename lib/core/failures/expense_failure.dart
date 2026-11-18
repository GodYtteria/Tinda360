import 'package:tinda360/core/failure.dart';

sealed class ExpenseFailure extends Failure {
  const ExpenseFailure();
}

final class ExpenseTitleRequired extends ExpenseFailure {
  const ExpenseTitleRequired();

  @override
  String get code => 'expense.title_required';
}

final class ExpenseAmountInvalid extends ExpenseFailure {
  const ExpenseAmountInvalid();

  @override
  String get code => 'expense.amount_invalid';
}

final class ExpenseUnavailable extends ExpenseFailure {
  const ExpenseUnavailable();

  @override
  String get code => 'expense.unavailable';
}
