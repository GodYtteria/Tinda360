import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/categories.dart';

/// Products for sale. Stock is NOT stored here; it is the sum of
/// stock_movements.
@DataClassName('ProductRow')
class Products extends Table with AuditColumns {
  /// Display name.
  TextColumn get name => text()();

  /// `ProductUnit.storageName`.
  TextColumn get unit => text()();

  /// Selling price per unit, in minor units.
  IntColumn get priceMinor => integer()();

  /// Cost per unit, in minor units.
  IntColumn get costMinor => integer()();

  /// Optional category; cleared if the category is removed.
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Optional barcode, unique among active products (see app_database).
  TextColumn get barcode => text().nullable()();

  /// Optional low-stock alert level, thousandths of a unit.
  IntColumn get lowStockAtMilli => integer().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(name)) > 0)',
    "CHECK (unit IN ('piece', 'pack', 'sachet', 'can', 'bottle', 'bar', "
        "'bag', 'kilo', 'liter'))",
    'CHECK (price_minor >= 0)',
    'CHECK (cost_minor >= 0)',
    'CHECK (low_stock_at_milli IS NULL OR low_stock_at_milli >= 0)',
  ];

  @override
  bool get isStrict => true;
}
