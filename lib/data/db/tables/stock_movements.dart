import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/products.dart';
import 'package:tinda360/data/db/tables/sales.dart';

/// Every change to a product's stock. Current stock is the sum of deltas.
@DataClassName('StockMovementRow')
class StockMovements extends Table with AuditColumns {
  /// The product whose stock changed.
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();

  /// Change in thousandths of a unit; negative for sales.
  IntColumn get qtyDeltaMilli => integer()();

  /// Why stock changed.
  TextColumn get reason => text()();

  /// The sale that caused this movement, if any.
  TextColumn get saleId => text().nullable().references(
    Sales,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  List<String> get customConstraints => const [
    'CHECK (qty_delta_milli <> 0)',
    "CHECK (reason IN ('initial', 'restock', 'sale', 'adjust'))",
    "CHECK (reason <> 'sale' OR sale_id IS NOT NULL)",
  ];

  @override
  bool get isStrict => true;
}
