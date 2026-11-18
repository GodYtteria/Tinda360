import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';

final class ProductDraft {
  const new({
    required this.name,
    required this.unit,
    required this.price,
    required this.cost,
    this.categoryId,
    this.barcode,
    this.lowStockAt,
    this.initialStock = Quantity.zero,
    this.utangPrice,
    this.tracksStock = true,
    this.expiryDay,
  });

  final String name;

  final ProductUnit unit;

  final Money price;

  final Money cost;

  final String? categoryId;

  final String? barcode;

  final Quantity? lowStockAt;

  final Quantity initialStock;

  final Money? utangPrice;

  final bool tracksStock;

  final LocalDay? expiryDay;
}
