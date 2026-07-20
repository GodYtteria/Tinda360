import 'package:tinda360/core/failure.dart';

/// Why an expense could not be recorded.
sealed class ExpenseFailure extends Failure {
  const ExpenseFailure();
}

/// The expense title is empty after trimming.
final class ExpenseTitleRequired extends ExpenseFailure {
  /// Creates the failure.
  const ExpenseTitleRequired();

  @override
  String get code => 'expense.title_required';
}

/// The expense amount is zero, negative, or in the wrong currency.
final class ExpenseAmountInvalid extends ExpenseFailure {
  /// Creates the failure.
  const ExpenseAmountInvalid();

  @override
  String get code => 'expense.amount_invalid';
}

/// The database could not complete the expense operation.
final class ExpenseUnavailable extends ExpenseFailure {
  /// Creates the failure.
  const ExpenseUnavailable();

  @override
  String get code => 'expense.unavailable';
}
