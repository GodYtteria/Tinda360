import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/categories.dart';

@DataClassName('ProductRow')
class Products extends Table with AuditColumns {
  TextColumn get name => text()();

  TextColumn get unit => text()();

  IntColumn get priceMinor => integer()();

  IntColumn get costMinor => integer()();

  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get barcode => text().nullable()();

  IntColumn get lowStockAtMilli => integer().nullable()();

  IntColumn get utangPriceMinor => integer().nullable()();

  BoolColumn get tracksStock => boolean().withDefault(const Constant(true))();

  IntColumn get expiryDaySerial => integer().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(name)) > 0)',
    "CHECK (unit IN ('piece', 'pack', 'sachet', 'can', 'bottle', 'bar', "
        "'bag', 'kilo', 'liter'))",
    'CHECK (price_minor >= 0)',
    'CHECK (utang_price_minor IS NULL OR utang_price_minor >= 0)',
    'CHECK (cost_minor >= 0)',
    'CHECK (low_stock_at_milli IS NULL OR low_stock_at_milli >= 0)',
  ];

  @override
  bool get isStrict => true;
}
