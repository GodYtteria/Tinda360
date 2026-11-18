import 'package:drift/drift.dart';
import 'package:tinda360/data/db/tables/audit_columns.dart';
import 'package:tinda360/data/db/tables/products.dart';
import 'package:tinda360/data/db/tables/sales.dart';

@DataClassName('SaleReturnRow')
class SaleReturns extends Table with AuditColumns {
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.cascade)();

  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();

  IntColumn get qtyMilli => integer()();

  IntColumn get refundMinor => integer()();

  TextColumn get reason => text().nullable()();

  TextColumn get cashierName => text().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (qty_milli > 0)',
    'CHECK (refund_minor >= 0)',
  ];

  @override
  bool get isStrict => true;
}
