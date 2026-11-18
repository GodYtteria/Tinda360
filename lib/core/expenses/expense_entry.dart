import 'package:meta/meta.dart';
import 'package:tinda360/core/money/money.dart';

@immutable
final class ExpenseEntry {
  const new({
    required this.id,
    required this.createdAtMs,
    required this.daySerial,
    required this.title,
    required this.amount,
  });

  final String id;

  final int createdAtMs;

  final int daySerial;

  final String title;

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
  String toString() => 'ExpenseEntry($id, $title, $amount, day=$daySerial)';
}
