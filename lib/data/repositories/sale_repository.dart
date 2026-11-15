import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failures/sale_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/sold_line.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/id_generator.dart';

/// The single write path for sales: one sale, its lines, the stock it takes
/// out, and any utang it creates are written together or not at all.
final class SaleRepository {
  /// Creates the repository.
  SaleRepository({
    required AppDatabase db,
    required Clock clock,
    required IdGenerator ids,
    required AppLog log,
    required Currency currency,
  }) : _db = db,
       _clock = clock,
       _ids = ids,
       _log = log,
       _currency = currency;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;
  final AppLog _log;
  final Currency _currency;

  static const String _soldLinesSql = '''
SELECT s.id AS sale_id, i.qty_milli, i.unit_price_minor, i.unit_cost_minor
FROM sales s
JOIN sale_items i ON i.sale_id = s.id
WHERE s.is_deleted = 0 AND i.is_deleted = 0
  AND s.day_serial BETWEEN ? AND ?
''';

  static const String _topProductsSql = '''
SELECT i.product_id,
       p.name AS product_name,
       p.unit AS product_unit,
       SUM(i.qty_milli) AS total_qty_milli,
       SUM((i.qty_milli * i.unit_price_minor + 500) / 1000) AS total_revenue_minor
FROM sales s
JOIN sale_items i ON i.sale_id = s.id
JOIN products p ON p.id = i.product_id
WHERE s.is_deleted = 0 AND i.is_deleted = 0
  AND s.day_serial BETWEEN ? AND ?
GROUP BY i.product_id
ORDER BY total_revenue_minor DESC, total_qty_milli DESC
LIMIT ?
''';

