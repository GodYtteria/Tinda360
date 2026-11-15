import 'package:tinda360/core/money/money.dart';

/// Totals for a range of days. Always derived from sale lines, never stored.
final class SalesSummary {
  /// Creates a summary.
  const SalesSummary({
    required this.revenue,
    required this.cost,
    required this.saleCount,
  });

  /// Total sold.
  final Money revenue;

  /// Total cost of what was sold.
  final Money cost;

  /// Number of sales.
  final int saleCount;

  /// Revenue minus cost.
  Money get profit => revenue - cost;

  @override
  bool operator ==(Object other) =>
      other is SalesSummary &&
      other.revenue == revenue &&
      other.cost == cost &&
      other.saleCount == saleCount;

  @override
  int get hashCode => Object.hash(revenue, cost, saleCount);
}
