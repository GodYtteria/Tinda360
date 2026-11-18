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
      expect(
        csvOutput,
        'name,price,cost,stock,unit,barcode,low_stock,utang_price,expiry,tracks_stock',
      );
    });

    test('neutralizes formula-looking names but keeps negative numbers', () {
      final products = <StockedProduct>[
        const StockedProduct(
          product: Product(
            id: 'product-evil',
            name: '=HYPERLINK("http://example.test","click")',
            unit: ProductUnit.piece,
            price: Money(1000, Currency.php),
            cost: Money(800, Currency.php),
            barcode: '@SUM(A1)',
          ),
          stock: Quantity.whole(-3),
        ),
      ];

      final dataRow = exportProductsCsv(products).split('\r\n')[1];

      expect(dataRow, startsWith('"\'=HYPERLINK('));
      expect(dataRow, contains(",-3,"));
      expect(dataRow, contains("'@SUM(A1)"));
    });

    test(
      'exports products with decimal prices, stock, and optional fields',
      () {
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
              utangPrice: Money(1650, Currency.php),
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
          'name,price,cost,stock,unit,barcode,low_stock,utang_price,expiry,tracks_stock\r\n'
          'Lucky Me Pancit Canton,15.00,12.00,24,piece,4800016644801,5,16.50,,1\r\n'
          'Rice Sinandomeng,58.50,50.00,1.25,kilo,,,,,1',
        );
      },
    );

    test('exports tracks_stock 0 for a do-not-count product', () {
      final csvOutput = exportProductsCsv(const <StockedProduct>[
        StockedProduct(
          product: Product(
            id: 'product-4',
            name: 'Load',
            unit: ProductUnit.piece,
            price: Money(1000, Currency.php),
            cost: Money(900, Currency.php),
            tracksStock: false,
          ),
          stock: Quantity.zero,
        ),
      ]);

      expect(csvOutput.split('\r\n')[1], 'Load,10.00,9.00,0,piece,,,,,0');
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
        'name,price,cost,stock,unit,barcode,low_stock,utang_price,expiry,tracks_stock\r\n'
        '"Sardines, ""Hot"" & Spicy\n555",28.00,23.50,10,can,"123,456",,,,1',
      );
    });
  });

  group('exportSalesCsv', () {
    test('returns header only when sales list is empty', () {
      final csvOutput = exportSalesCsv(const <SaleRecord>[]);
      expect(
        csvOutput,
        'sale_id,created_at_iso,method,customer,total,paid,items,interest,refunded,cashier',
      );
    });

    test('exports sales with ISO timestamp, totals, and escaped fields', () {
      final createdAt = DateTime(2026, 5, 10, 8, 30, 15);
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
        'sale_id,created_at_iso,method,customer,total,paid,items,interest,refunded,cashier\r\n'
        'sale-1,2026-05-10T08:30:15.000,cash,,39.00,50.00,2 pack SkyFlakes; 1 sachet Kopiko,0.00,0.00,\r\n'
        'sale-2,2026-05-10T08:30:15.000,utang,"Dela Cruz, ""Ate"" Maria",58.50,0.00,"0.5 kilo Rice, ""Special""",0.00,0.00,',
      );
    });

    test('exports interest, refunded, local time and safe cashier', () {
      final earlyMorning = DateTime(2026, 5, 10, 7, 0, 0);
      final csvOutput = exportSalesCsv(<SaleRecord>[
        SaleRecord(
          id: 'sale-9',
          createdAtMs: earlyMorning.millisecondsSinceEpoch,
          method: PaymentMethod.utang,
          paid: const Money(0, Currency.php),
          total: const Money(10500, Currency.php),
          interestAmount: const Money(500, Currency.php),
          refundedAmount: const Money(1000, Currency.php),
          cashierName: '=CMD()',
          lines: const <SaleRecordLine>[],
        ),
      ]);

      expect(
        csvOutput.split('\r\n')[1],
        "sale-9,2026-05-10T07:00:00.000,utang,,105.00,0.00,,5.00,10.00,'=CMD()",
      );
    });
  });
}
