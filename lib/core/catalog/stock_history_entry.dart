import 'package:tinda360/core/catalog/quantity.dart';

final class StockHistoryEntry {
  const StockHistoryEntry({
    required this.id,
    required this.createdAtMs,
    required this.reason,
    required this.change,
    required this.stockAfter,
  });

  final String id;

  final int createdAtMs;

  final String reason;

  final Quantity change;

  final Quantity stockAfter;

  @override
  bool operator ==(Object other) =>
      other is StockHistoryEntry &&
      other.id == id &&
      other.createdAtMs == createdAtMs &&
      other.reason == reason &&
      other.change == change &&
      other.stockAfter == stockAfter;

  @override
  int get hashCode => Object.hash(id, createdAtMs, reason, change, stockAfter);
}
