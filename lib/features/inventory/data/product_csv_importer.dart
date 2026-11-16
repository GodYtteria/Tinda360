import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

final class CsvRowError {
  const new({required this.rowNumber, required this.reason});

  final int rowNumber;

  final String reason;
}

final class CsvImportReport {
  const new({
    required this.importedCount,
    required this.skippedCount,
    required this.errors,
    this.priceZeroRows = 0,
  });

  final int priceZeroRows;

  final int importedCount;

  final int skippedCount;

  final List<CsvRowError> errors;
}

final RegExp _formulaGuardPattern = RegExp(r"^'[=+\-@\t\r]");

final class ProductCsvImporter {
  const new();

  static const String sampleCsv =
      'name,price,cost,stock,unit,barcode,low_stock\n'
      'Sample product 1,15.00,12.00,24,piece,,5\n'
      'Sample product 2,9.00,7.00,40,sachet,,10\n'
      'Sample product 3,58.00,50.00,25,kilo,,5\n';

  static const Map<String, String> _headerAliases = <String, String>{
    'name': 'name',
    'pangalan': 'name',
    'product': 'name',
    'item': 'name',
    'price': 'price',
    'presyo': 'price',
    'selling_price': 'price',
    'srp': 'price',
    'cost': 'cost',
    'puhunan': 'cost',
    'cost_price': 'cost',
    'stock': 'stock',
    'qty': 'stock',
    'quantity': 'stock',
    'initial_stock': 'stock',
    'bilang': 'stock',
    'dami': 'stock',
    'unit': 'unit',
    'yunit': 'unit',
    'barcode': 'barcode',
    'sku': 'barcode',
    'code': 'barcode',
    'low_stock': 'low_stock',
    'low_stock_at': 'low_stock',
    'min_stock': 'low_stock',
    'paalala': 'low_stock',
    'utang_price': 'utang_price',
    'presyong_utang': 'utang_price',
    'expiry': 'expiry',
    'expiry_date': 'expiry',
    'expiration': 'expiry',
    'petsa_ng_expire': 'expiry',
    'tracks_stock': 'tracks_stock',
  };

  static const Map<String, ProductUnit> _unitAliases = <String, ProductUnit>{
    'piece': ProductUnit.piece,
    'pieces': ProductUnit.piece,
    'pc': ProductUnit.piece,
    'pcs': ProductUnit.piece,
    'piraso': ProductUnit.piece,
    'pack': ProductUnit.pack,
    'pakete': ProductUnit.pack,
    'sachet': ProductUnit.sachet,
    'can': ProductUnit.can,
    'lata': ProductUnit.can,
    'bottle': ProductUnit.bottle,
    'bote': ProductUnit.bottle,
    'bar': ProductUnit.bar,
    'bag': ProductUnit.bag,
    'supot': ProductUnit.bag,
    'kilo': ProductUnit.kilo,
    'kg': ProductUnit.kilo,
    'liter': ProductUnit.liter,
    'litro': ProductUnit.liter,
    'l': ProductUnit.liter,
  };

  Future<CsvImportReport> importCsv({
    required String csvContent,
    required ProductRepository repository,
    required Currency currency,
  }) async {
    final rows = parseCsvRows(csvContent);
    if (rows.isEmpty) {
      return const CsvImportReport(
        importedCount: 0,
        skippedCount: 0,
        errors: <CsvRowError>[],
      );
    }

    final columnMap = _resolveColumns(rows.first);
    final hasHeader =
        columnMap.containsKey('name') && columnMap.containsKey('price');
    final effectiveColumns = hasHeader
        ? columnMap
        : const <String, int>{
            'name': 0,
            'price': 1,
            'cost': 2,
            'stock': 3,
            'unit': 4,
            'barcode': 5,
            'low_stock': 6,
            'utang_price': 7,
            'expiry': 8,
            'tracks_stock': 9,
          };
    final startIndex = hasHeader ? 1 : 0;

    var importedCount = 0;
    var priceZeroRows = 0;
    final errors = <CsvRowError>[];
    final knownNames = <String>{
      for (final stocked in await repository.watchActive().first)
        _nameKey(stocked.product.name),
    };

    for (var rowIndex = startIndex; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_isRowBlank(row)) continue;

      final rowNumber = rowIndex + 1;
      final draft = _buildDraftFromRow(row, effectiveColumns, currency);
      if (draft == null) {
        errors.add(CsvRowError(rowNumber: rowNumber, reason: 'invalid_row'));
        continue;
      }

      if (!knownNames.add(_nameKey(draft.name))) {
        errors.add(
          CsvRowError(rowNumber: rowNumber, reason: 'duplicate_name'),
        );
        continue;
      }

      final result = await repository.create(draft);
      switch (result) {
        case Ok():
          importedCount++;
          if (draft.price.minorUnits == 0) priceZeroRows++;
        case Err(:final failure):
          errors.add(
            CsvRowError(
              rowNumber: rowNumber,
              reason: failure.runtimeType.toString(),
            ),
          );
      }
    }

