import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/data/db/tables/cash_counts.dart';
import 'package:tinda360/data/db/tables/categories.dart';
import 'package:tinda360/data/db/tables/customers.dart';
import 'package:tinda360/data/db/tables/ledger_entries.dart';
import 'package:tinda360/data/db/tables/products.dart';
import 'package:tinda360/data/db/tables/sale_items.dart';
import 'package:tinda360/data/db/tables/sale_returns.dart';
import 'package:tinda360/data/db/tables/sales.dart';
import 'package:tinda360/data/db/tables/stock_movements.dart';
import 'package:tinda360/data/db/tables/store_profiles.dart';

part 'app_database.g.dart';

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
    SaleReturns,
    CashCounts,
  ],
)
class AppDatabase extends _$AppDatabase {
  new(super.executor);

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
    ..._versionThreeIndexStatements,
  ];

  static const List<String> _versionThreeIndexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_sale_returns_sale ON sale_returns (sale_id)',
    'CREATE INDEX IF NOT EXISTS idx_cash_counts_day ON cash_counts (day_serial)',
  ];

  static const int currentSchemaVersion = 7;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      for (final statement in _indexStatements) {
        await customStatement(statement);
      }
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await _rebuildWithMissingColumns(migrator, sales);
      }
      if (from < 3) {
        await _rebuildWithMissingColumns(migrator, stockMovements);
        await migrator.createTable(saleReturns);
        await migrator.createTable(cashCounts);
        for (final statement in _versionThreeIndexStatements) {
          await customStatement(statement);
        }
      }
      if (from < 4) {
        await _rebuildWithMissingColumns(migrator, customers);
        await _rebuildWithMissingColumns(migrator, ledgerEntries);
      }
      if (from < 5) {
        await _rebuildWithMissingColumns(migrator, products);
      }
      if (from < 6) {
        await _rebuildWithMissingColumns(migrator, ledgerEntries);
      }
      if (from < 7) {
        await _rebuildWithMissingColumns(migrator, products);
        await _rebuildWithMissingColumns(migrator, sales);
        await _rebuildWithMissingColumns(migrator, saleReturns);
        await _rebuildWithMissingColumns(migrator, ledgerEntries);
        await _rebuildWithMissingColumns(migrator, storeProfiles);
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

  Future<void> _rebuildWithMissingColumns(
    Migrator migrator,
    TableInfo<Table, Object?> table,
  ) async {
    final existingRows = await customSelect(
      'SELECT name FROM pragma_table_info(?)',
      variables: [Variable.withString(table.actualTableName)],
    ).get();
    final existingNames = {
      for (final row in existingRows) row.read<String>('name'),
    };
    await migrator.alterTable(
      TableMigration(
        table,
        newColumns: [
          for (final column in table.$columns)
            if (!existingNames.contains(column.name)) column,
        ],
      ),
    );
  }
}
