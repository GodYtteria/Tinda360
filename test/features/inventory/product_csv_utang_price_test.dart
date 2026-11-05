import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/features/inventory/data/product_csv_importer.dart';

import '../../support/test_repositories.dart';

void main() {
  late TestRepositories repositories;
  const importer = ProductCsvImporter();

  setUp(() => repositories = TestRepositories());
  tearDown(() => repositories.db.close());

  test('imports the optional utang_price column', () async {
    const csv =
        'name,price,cost,stock,unit,barcode,low_stock,utang_price\r\n'
        'Bigas,50,45,10,kilo,,,55\r\n'
        'Asin,10,8,10,piece,,,\r\n';

    final report = await importer.importCsv(
      csvContent: csv,
      repository: repositories.products,
      currency: Currency.php,
    );

    expect(report.importedCount, 2);
    final items = await repositories.products.watchActive().first;
    final bigas = items.firstWhere((item) => item.product.name == 'Bigas');
    final asin = items.firstWhere((item) => item.product.name == 'Asin');
    expect(bigas.product.utangPrice?.minorUnits, 5500);
    expect(asin.product.utangPrice, isNull);
  });

  test(
    'old files without the column still import with no utang price',
    () async {
      const csv =
          'name,price,cost,stock,unit,barcode,low_stock\r\n'
          'Bigas,50,45,10,kilo,,3\r\n';

      final report = await importer.importCsv(
        csvContent: csv,
        repository: repositories.products,
        currency: Currency.php,
      );

      expect(report.importedCount, 1);
      final items = await repositories.products.watchActive().first;
      expect(items.single.product.utangPrice, isNull);
    },
  );

  test('an unreadable utang_price skips the row', () async {
    const csv =
        'name,price,cost,stock,unit,barcode,low_stock,utang_price\r\n'
        'Bigas,50,45,10,kilo,,,abc\r\n';

    final report = await importer.importCsv(
      csvContent: csv,
      repository: repositories.products,
      currency: Currency.php,
    );

    expect(report.importedCount, 0);
    expect(report.skippedCount, 1);
  });
}
