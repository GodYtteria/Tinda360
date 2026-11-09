import 'package:meta/meta.dart';
import 'package:tinda360/core/money/money.dart';

@immutable
final class SalesSummary {
  const new({
    required this.revenue,
    required this.cost,
    required this.saleCount,
  });

  final Money revenue;

  final Money cost;

  final int saleCount;

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
