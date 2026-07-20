import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/features/inventory/data/product_csv_exporter.dart';

void main() {
  group('exportProductsCsv', () {
    test('returns header only when product list is empty', () {
      final csvOutput = exportProductsCsv(const <StockedProduct>[]);
      expect(csvOutput, 'name,price,cost,stock,unit,barcode,low_stock');
    });

    test('exports products with decimal prices, stock, and optional fields', () {
      final products = <StockedProduct>[
        const StockedProduct(
          product: Product(
            id: 'product-1',
            name: 'Lucky Me Pancit Canton',
            unit: ProductUnit.piece,
            price: Money(1500, Currency.php),
            cost: Money(1200, Currency.php),
            barcode: '4800016644801',
            lowStockAt: Quantity.whole(5),
          ),
          stock: Quantity.whole(24),
        ),
        const StockedProduct(
          product: Product(
            id: 'product-2',
            name: 'Rice Sinandomeng',
            unit: ProductUnit.kilo,
            price: Money(5850, Currency.php),
            cost: Money(5000, Currency.php),
          ),
          stock: Quantity.milli(1250),
        ),
      ];

      final csvOutput = exportProductsCsv(products);

      expect(
        csvOutput,
        'name,price,cost,stock,unit,barcode,low_stock\r\n'
        'Lucky Me Pancit Canton,15.00,12.00,24,piece,4800016644801,5\r\n'
        'Rice Sinandomeng,58.50,50.00,1.25,kilo,,',
      );
    });

    test('escapes commas, double quotes, and newlines per RFC 4180', () {
      final products = <StockedProduct>[
        const StockedProduct(
          product: Product(
            id: 'product-3',
            name: 'Sardines, "Hot" & Spicy\n555',
            unit: ProductUnit.can,
            price: Money(2800, Currency.php),
            cost: Money(2350, Currency.php),
            barcode: '123,456',
          ),
          stock: Quantity.whole(10),
        ),
      ];

      final csvOutput = exportProductsCsv(products);

      expect(
        csvOutput,
        'name,price,cost,stock,unit,barcode,low_stock\r\n'
        '"Sardines, ""Hot"" & Spicy\n555",28.00,23.50,10,can,"123,456",',
      );
    });
  });

  group('exportSalesCsv', () {
    test('returns header only when sales list is empty', () {
      final csvOutput = exportSalesCsv(const <SaleRecord>[]);
      expect(
        csvOutput,
        'sale_id,created_at_iso,method,customer,total,paid,items',
      );
    });

    test('exports sales with ISO timestamp, totals, and escaped fields', () {
      final createdAt = DateTime.utc(2026, 5, 10, 8, 30, 15);
      final sales = <SaleRecord>[
        SaleRecord(
          id: 'sale-1',
          createdAtMs: createdAt.millisecondsSinceEpoch,
          method: PaymentMethod.cash,
          paid: const Money(5000, Currency.php),
          total: const Money(3900, Currency.php),
          lines: const <SaleRecordLine>[
            SaleRecordLine(
              productId: 'product-1',
              productName: 'SkyFlakes',
              unit: ProductUnit.pack,
              quantity: Quantity.whole(2),
              unitPrice: Money(1200, Currency.php),
              lineTotal: Money(2400, Currency.php),
            ),
            SaleRecordLine(
              productId: 'product-2',
              productName: 'Kopiko',
              unit: ProductUnit.sachet,
              quantity: Quantity.whole(1),
              unitPrice: Money(1500, Currency.php),
              lineTotal: Money(1500, Currency.php),
            ),
          ],
        ),
        SaleRecord(
          id: 'sale-2',
          createdAtMs: createdAt.millisecondsSinceEpoch,
          method: PaymentMethod.utang,
          customerName: 'Dela Cruz, "Ate" Maria',
          paid: const Money(0, Currency.php),
          total: const Money(5850, Currency.php),
          lines: const <SaleRecordLine>[
            SaleRecordLine(
              productId: 'product-3',
              productName: 'Rice, "Special"',
              unit: ProductUnit.kilo,
              quantity: Quantity.milli(500),
              unitPrice: Money(11700, Currency.php),
              lineTotal: Money(5850, Currency.php),
            ),
          ],
        ),
      ];

      final csvOutput = exportSalesCsv(sales);

      expect(
        csvOutput,
        'sale_id,created_at_iso,method,customer,total,paid,items\r\n'
        'sale-1,2026-05-10T08:30:15.000Z,cash,,39.00,50.00,2 pack SkyFlakes; 1 sachet Kopiko\r\n'
        'sale-2,2026-05-10T08:30:15.000Z,utang,"Dela Cruz, ""Ate"" Maria",58.50,0.00,"0.5 kilo Rice, ""Special"""',
      );
    });
  });
}
