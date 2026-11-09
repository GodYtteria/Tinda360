import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tinda360/data/db/app_database.dart';

void main() {
  late Directory tempDirectory;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('tinda360_schema_');
  });

  tearDown(() => tempDirectory.deleteSync(recursive: true));

  Future<void> createVersionOneFile(File file) async {
    final current = AppDatabase(NativeDatabase(file));
    await current.customSelect('SELECT 1').get();
    await current.close();

    final raw = sqlite3.open(file.path);
    try {
      final createSql =
          raw
                  .select("SELECT sql FROM sqlite_master WHERE name = 'sales'")
                  .first
                  .values
                  .first!
              as String;
      final versionOneSql = createSql
          .replaceAll(RegExp(r'"tendered_minor" INTEGER NULL,\s*'), '')
          .replaceAll(
            RegExp(r',\s*CHECK \(tendered_minor IS NULL OR [^)]*\)'),
            '',
          );
      expect(versionOneSql, isNot(contains('tendered_minor')));
      raw
        ..execute('PRAGMA foreign_keys = OFF')
        ..execute('DROP TABLE sale_returns')
        ..execute('DROP TABLE cash_counts')
        ..execute('DROP TABLE sales')
        ..execute(versionOneSql)
        ..execute('CREATE INDEX idx_sales_day ON sales (day_serial)')
        ..execute('CREATE INDEX idx_sales_customer ON sales (customer_id)')
        ..execute('ALTER TABLE sales DROP COLUMN cashier_name')
        ..execute('ALTER TABLE products DROP COLUMN tracks_stock')
        ..execute('ALTER TABLE products DROP COLUMN expiry_day_serial')
        ..execute('ALTER TABLE ledger_entries DROP COLUMN delete_reason')
        ..execute('ALTER TABLE ledger_entries DROP COLUMN deleted_by_name')
        ..execute('ALTER TABLE store_profiles DROP COLUMN address')
        ..execute('ALTER TABLE store_profiles DROP COLUMN phone')
        ..execute(
          'INSERT INTO sales (id, created_at, updated_at, method, '
          "paid_minor, day_serial) VALUES ('old-sale', 1, 1, 'cash', 500, 1)",
        )
        ..execute(
          'INSERT INTO products (id, created_at, updated_at, name, '
          'unit, price_minor, cost_minor) '
          "VALUES ('old-product', 1, 1, 'Kopiko', 'sachet', 500, 400)",
        )
        ..execute(
          'INSERT INTO sale_items (id, created_at, updated_at, '
          'sale_id, product_id, qty_milli, unit_price_minor, '
          "unit_cost_minor) VALUES ('old-line', 1, 1, 'old-sale', "
          "'old-product', 1000, 500, 400)",
        )
        ..execute('PRAGMA user_version = 1');
    } finally {
      raw.close();
    }
  }

  test(
    'a version 1 database gains tendered_minor and keeps old sales',
    () async {
      final file = File('${tempDirectory.path}/store.sqlite');
      await createVersionOneFile(file);

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final rows = await upgraded
          .customSelect('SELECT id, paid_minor, tendered_minor FROM sales')
          .get();

      expect(rows.single.read<String>('id'), 'old-sale');
      expect(rows.single.read<int>('paid_minor'), 500);
      expect(rows.single.readNullable<int>('tendered_minor'), isNull);
      final version = await upgraded.customSelect('PRAGMA user_version').get();
      expect(
        version.single.data.values.first,
        AppDatabase.currentSchemaVersion,
      );
    },
  );

  test(
    'an upgraded database keeps sale lines and enforces the new rules',
    () async {
      final file = File('${tempDirectory.path}/store.sqlite');
      await createVersionOneFile(file);

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final saleLines = await upgraded
          .customSelect(
            'SELECT id FROM sale_items WHERE sale_id = ?',
            variables: [Variable.withString('old-sale')],
          )
          .get();
      expect(saleLines.map((row) => row.read<String>('id')), ['old-line']);

      final foreignKeyProblems = await upgraded
          .customSelect('PRAGMA foreign_key_check')
          .get();
      expect(foreignKeyProblems, isEmpty);

      final salesIndexes = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND tbl_name = 'sales' AND name LIKE 'idx_%' ORDER BY name",
          )
          .get();
      expect(
        salesIndexes.map((row) => row.read<String>('name')),
        ['idx_sales_customer', 'idx_sales_day'],
      );

      await expectLater(
        upgraded.customStatement(
          'INSERT INTO sales (id, created_at, updated_at, method, paid_minor, '
          'tendered_minor, day_serial) '
          "VALUES ('short-cash', 2, 2, 'cash', 500, 100, 1)",
        ),
        throwsA(anything),
      );
    },
  );

  test('an upgraded database gains return and cash count tables', () async {
    final file = File('${tempDirectory.path}/store.sqlite');
    await createVersionOneFile(file);

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.customStatement(
      'INSERT INTO sale_returns (id, created_at, updated_at, sale_id, '
      'product_id, qty_milli, refund_minor) '
      "VALUES ('return-1', 3, 3, 'old-sale', 'old-product', 1000, 500)",
    );
    await upgraded.customStatement(
      'INSERT INTO stock_movements (id, created_at, updated_at, product_id, '
      'qty_delta_milli, reason, sale_id) '
      "VALUES ('movement-return', 3, 3, 'old-product', 1000, 'return', "
      "'old-sale')",
    );
    await upgraded.customStatement(
      'INSERT INTO cash_counts (id, created_at, updated_at, day_serial, '
      "expected_minor, counted_minor) VALUES ('count-1', 3, 3, 1, 500, 480)",
    );

    final returnRows = await upgraded
        .customSelect('SELECT refund_minor FROM sale_returns')
        .get();
    expect(returnRows.single.read<int>('refund_minor'), 500);
    final countRows = await upgraded
        .customSelect('SELECT counted_minor FROM cash_counts')
        .get();
    expect(countRows.single.read<int>('counted_minor'), 480);
    final indexes = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name IN ('idx_sale_returns_sale', 'idx_cash_counts_day') "
          'ORDER BY name',
        )
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')),
      ['idx_cash_counts_day', 'idx_sale_returns_sale'],
    );
    final version = await upgraded.customSelect('PRAGMA user_version').get();
    expect(
      version.single.data.values.first,
      AppDatabase.currentSchemaVersion,
    );
  });

  test('an upgraded database accepts interest entries and a suki rate', () async {
    final file = File('${tempDirectory.path}/store.sqlite');
    await createVersionOneFile(file);

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.customStatement(
      'INSERT INTO customers (id, created_at, updated_at, name, '
      "interest_percent_tenths) VALUES ('suki-1', 1, 1, 'Ate Lina', 50)",
    );
    await upgraded.customStatement(
      'INSERT INTO ledger_entries (id, created_at, updated_at, customer_id, '
      "kind, amount_minor) VALUES ('tubo-1', 2, 2, 'suki-1', 'interest', 500)",
    );
    final rows = await upgraded
        .customSelect('SELECT kind FROM ledger_entries')
        .get();
    expect(rows.single.read<String>('kind'), 'interest');

    await expectLater(
      upgraded.customStatement(
        'INSERT INTO ledger_entries (id, created_at, updated_at, '
        'customer_id, kind, amount_minor) '
        "VALUES ('bad', 3, 3, 'suki-1', 'bonus', 100)",
      ),
      throwsA(anything),
    );
    await expectLater(
      upgraded.customStatement(
        'INSERT INTO customers (id, created_at, updated_at, name, '
        "interest_percent_tenths) VALUES ('suki-2', 1, 1, 'Mang Ben', 900)",
      ),
      throwsA(anything),
    );
  });

  test(
    'an upgraded database keeps products and accepts an utang price',
    () async {
      final file = File('${tempDirectory.path}/store.sqlite');
      await createVersionOneFile(file);

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final products = await upgraded
          .customSelect('SELECT id, utang_price_minor FROM products')
          .get();
      expect(products.single.read<String>('id'), 'old-product');
      expect(products.single.readNullable<int>('utang_price_minor'), isNull);

      await upgraded.customStatement(
        "UPDATE products SET utang_price_minor = 550 WHERE id = 'old-product'",
      );
      await expectLater(
        upgraded.customStatement(
          "UPDATE products SET utang_price_minor = -1 WHERE id = 'old-product'",
        ),
        throwsA(anything),
      );
      final saleLines = await upgraded
          .customSelect('SELECT id FROM sale_items')
          .get();
      expect(saleLines.map((row) => row.read<String>('id')), ['old-line']);
      final problems = await upgraded
          .customSelect('PRAGMA foreign_key_check')
          .get();
      expect(problems, isEmpty);
    },
  );

  test(
    'an upgraded database keeps ledger entries and gains a delete reason',
    () async {
      final file = File('${tempDirectory.path}/store.sqlite');
      await createVersionOneFile(file);

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      await upgraded.customStatement(
        'INSERT INTO customers (id, created_at, updated_at, name) '
        "VALUES ('suki-9', 1, 1, 'Ate Rosa')",
      );
      await upgraded.customStatement(
        'INSERT INTO ledger_entries (id, created_at, updated_at, customer_id, '
        'kind, amount_minor, is_deleted, deleted_at, delete_reason) '
        "VALUES ('entry-1', 2, 2, 'suki-9', 'payment', 500, 1, 3, 'maling halaga')",
      );
      final rows = await upgraded
          .customSelect('SELECT delete_reason, is_deleted FROM ledger_entries')
          .get();
      expect(rows.single.read<String>('delete_reason'), 'maling halaga');
      expect(rows.single.read<int>('is_deleted'), 1);
      final problems = await upgraded
          .customSelect('PRAGMA foreign_key_check')
          .get();
      expect(problems, isEmpty);
    },
  );

  test('an upgraded database accepts the version seven columns', () async {
    final file = File('${tempDirectory.path}/store.sqlite');
    await createVersionOneFile(file);

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.customStatement(
      'UPDATE products SET tracks_stock = 0, expiry_day_serial = 20800 '
      "WHERE id = 'old-product'",
    );
    await upgraded.customStatement(
      "UPDATE sales SET cashier_name = 'Ana' WHERE id = 'old-sale'",
    );
    await upgraded.customStatement(
      "UPDATE store_profiles SET address = 'Brgy. Uno', phone = '0917' "
      "WHERE id = 'store'",
    );
    final product = await upgraded
        .customSelect('SELECT tracks_stock, expiry_day_serial FROM products')
        .getSingle();
    expect(product.read<int>('tracks_stock'), 0);
    expect(product.read<int>('expiry_day_serial'), 20800);
    final sale = await upgraded
        .customSelect('SELECT cashier_name FROM sales')
        .getSingle();
    expect(sale.read<String>('cashier_name'), 'Ana');
    final profile = await upgraded
        .customSelect('SELECT address, phone FROM store_profiles')
        .getSingle();
    expect(profile.read<String>('address'), 'Brgy. Uno');
    final problems = await upgraded
        .customSelect('PRAGMA foreign_key_check')
        .get();
    expect(problems, isEmpty);
    final version = await upgraded.customSelect('PRAGMA user_version').get();
    expect(version.single.data.values.first, 7);
  });
}