    return CsvImportReport(
      importedCount: importedCount,
      skippedCount: errors.length,
      errors: errors,
      priceZeroRows: priceZeroRows,
    );
  }

  String _nameKey(String name) => name.trim().toLowerCase();

  List<List<String>> parseCsvRows(String input) {
    final normalized = input.startsWith('\uFEFF') ? input.substring(1) : input;
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final cellBuffer = StringBuffer();
    var insideQuotes = false;

    for (var index = 0; index < normalized.length; index++) {
      final character = normalized[index];
      if (insideQuotes) {
        if (character == '"') {
          final hasEscapedQuote =
              index + 1 < normalized.length && normalized[index + 1] == '"';
          if (hasEscapedQuote) {
            cellBuffer.write('"');
            index++;
          } else {
            insideQuotes = false;
          }
        } else {
          cellBuffer.write(character);
        }
        continue;
      }

      if (character == '"') {
        insideQuotes = true;
      } else if (character == ',') {
        currentRow.add(cellBuffer.toString());
        cellBuffer.clear();
      } else if (character == '\r' || character == '\n') {
        if (character == '\r' &&
            index + 1 < normalized.length &&
            normalized[index + 1] == '\n') {
          index++;
        }
        currentRow.add(cellBuffer.toString());
        cellBuffer.clear();
        rows.add(currentRow);
        currentRow = <String>[];
      } else {
        cellBuffer.write(character);
      }
    }

    if (cellBuffer.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(cellBuffer.toString());
      rows.add(currentRow);
    }

    return rows;
  }

  Map<String, int> _resolveColumns(List<String> headerRow) {
    final mapping = <String, int>{};
    for (var index = 0; index < headerRow.length; index++) {
      final key = headerRow[index].trim().toLowerCase().replaceAll(' ', '_');
      final canonical = _headerAliases[key];
      if (canonical != null && !mapping.containsKey(canonical)) {
        mapping[canonical] = index;
      }
    }
    return mapping;
  }

  bool _isRowBlank(List<String> row) =>
      row.every((cell) => cell.trim().isEmpty);

  ProductDraft? _buildDraftFromRow(
    List<String> row,
    Map<String, int> columns,
    Currency currency,
  ) {
    final name = _cell(row, columns['name']);
    final priceText = _cell(row, columns['price']);
    if (name.isEmpty || priceText.isEmpty) return null;

    final price = parseMoneyInput(priceText, currency);
    if (price == null) return null;

    final costText = _cell(row, columns['cost']);
    final cost = costText.isEmpty
        ? Money(0, currency)
        : parseMoneyInput(costText, currency);
    if (cost == null) return null;

    final unitText = _cell(row, columns['unit']).toLowerCase();
    final unit = unitText.isEmpty ? ProductUnit.piece : _unitAliases[unitText];
    if (unit == null) return null;

    final stockText = _cell(row, columns['stock']);
    final initialStock = stockText.isEmpty
        ? Quantity.zero
        : _parseQuantity(stockText);
    if (initialStock == null) return null;

    final lowStockText = _cell(row, columns['low_stock']);
    final lowStockAt = lowStockText.isEmpty
        ? null
        : _parseQuantity(lowStockText);
    if (lowStockText.isNotEmpty && lowStockAt == null) return null;

    final utangPriceText = _cell(row, columns['utang_price']);
    final utangPrice = utangPriceText.isEmpty
        ? null
        : parseMoneyInput(utangPriceText, currency);
    if (utangPriceText.isNotEmpty && utangPrice == null) return null;

    final expiryText = _cell(row, columns['expiry']);
    final expiryDay = expiryText.isEmpty
        ? null
        : ExpiryRules.parseIso(expiryText);
    if (expiryText.isNotEmpty && expiryDay == null) return null;

    final tracksStockText = _cell(row, columns['tracks_stock']).toLowerCase();
    final tracksStock = !const {'0', 'false', 'no', 'hindi'}.contains(
      tracksStockText,
    );

    final barcodeText = _cell(row, columns['barcode']);
    return ProductDraft(
      tracksStock: tracksStock,
      utangPrice: utangPrice,
      name: name,
      unit: unit,
      price: price,
      cost: cost,
      barcode: barcodeText.isEmpty ? null : barcodeText,
      lowStockAt: lowStockAt,
      initialStock: initialStock,
      expiryDay: expiryDay,
    );
  }

  String _cell(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return _stripFormulaGuard(row[index].trim());
  }

  String _stripFormulaGuard(String value) =>
      _formulaGuardPattern.hasMatch(value) ? value.substring(1) : value;

  Quantity? _parseQuantity(String rawInput) {
    final parsed = double.tryParse(rawInput.trim());
    if (parsed == null || parsed < 0 || parsed.isNaN || parsed.isInfinite) {
      return null;
    }
    return Quantity.milli((parsed * 1000).round());
  }
}
