import 'package:meta/meta.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

@immutable
final class Product {
  const new({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.cost,
    this.categoryId,
    this.barcode,
    this.lowStockAt,
    this.utangPrice,
    this.tracksStock = true,
    this.expiryDay,
  });

  final String id;

  final String name;

  final ProductUnit unit;

  final Money price;

  final Money cost;

  final String? categoryId;

  final String? barcode;

  final Quantity? lowStockAt;

  final Money? utangPrice;

  final bool tracksStock;

  final LocalDay? expiryDay;

  Money get marginPerUnit => price - cost;

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.name == name &&
      other.unit == unit &&
      other.price == price &&
      other.cost == cost &&
      other.categoryId == categoryId &&
      other.barcode == barcode &&
      other.lowStockAt == lowStockAt &&
      other.utangPrice == utangPrice &&
      other.tracksStock == tracksStock &&
      other.expiryDay == expiryDay;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    unit,
    price,
    cost,
    categoryId,
    barcode,
    lowStockAt,
    utangPrice,
    tracksStock,
    expiryDay,
  );
}
