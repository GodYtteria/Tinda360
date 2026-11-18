import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/inventory/data/product_csv_exporter.dart';
import 'package:tinda360/features/inventory/data/product_csv_importer.dart';

import '../../support/test_repositories.dart';

void main() {
  late TestRepositories repositories;

  setUp(() => repositories = TestRepositories());
  tearDown(() async => repositories.db.close());

  test('imports expiry column and skips a row with a bad date', () async {
    const csv =
        'name,price,cost,stock,unit,barcode,low_stock,utang_price,expiry\r\n'
        'Gatas,20,15,5,piece,,,,2027-03-09\r\n'
        'Sabon,10,8,5,piece,,,,2027-13-40\r\n'
        'Asin,5,3,5,piece,,,,\r\n';
    final report = await const ProductCsvImporter().importCsv(
      csvContent: csv,
      repository: repositories.products,
      currency: Currency.php,
    );
    expect(report.importedCount, 2);
    expect(report.errors.single.rowNumber, 3);
    final products = await repositories.products.watchActive().first;
    final byName = {for (final item in products) item.product.name: item};
    expect(
      ExpiryRules.formatIso(byName['Gatas']!.product.expiryDay!),
      '2027-03-09',
    );
    expect(byName['Asin']!.product.expiryDay, isNull);
  });

  test('old files without expiry column still import', () async {
    final report = await const ProductCsvImporter().importCsv(
      csvContent: 'name,price\r\nTinapay,12\r\n',
      repository: repositories.products,
      currency: Currency.php,
    );
    expect(report.importedCount, 1);
  });

  test('export appends expiry as YYYY-MM-DD', () {
    final day = ExpiryRules.parseIso('2027-03-09')!;
    final csv = exportProductsCsv([
      StockedProduct(
        product: Product(
          id: 'p',
          name: 'Gatas',
          unit: ProductUnit.piece,
          price: const Money(2000, Currency.php),
          cost: const Money(1500, Currency.php),
          expiryDay: day,
        ),
        stock: const Quantity.whole(1),
      ),
    ]);
    expect(csv.split('\r\n').first, endsWith(',expiry,tracks_stock'));
    expect(csv.split('\r\n').last, endsWith(',2027-03-09,1'));
  });
}
