import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/products.dart';
import 'package:tinda360/data/db/tables/sales.dart';

@DataClassName('StockMovementRow')
class StockMovements extends Table with AuditColumns {
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();

  IntColumn get qtyDeltaMilli => integer()();

  TextColumn get reason => text()();

  TextColumn get saleId => text().nullable().references(
    Sales,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  List<String> get customConstraints => const [
    'CHECK (qty_delta_milli <> 0)',
    "CHECK (reason IN ('initial', 'restock', 'sale', 'adjust', 'return'))",
    "CHECK (reason <> 'sale' OR sale_id IS NOT NULL)",
  ];

  @override
  bool get isStrict => true;
}
