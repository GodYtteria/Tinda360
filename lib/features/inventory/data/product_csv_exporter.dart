import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sale_record.dart';

String exportProductsCsv(List<StockedProduct> products) {
  final lines = <String>[
    'name,price,cost,stock,unit,barcode,low_stock,utang_price,expiry,tracks_stock',
  ];
  for (final stockedProduct in products) {
    final product = stockedProduct.product;
    final lowStockThreshold = product.lowStockAt;
    final utangPrice = product.utangPrice;
    final expiryDay = product.expiryDay;
    final fields = <String>[
      product.name,
      _formatDecimalMoney(product.price),
      _formatDecimalMoney(product.cost),
      _formatDecimalQuantity(stockedProduct.stock),
      product.unit.storageName,
      product.barcode ?? '',
      if (lowStockThreshold == null)
        ''
      else
        _formatDecimalQuantity(lowStockThreshold),
      if (utangPrice == null) '' else _formatDecimalMoney(utangPrice),
      if (expiryDay == null) '' else ExpiryRules.formatIso(expiryDay),
      if (product.tracksStock) '1' else '0',
    ];
    lines.add(_encodeCsvRow(fields));
  }
  return lines.join('\r\n');
}

String exportSalesCsv(List<SaleRecord> sales) {
  final lines = <String>[
    'sale_id,created_at_iso,method,customer,total,paid,items,interest,refunded,cashier',
  ];
  for (final sale in sales) {
    final createdAtIso = DateTime.fromMillisecondsSinceEpoch(
      sale.createdAtMs,
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
      _formatDecimalMoney(sale.interest),
      _formatDecimalMoney(sale.refunded),
      sale.cashierName ?? '',
    ];
    lines.add(_encodeCsvRow(fields));
  }
  return lines.join('\r\n');
}

String _encodeCsvRow(List<String> fields) {
  return fields.map(_escapeCsvField).join(',');
}

const Set<String> _formulaTriggerCharacters = {'=', '+', '-', '@', '\t', '\r'};

String _neutralizeFormula(String value) {
  if (value.isEmpty || double.tryParse(value) != null) return value;
  return _formulaTriggerCharacters.contains(value[0]) ? "'$value" : value;
}

String _escapeCsvField(String rawValue) {
  final value = _neutralizeFormula(rawValue);
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
