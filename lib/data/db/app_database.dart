import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/data/db/tables/categories.dart';
import 'package:tinda360/data/db/tables/customers.dart';
import 'package:tinda360/data/db/tables/ledger_entries.dart';
import 'package:tinda360/data/db/tables/products.dart';
import 'package:tinda360/data/db/tables/sale_items.dart';
import 'package:tinda360/data/db/tables/sales.dart';
import 'package:tinda360/data/db/tables/stock_movements.dart';
import 'package:tinda360/data/db/tables/store_profiles.dart';

part 'app_database.g.dart';

/// The single on-device database. Only lib/data/ may import it.
@DriftDatabase(
  tables: [
    StoreProfiles,
    Categories,
    Products,
    StockMovements,
    Customers,
    Sales,
    SaleItems,
    LedgerEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database on [executor].
  AppDatabase(super.executor);

  /// Primary key of the one store profile row.
  static const String storeProfileId = 'store';

  static const List<String> _indexStatements = [
    'CREATE INDEX idx_products_active_name ON products (is_deleted, name)',
    'CREATE UNIQUE INDEX ux_products_barcode ON products (barcode) '
        'WHERE barcode IS NOT NULL AND is_deleted = 0',
    'CREATE INDEX idx_stock_movements_product '
        'ON stock_movements (product_id)',
    'CREATE INDEX idx_stock_movements_sale ON stock_movements (sale_id)',
    'CREATE INDEX idx_sales_day ON sales (day_serial)',
    'CREATE INDEX idx_sales_customer ON sales (customer_id)',
    'CREATE INDEX idx_sale_items_sale ON sale_items (sale_id)',
    'CREATE INDEX idx_sale_items_product ON sale_items (product_id)',
    'CREATE INDEX idx_ledger_customer ON ledger_entries (customer_id)',
    'CREATE INDEX idx_ledger_sale ON ledger_entries (sale_id)',
  ];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      for (final statement in _indexStatements) {
        await customStatement(statement);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated) {
        final nowMs = clock.now().toUtc().millisecondsSinceEpoch;
        await into(storeProfiles).insert(
          StoreProfilesCompanion.insert(
            id: storeProfileId,
            createdAt: nowMs,
            updatedAt: nowMs,
            name: '',
            currencyCode: Currency.php.code,
          ),
        );
      }
    },
  );
}
