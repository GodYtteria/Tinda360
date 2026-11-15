import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sale_record.dart';

/// Exports [products] to an RFC 4180 CSV string with header
/// `name,price,cost,stock,unit,barcode,low_stock`.
String exportProductsCsv(List<StockedProduct> products) {
  final lines = <String>['name,price,cost,stock,unit,barcode,low_stock'];
  for (final stockedProduct in products) {
    final product = stockedProduct.product;
    final lowStockThreshold = product.lowStockAt;
    final fields = <String>[
      product.name,
      _formatDecimalMoney(product.price),
      _formatDecimalMoney(product.cost),
      _formatDecimalQuantity(stockedProduct.stock),
      product.unit.storageName,
      product.barcode ?? '',
      lowStockThreshold == null ? '' : _formatDecimalQuantity(lowStockThreshold),
    ];
    lines.add(_encodeCsvRow(fields));
  }
  return lines.join('\r\n');
}

/// Exports [sales] to an RFC 4180 CSV string with header
/// `sale_id,created_at_iso,method,customer,total,paid,items`.
String exportSalesCsv(List<SaleRecord> sales) {
  final lines = <String>[
    'sale_id,created_at_iso,method,customer,total,paid,items',
  ];
  for (final sale in sales) {
    final createdAtIso = DateTime.fromMillisecondsSinceEpoch(
      sale.createdAtMs,
      isUtc: true,
    ).toIso8601String();
    final itemsSummary = sale.lines
        .map(
          (line) =>
              '${_formatDecimalQuantity(line.quantity)} ${line.unit.storageName} ${line.productName}',
        )
        .join('; ');
    final fields = <String>[
      sale.id,
      createdAtIso,
      sale.method.storageName,
      sale.customerName ?? '',
      _formatDecimalMoney(sale.total),
      _formatDecimalMoney(sale.paid),
      itemsSummary,
    ];
    lines.add(_encodeCsvRow(fields));
  }
  return lines.join('\r\n');
}

String _encodeCsvRow(List<String> fields) {
  return fields.map(_escapeCsvField).join(',');
}

String _escapeCsvField(String value) {
  final needsQuotes =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\r') ||
      value.contains('\n');
  if (!needsQuotes) {
    return value;
  }
  final escapedQuotes = value.replaceAll('"', '""');
  return '"$escapedQuotes"';
}

String _formatDecimalMoney(Money money) {
  final sign = money.isNegative ? '-' : '';
  final absoluteMinor = money.minorUnits.abs();
  final minorPerMajor = money.currency.minorPerMajor;
  final majorUnits = absoluteMinor ~/ minorPerMajor;
  if (money.currency.exponent == 0) {
    return '$sign$majorUnits';
  }
  final minorUnits = absoluteMinor % minorPerMajor;
  final paddedMinor = minorUnits.toString().padLeft(
    money.currency.exponent,
    '0',
  );
  return '$sign$majorUnits.$paddedMinor';
}

String _formatDecimalQuantity(Quantity quantity) {
  final milli = quantity.milli;
  if (milli % Quantity.milliPerUnit == 0) {
    return (milli ~/ Quantity.milliPerUnit).toString();
  }
  final sign = milli < 0 ? '-' : '';
  final absoluteMilli = milli.abs();
  final wholeUnits = absoluteMilli ~/ Quantity.milliPerUnit;
  final fractionalMilli = absoluteMilli % Quantity.milliPerUnit;
  final paddedFraction = fractionalMilli
      .toString()
      .padLeft(3, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$sign$wholeUnits.$paddedFraction';
}
