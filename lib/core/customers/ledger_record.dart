import 'package:meta/meta.dart';
import 'package:tinda360/core/money/money.dart';

/// A single debt or payment entry on a customer's utang ledger.
@immutable
final class LedgerRecord {
  /// Creates a ledger record.
  const LedgerRecord({
    required this.id,
    required this.createdAtMs,
    required this.kind,
    required this.amount,
    this.saleId,
  });

  /// Unique identifier of the ledger entry.
  final String id;

  /// Creation timestamp in UTC milliseconds since epoch.
  final int createdAtMs;

  /// Entry type: `'debt'` or `'payment'`.
  final String kind;

  /// Positive monetary amount of this entry.
  final Money amount;

  /// Optional associated sale identifier when [kind] is `'debt'`.
  final String? saleId;

  /// Whether this entry increased the customer's utang.
  bool get isDebt => kind == 'debt';

  /// Whether this entry reduced the customer's utang.
  bool get isPayment => kind == 'payment';

  @override
  bool operator ==(Object other) =>
      other is LedgerRecord &&
      other.id == id &&
      other.createdAtMs == createdAtMs &&
      other.kind == kind &&
      other.amount == amount &&
      other.saleId == saleId;

  @override
  int get hashCode => Object.hash(id, createdAtMs, kind, amount, saleId);
}