  /// Records [draft]. Prices are read from the database inside the
  /// transaction, so the cart can never save a stale price.
  ///
  /// Returns the new sale's id.
  @useResult
  Future<Result<String, SaleFailure>> record(SaleDraft draft) async {
    final precheck = _precheck(draft);
    if (precheck != null) return Err(precheck);

    final saleId = _ids.next();
    final now = _clock.now();
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final day = LocalDay.fromLocal(now);

    try {
      await _db.transaction(() async {
        final priced = <_PricedLine>[];
        for (final line in draft.lines) {
          priced.add(await _price(line));
        }
        final total = priced.fold(
          Money.zero(_currency),
          (sum, line) => sum + SaleMath.lineTotal(line.unitPrice, line.quantity),
        );

        final customerId = draft.customerId;
        if (customerId != null) await _requireCustomer(customerId);

        final paid = _paidAtCounter(draft, total);

        await _db.into(_db.sales).insert(
          SalesCompanion.insert(
            id: saleId,
            createdAt: nowMs,
            updatedAt: nowMs,
            method: draft.method.storageName,
            paidMinor: paid.minorUnits,
            daySerial: day.serial,
            customerId: Value(customerId),
            ewalletReference: Value(draft.ewalletReference),
          ),
        );
        for (final line in priced) {
          await _insertLine(saleId, line, nowMs);
        }
        if (draft.method == PaymentMethod.utang &&
            customerId != null &&
            total.isPositive) {
          await _db.into(_db.ledgerEntries).insert(
            LedgerEntriesCompanion.insert(
              id: _ids.next(),
              createdAt: nowMs,
              updatedAt: nowMs,
              customerId: customerId,
              kind: 'debt',
              amountMinor: total.minorUnits,
              saleId: Value(saleId),
            ),
          );
        }
      });
      return Ok(saleId);
    } on _SaleRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('sale.record', error, stack);
      return const Err(SaleStoreUnavailable());
    }
  }

  /// Revenue, cost and sale count for [range], re-emitted on every committed
  /// sale.
  Stream<SalesSummary> watchSummary(DayRange range) => _db
      .customSelect(
        _soldLinesSql,
        variables: [
          Variable.withInt(range.first.serial),
          Variable.withInt(range.last.serial),
        ],
        readsFrom: {_db.sales, _db.saleItems},
      )
      .watch()
      .map(
        (rows) => SaleMath.summarize(
          rows.map(
            (row) => SoldLine(
              saleId: row.read<String>('sale_id'),
              quantity: Quantity.milli(row.read<int>('qty_milli')),
              unitPrice: Money(row.read<int>('unit_price_minor'), _currency),
              unitCost: Money(row.read<int>('unit_cost_minor'), _currency),
            ),
          ),
          _currency,
        ),
      );

  /// Top-selling products for [range] ordered by revenue then quantity.
  Stream<List<TopProduct>> watchTopProducts(DayRange range, {int limit = 3}) =>
      _db
          .customSelect(
            _topProductsSql,
            variables: [
              Variable.withInt(range.first.serial),
              Variable.withInt(range.last.serial),
              Variable.withInt(limit),
            ],
            readsFrom: {_db.sales, _db.saleItems, _db.products},
          )
          .watch()
          .map(
            (rows) => rows.map((row) {
              final rawUnit = row.read<String>('product_unit');
              final unit =
                  ProductUnit.tryParse(rawUnit) ??
                  (throw StateError('Unknown product unit "$rawUnit"'));
              return TopProduct(
                productId: row.read<String>('product_id'),
                productName: row.read<String>('product_name'),
                unit: unit,
                totalQuantity: Quantity.milli(row.read<int>('total_qty_milli')),
                totalRevenue: Money(
                  row.read<int>('total_revenue_minor'),
                  _currency,
                ),
              );
            }).toList(),
          );

  static const String _recentSalesSql = '''
SELECT s.id AS sale_id,
       s.created_at,
       s.method,
       s.paid_minor,
       s.ewallet_reference,
       c.name AS customer_name,
       i.product_id,
       p.name AS product_name,
       p.unit AS product_unit,
       i.qty_milli,
       i.unit_price_minor
FROM sales s
JOIN sale_items i ON i.sale_id = s.id AND i.is_deleted = 0
JOIN products p ON p.id = i.product_id
LEFT JOIN customers c ON c.id = s.customer_id
WHERE s.is_deleted = 0
  AND s.day_serial BETWEEN ? AND ?
ORDER BY s.created_at DESC, s.id DESC
''';

  /// Live list of recent recorded sales inside [range], newest first.
  Stream<List<SaleRecord>> watchRecentSales(
    DayRange range, {
    int limit = 50,
  }) =>
      _db
          .customSelect(
            _recentSalesSql,
            variables: [
              Variable.withInt(range.first.serial),
              Variable.withInt(range.last.serial),
            ],
            readsFrom: {_db.sales, _db.saleItems, _db.products, _db.customers},
          )
          .watch()
          .map((rows) => _groupSaleRecords(rows, limit: limit));

  /// Returns distinct product IDs sold inside [range].
  Future<Set<String>> soldProductIdsInRange(DayRange range) async {
    final rows = await _db
        .customSelect(
          '''
SELECT DISTINCT i.product_id
FROM sales s
JOIN sale_items i ON i.sale_id = s.id AND i.is_deleted = 0
WHERE s.is_deleted = 0
  AND s.day_serial BETWEEN ? AND ?
''',
          variables: [
            Variable.withInt(range.first.serial),
            Variable.withInt(range.last.serial),
          ],
          readsFrom: {_db.sales, _db.saleItems},
        )
        .get();
    return <String>{for (final row in rows) row.read<String>('product_id')};
  }

  /// Voids [saleId], restoring stock movements and reversing any utang debt.
  @useResult
  Future<Result<void, SaleFailure>> voidSale(String saleId) async {
    final nowMs = _clock.now().toUtc().millisecondsSinceEpoch;
    try {
      final updatedCount = await _db.transaction(() async {
        final count = await (_db.update(_db.sales)
              ..where((s) => s.id.equals(saleId) & s.isDeleted.equals(false)))
            .write(
              SalesCompanion(
                isDeleted: const Value(true),
                updatedAt: Value(nowMs),
              ),
            );
        if (count == 0) return 0;

        await (_db.update(_db.saleItems)..where((i) => i.saleId.equals(saleId)))
            .write(
              SaleItemsCompanion(
                isDeleted: const Value(true),
                updatedAt: Value(nowMs),
              ),
            );
        await (_db.update(
          _db.stockMovements,
        )..where((m) => m.saleId.equals(saleId))).write(
          StockMovementsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(nowMs),
          ),
        );
        await (_db.update(
          _db.ledgerEntries,
        )..where((l) => l.saleId.equals(saleId))).write(
          LedgerEntriesCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(nowMs),
          ),
        );
        return count;
      });
      if (updatedCount == 0) return const Err(SaleStoreUnavailable());
      return const Ok(null);
    } on Exception catch (error, stack) {
      _log.error('sale.void', error, stack);
      return const Err(SaleStoreUnavailable());
    }
  }

  List<SaleRecord> _groupSaleRecords(
    List<QueryRow> rows, {
    required int limit,
  }) {
    final grouped = <String, _MutableSale>{};
    for (final row in rows) {
      final saleId = row.read<String>('sale_id');
      var entry = grouped[saleId];
      if (entry == null) {
        if (grouped.length >= limit) continue;
        final rawMethod = row.read<String>('method');
        final method =
            PaymentMethod.tryParse(rawMethod) ?? PaymentMethod.cash;
        entry = _MutableSale(
          id: saleId,
          createdAtMs: row.read<int>('created_at'),
          method: method,
          paid: Money(row.read<int>('paid_minor'), _currency),
          customerName: row.readNullable<String>('customer_name'),
          ewalletReference: row.readNullable<String>('ewallet_reference'),
        );
        grouped[saleId] = entry;
      }

      final rawUnit = row.read<String>('product_unit');
      final unit = ProductUnit.tryParse(rawUnit) ?? ProductUnit.piece;
      final quantity = Quantity.milli(row.read<int>('qty_milli'));
      final unitPrice = Money(row.read<int>('unit_price_minor'), _currency);
      final lineTotal = SaleMath.lineTotal(unitPrice, quantity);
      entry.lines.add(
        SaleRecordLine(
          productId: row.read<String>('product_id'),
          productName: row.read<String>('product_name'),
          unit: unit,
          quantity: quantity,
          unitPrice: unitPrice,
          lineTotal: lineTotal,
        ),
      );
      entry.total = entry.total + lineTotal;
    }

    return [
      for (final sale in grouped.values)
        SaleRecord(
          id: sale.id,
          createdAtMs: sale.createdAtMs,
          method: sale.method,
          paid: sale.paid,
          total: sale.total,
          lines: List<SaleRecordLine>.unmodifiable(sale.lines),
          customerName: sale.customerName,
          ewalletReference: sale.ewalletReference,
        ),
    ];
  }

  SaleFailure? _precheck(SaleDraft draft) {
    if (draft.lines.isEmpty) return const SaleHasNoLines();
    for (final line in draft.lines) {
      if (!line.quantity.isPositive) {
        return SaleQuantityInvalid(line.productId);
      }
    }
    if (draft.method == PaymentMethod.utang && draft.customerId == null) {
      return const SaleCustomerRequired();
    }
    return null;
  }

  Money _paidAtCounter(SaleDraft draft, Money total) {
    switch (draft.method) {
      case PaymentMethod.cash:
        final tendered = draft.cashTendered ?? Money.zero(_currency);
        if (tendered < total) {
          throw _SaleRejected(
            SalePaymentTooLow(total: total, tendered: tendered),
          );
        }
        return total;
      case PaymentMethod.ewallet:
        return total;
      case PaymentMethod.utang:
        return Money.zero(_currency);
    }
  }

  Future<_PricedLine> _price(SaleLineDraft line) async {
    final row =
        await (_db.select(_db.products)..where(
              (p) => p.id.equals(line.productId) & p.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) throw _SaleRejected(SaleProductNotFound(line.productId));

    final unit =
        ProductUnit.tryParse(row.unit) ??
        (throw StateError('Unknown product unit "${row.unit}"'));
    if (!unit.allowsFraction && !line.quantity.isWhole) {
      throw _SaleRejected(SaleQuantityInvalid(line.productId));
    }
    return _PricedLine(
      productId: line.productId,
      quantity: line.quantity,
      unitPrice: Money(row.priceMinor, _currency),
      unitCost: Money(row.costMinor, _currency),
    );
  }

  Future<void> _requireCustomer(String customerId) async {
    final row =
        await (_db.select(_db.customers)..where(
              (c) => c.id.equals(customerId) & c.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) throw _SaleRejected(SaleCustomerNotFound(customerId));
  }

  Future<void> _insertLine(String saleId, _PricedLine line, int nowMs) async {
    await _db.into(_db.saleItems).insert(
      SaleItemsCompanion.insert(
        id: _ids.next(),
        createdAt: nowMs,
        updatedAt: nowMs,
        saleId: saleId,
        productId: line.productId,
        qtyMilli: line.quantity.milli,
        unitPriceMinor: line.unitPrice.minorUnits,
        unitCostMinor: line.unitCost.minorUnits,
      ),
    );
    await _db.into(_db.stockMovements).insert(
      StockMovementsCompanion.insert(
        id: _ids.next(),
        createdAt: nowMs,
        updatedAt: nowMs,
        productId: line.productId,
        qtyDeltaMilli: -line.quantity.milli,
        reason: 'sale',
        saleId: Value(saleId),
      ),
    );
  }
}

final class _PricedLine {
  const _PricedLine({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  final String productId;
  final Quantity quantity;
  final Money unitPrice;
  final Money unitCost;
}

/// Aborts a transaction with a typed failure; caught in the same method.
final class _SaleRejected implements Exception {
  const _SaleRejected(this.failure);

  final SaleFailure failure;
}

final class _MutableSale {
  _MutableSale({
    required this.id,
    required this.createdAtMs,
    required this.method,
    required this.paid,
    required this.customerName,
    required this.ewalletReference,
  }) : total = Money.zero(paid.currency);

  final String id;
  final int createdAtMs;
  final PaymentMethod method;
  final Money paid;
  final String? customerName;
  final String? ewalletReference;
  final List<SaleRecordLine> lines = <SaleRecordLine>[];
  Money total;
}
