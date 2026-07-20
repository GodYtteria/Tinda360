import 'package:meta/meta.dart';
import 'package:tinda360/core/money/money.dart';

/// A single recorded store expense entry.
@immutable
final class ExpenseEntry {
  /// Creates an expense entry.
  const ExpenseEntry({
    required this.id,
    required this.createdAtMs,
    required this.daySerial,
    required this.title,
    required this.amount,
  });

  /// Expense identifier.
  final String id;

  /// UTC epoch milliseconds when the expense was recorded.
  final int createdAtMs;

  /// Local calendar day serial when the expense was recorded.
  final int daySerial;

  /// Description of the expense.
  final String title;

  /// Expense amount.
  final Money amount;

  @override
  bool operator ==(Object other) =>
      other is ExpenseEntry &&
      other.id == id &&
      other.createdAtMs == createdAtMs &&
      other.daySerial == daySerial &&
      other.title == title &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(id, createdAtMs, daySerial, title, amount);

  @override
  String toString() =>
      'ExpenseEntry($id, $title, $amount, day=$daySerial)';
}
