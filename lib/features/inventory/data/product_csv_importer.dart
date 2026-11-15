import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

/// Describes a single skipped row during CSV product import.
final class CsvRowError {
  /// Creates a row error.
  const CsvRowError({required this.rowNumber, required this.reason});

  /// 1-based row number in the CSV file (header is row 1).
  final int rowNumber;

  /// Human-readable reason the row was skipped.
  final String reason;
}

/// Summary returned after importing products from a CSV string.
final class CsvImportReport {
  /// Creates an import report.
  const CsvImportReport({
    required this.importedCount,
    required this.skippedCount,
    required this.errors,
  });

  /// Number of products created in the repository.
  final int importedCount;

  /// Number of non-empty data rows that failed validation or creation.
  final int skippedCount;

  /// Details for each skipped row.
  final List<CsvRowError> errors;
}

/// Parses product CSV files and imports valid rows into [ProductRepository].
final class ProductCsvImporter {
  /// Creates a CSV product importer.
  const ProductCsvImporter();

  /// Sample CSV template with expected headers and example sari-sari items.
  static const String sampleCsv =
      'name,price,cost,stock,unit,barcode,low_stock\n'
      'Lucky Me Pancit Canton,15.00,12.00,24,piece,4800016644801,5\n'
      'Kopiko Black 3-in-1,9.00,7.00,40,sachet,,10\n'
      'Rice Sinandomeng,58.00,50.00,25,kilo,,5\n';

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

  /// Parses [csvContent] and inserts valid products into [repository].
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
    final hasHeader = columnMap.containsKey('name') && columnMap.containsKey('price');
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
          };
    final startIndex = hasHeader ? 1 : 0;

    var importedCount = 0;
    final errors = <CsvRowError>[];

    for (var rowIndex = startIndex; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_isRowBlank(row)) continue;

      final rowNumber = rowIndex + 1;
      final draft = _buildDraftFromRow(row, effectiveColumns, currency);
      if (draft == null) {
        errors.add(CsvRowError(rowNumber: rowNumber, reason: 'invalid_row'));
        continue;
      }

      final result = await repository.create(draft);
      switch (result) {
        case Ok():
          importedCount++;
        case Err(:final failure):
          errors.add(
            CsvRowError(rowNumber: rowNumber, reason: failure.runtimeType.toString()),
          );
      }
    }

    return CsvImportReport(
      importedCount: importedCount,
      skippedCount: errors.length,
      errors: errors,
    );
  }

  /// Parses RFC 4180 CSV text into rows of cell strings.
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

  bool _isRowBlank(List<String> row) => row.every((cell) => cell.trim().isEmpty);

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
    final unit = unitText.isEmpty
        ? ProductUnit.piece
        : (_unitAliases[unitText] ?? ProductUnit.piece);

    final stockText = _cell(row, columns['stock']);
    final initialStock = stockText.isEmpty
        ? Quantity.zero
        : _parseQuantity(stockText);
    if (initialStock == null) return null;

    final lowStockText = _cell(row, columns['low_stock']);
    final lowStockAt = lowStockText.isEmpty ? null : _parseQuantity(lowStockText);
    if (lowStockText.isNotEmpty && lowStockAt == null) return null;

    final barcodeText = _cell(row, columns['barcode']);
    return ProductDraft(
      name: name,
      unit: unit,
      price: price,
      cost: cost,
      barcode: barcodeText.isEmpty ? null : barcodeText,
      lowStockAt: lowStockAt,
      initialStock: initialStock,
    );
  }

  String _cell(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  Quantity? _parseQuantity(String rawInput) {
    final parsed = double.tryParse(rawInput.trim());
    if (parsed == null || parsed < 0 || parsed.isNaN || parsed.isInfinite) {
      return null;
    }
    return Quantity.milli((parsed * 1000).round());
  }
}
