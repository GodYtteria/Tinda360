import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/features/inventory/data/product_csv_importer.dart';

import '../../support/test_repositories.dart';

void main() {
  late TestRepositories repositories;
  const importer = ProductCsvImporter();

  setUp(() {
    repositories = TestRepositories();
  });

  tearDown(() async {
    await repositories.db.close();
  });

  test(
    'imports valid CSV rows with headers, quotes, BOM, and fractional stock',
    () async {
      const csv =
          '\uFEFF'
          'name,price,cost,stock,unit,barcode,low_stock\r\n'
          '"Pancit Canton, Original",15.50,12.00,24,piece,4800016644801,5\r\n'
          'Sinandomeng Rice,58,50,12.5,kilo,,3\r\n'
          '"Soap ""Silka"" Bar",35.00,,10,bar,,2\r\n';

      final report = await importer.importCsv(
        csvContent: csv,
        repository: repositories.products,
        currency: Currency.php,
      );

      expect(report.importedCount, 3);
      expect(report.skippedCount, 0);
      expect(report.errors, isEmpty);

      final items = await repositories.products.watchActive().first;
      expect(items.length, 3);

      final canton = items.firstWhere(
        (item) => item.product.name == 'Pancit Canton, Original',
      );
      expect(canton.product.price.minorUnits, 1550);
      expect(canton.product.cost.minorUnits, 1200);
      expect(canton.stock.milli, 24000);
      expect(canton.product.barcode, '4800016644801');

      final rice = items.firstWhere(
        (item) => item.product.name == 'Sinandomeng Rice',
      );
      expect(rice.product.unit, ProductUnit.kilo);
      expect(rice.stock.milli, 12500);
    },
  );

  test(
    'supports Filipino header aliases and skips invalid or duplicate rows',
    () async {
      const csv =
          'pangalan,presyo,puhunan,dami,yunit,barcode\n'
          'Kape 3-in-1,9.00,7.00,20,sachet,111222333\n'
          ',10.00,5.00,5,piraso,\n'
          'Bad Price,abc,5.00,5,piece,\n'
          'Duplicate Barcode,12.00,8.00,4,piece,111222333\n';

      final report = await importer.importCsv(
        csvContent: csv,
        repository: repositories.products,
        currency: Currency.php,
      );

      expect(report.importedCount, 1);
      expect(report.skippedCount, 3);
      expect(report.errors.map((error) => error.rowNumber), [3, 4, 5]);
    },
  );

  test('rejects rows with an unknown unit instead of guessing piece', () async {
    const csv =
        'name,price,cost,stock,unit\n'
        'Itlog,8.00,6.00,30,dozen\n'
        'Asukal,60.00,50.00,2.5,kilo\n';

    final report = await importer.importCsv(
      csvContent: csv,
      repository: repositories.products,
      currency: Currency.php,
    );

    expect(report.importedCount, 1);
    expect(report.errors.map((error) => error.rowNumber), [2]);
  });

  test(
    'round-trips a formula-looking name through export and import',
    () async {
      const csv =
          'name,price,cost,stock,unit\n'
          "'=Cola,20.00,15.00,5,piece\n";

      final report = await importer.importCsv(
        csvContent: csv,
        repository: repositories.products,
        currency: Currency.php,
      );

      expect(report.importedCount, 1);
      final products = await repositories.products.watchActive().first;
      expect(products.single.product.name, '=Cola');
    },
  );

  test('tracks_stock 0 imports an untracked product without stock', () async {
    const csv =
        'name,price,cost,stock,unit,tracks_stock\n'
        'Load,10,9,5,piece,0\n'
        'Rice,50,40,5,kilo,\n';

    final report = await importer.importCsv(
      csvContent: csv,
      repository: repositories.products,
      currency: Currency.php,
    );

    expect(report.importedCount, 2);
    final items = await repositories.products.watchActive().first;
    final load = items.firstWhere((item) => item.product.name == 'Load');
    final rice = items.firstWhere((item) => item.product.name == 'Rice');
    expect(load.product.tracksStock, isFalse);
    expect(load.stock.milli, 0);
    expect(rice.product.tracksStock, isTrue);
    expect(rice.stock.milli, 5000);
  });

  test(
    'skips duplicate names in file and existing, counts zero price',
    () async {
      const first = 'name,price,cost,stock,unit\nCola,20,15,5,piece\n';
      await importer.importCsv(
        csvContent: first,
        repository: repositories.products,
        currency: Currency.php,
      );

      const csv =
          'name,price,cost,stock,unit\n'
          ' cola ,20,15,5,piece\n'
          'Soap,0,0,5,bar\n'
          'SOAP,10,5,5,bar\n';
      final report = await importer.importCsv(
        csvContent: csv,
        repository: repositories.products,
        currency: Currency.php,
      );

      expect(report.importedCount, 1);
      expect(report.skippedCount, 2);
      expect(report.errors.map((error) => error.rowNumber), [2, 4]);
      expect(report.priceZeroRows, 1);
    },
  );

  test('returns empty report for empty CSV', () async {
    final report = await importer.importCsv(
      csvContent: '   \n  ',
      repository: repositories.products,
      currency: Currency.php,
    );

    expect(report.importedCount, 0);
    expect(report.skippedCount, 0);
  });
}
