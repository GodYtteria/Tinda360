import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/products.dart';
import 'package:tinda360/data/db/tables/sales.dart';

/// The lines of a sale, with prices copied at the moment of sale.
@DataClassName('SaleItemRow')
class SaleItems extends Table with AuditColumns {
  /// The owning sale.
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.cascade)();

  /// The product sold.
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();

  /// Quantity sold, thousandths of a unit.
  IntColumn get qtyMilli => integer()();

  /// Price per unit when sold, in minor units.
  IntColumn get unitPriceMinor => integer()();

  /// Cost per unit when sold, in minor units.
  IntColumn get unitCostMinor => integer()();

  @override
  List<String> get customConstraints => const [
    'CHECK (qty_milli > 0)',
    'CHECK (unit_price_minor >= 0)',
    'CHECK (unit_cost_minor >= 0)',
  ];

  @override
  bool get isStrict => true;
}
