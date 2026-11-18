import 'package:meta/meta.dart';
import 'package:tinda360/core/money/money.dart';

@immutable
final class LedgerRecord {
  const new({
    required this.id,
    required this.createdAtMs,
    required this.kind,
    required this.amount,
    this.saleId,
    this.isDeleted = false,
    this.deleteReason,
    this.deletedAtMs,
    this.deletedByName,
  });

  final String? deletedByName;

  final String id;

  final int createdAtMs;

  final String kind;

  final Money amount;

  final String? saleId;

  final bool isDeleted;

  final String? deleteReason;

  final int? deletedAtMs;

  bool get isDeletable =>
      !isDeleted && saleId == null && (isPayment || isInterest);

  bool get isDebt => kind == 'debt';

  bool get isPayment => kind == 'payment';

  bool get isInterest => kind == 'interest';

  @override
  bool operator ==(Object other) =>
      other is LedgerRecord &&
      other.id == id &&
      other.createdAtMs == createdAtMs &&
      other.kind == kind &&
      other.amount == amount &&
      other.saleId == saleId &&
      other.isDeleted == isDeleted &&
      other.deleteReason == deleteReason &&
      other.deletedAtMs == deletedAtMs &&
      other.deletedByName == deletedByName;

  @override
  int get hashCode => Object.hash(
    id,
    createdAtMs,
    kind,
    amount,
    saleId,
    isDeleted,
    deleteReason,
    deletedAtMs,
    deletedByName,
  );
}
