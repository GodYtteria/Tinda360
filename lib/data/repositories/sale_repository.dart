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
import 'package:tinda360/core/sales/cashier_name.dart';
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
import 'package:tinda360/data/repositories/cash_count_repository.dart'
    show startOfLocalDayMs;
import 'package:tinda360/data/repositories/customer_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';

final class SaleRepository {
  new({
    required this._db,
    required this._clock,
    required this._ids,
    required this._log,
    required this._currency,
  });

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

  static const String _returnedLinesSql = '''
SELECT r.qty_milli,
       r.refund_minor,
       (SELECT MAX(i.unit_cost_minor) FROM sale_items i
         WHERE i.sale_id = r.sale_id AND i.product_id = r.product_id
           AND i.is_deleted = 0) AS unit_cost_minor
FROM sale_returns r
JOIN sales s ON s.id = r.sale_id
WHERE r.is_deleted = 0 AND s.is_deleted = 0
  AND r.created_at >= ? AND r.created_at < ?
''';

  static const String _returnedByProductSql = '''
SELECT r.sale_id, r.product_id,
       SUM(r.qty_milli) AS returned_milli,
       SUM(r.refund_minor) AS refund_minor
FROM sale_returns r
JOIN sales s ON s.id = r.sale_id
WHERE r.is_deleted = 0 AND s.is_deleted = 0
  AND s.day_serial BETWEEN ? AND ?
GROUP BY r.sale_id, r.product_id
''';

  static const String _topProductsSql = '''
SELECT net.product_id,
       p.name AS product_name,
       p.unit AS product_unit,
       SUM(net.qty_milli) AS total_qty_milli,
       SUM(net.revenue_minor) AS total_revenue_minor
FROM (
  SELECT i.product_id,
         i.qty_milli AS qty_milli,
         (i.qty_milli * i.unit_price_minor + 500) / 1000 AS revenue_minor
  FROM sales s
  JOIN sale_items i ON i.sale_id = s.id
  WHERE s.is_deleted = 0 AND i.is_deleted = 0
    AND s.day_serial BETWEEN ? AND ?
  UNION ALL
  SELECT r.product_id,
         -r.qty_milli AS qty_milli,
         -r.refund_minor AS revenue_minor
  FROM sale_returns r
  JOIN sales s ON s.id = r.sale_id
  WHERE r.is_deleted = 0 AND s.is_deleted = 0
    AND r.created_at >= ? AND r.created_at < ?
) net
JOIN products p ON p.id = net.product_id
GROUP BY net.product_id
HAVING SUM(net.qty_milli) > 0
ORDER BY total_revenue_minor DESC, total_qty_milli DESC
LIMIT ?
''';

  static const String _customerBalanceAfterVoidSql =
      '''
SELECT $customerBalanceSqlForAliasC AS balance_minor
FROM sales s
JOIN customers c ON c.id = s.customer_id
WHERE s.id = ?
''';

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
        final requested = <String, Quantity>{};
        for (final line in draft.lines) {
          final earlier = requested[line.productId] ?? Quantity.zero;
          priced.add(await _price(line, earlierInDraft: earlier));
          requested[line.productId] = earlier + line.quantity;
        }
        final total = priced.fold(
          Money.zero(_currency),
          (sum, line) =>
              sum + SaleMath.lineTotal(line.unitPrice, line.quantity),
        );

        final customerId = draft.customerId;
        if (customerId != null) await _requireCustomer(customerId);

        final paid = _paidAtCounter(draft, total);

        await _db
            .into(_db.sales)
            .insert(
              SalesCompanion.insert(
                id: saleId,
                createdAt: nowMs,
                updatedAt: nowMs,
                method: draft.method.storageName,
                paidMinor: paid.minorUnits,
                tenderedMinor: Value(
                  draft.method == PaymentMethod.cash
                      ? draft.cashTendered?.minorUnits
                      : null,
                ),
                daySerial: day.serial,
                customerId: Value(customerId),
                ewalletReference: Value(draft.ewalletReference),
                cashierName: Value(normalizeCashierName(draft.cashierName)),
              ),
            );
        for (final line in priced) {
          await _insertLine(saleId, line, nowMs);
        }
        final owed = total - paid;
        if (draft.method == PaymentMethod.utang &&
            customerId != null &&
            owed.isPositive) {
          await _db
              .into(_db.ledgerEntries)
              .insert(
                LedgerEntriesCompanion.insert(
                  id: _ids.next(),
                  createdAt: nowMs,
                  updatedAt: nowMs,
                  customerId: customerId,
                  kind: 'debt',
                  amountMinor: owed.minorUnits,
                  saleId: Value(saleId),
                ),
              );
        }
        final interest = draft.interest;
        if (interest != null) {
          if (!owed.isPositive || customerId == null) {
            throw const _SaleRejected(SaleInterestInvalid());
          }
          await _db
              .into(_db.ledgerEntries)
              .insert(
                LedgerEntriesCompanion.insert(
                  id: _ids.next(),
                  createdAt: nowMs,
                  updatedAt: nowMs,
                  customerId: customerId,
                  kind: 'interest',
                  amountMinor: interest.minorUnits,
                  saleId: Value(saleId),
                ),
              );
        }
      });
      return Ok(saleId);
    } on _SaleRejected catch (rejection) {
      return Err(rejection.failure);
    } on Object catch (error, stack) {
      _log.error('sale.record', error, stack);
      return const Err(SaleStoreUnavailable());
    }
  }

  Stream<SalesSummary> watchSummary(DayRange range) => _db
      .customSelect(
        _soldLinesSql,
        variables: [
          Variable.withInt(range.first.serial),
          Variable.withInt(range.last.serial),
        ],
        readsFrom: {_db.sales, _db.saleItems, _db.saleReturns},
      )
      .watch()
      .asyncMap((rows) async {
        final sold = SaleMath.summarize(
          rows.map(
            (row) => SoldLine(
              saleId: row.read<String>('sale_id'),
              quantity: Quantity.milli(row.read<int>('qty_milli')),
              unitPrice: Money(row.read<int>('unit_price_minor'), _currency),
              unitCost: Money(row.read<int>('unit_cost_minor'), _currency),
            ),
          ),
          _currency,
        );
        final returns = await _db
            .customSelect(
              _returnedLinesSql,
              variables: [
                Variable.withInt(startOfLocalDayMs(range.first)),
                Variable.withInt(startOfLocalDayMs(range.last.plusDays(1))),
              ],
              readsFrom: {_db.sales, _db.saleItems, _db.saleReturns},
            )
            .get();
        var refunded = Money.zero(_currency);
        var returnedCost = Money.zero(_currency);
        for (final row in returns) {
          refunded += Money(row.read<int>('refund_minor'), _currency);
          returnedCost += SaleMath.lineTotal(
            Money(row.read<int>('unit_cost_minor'), _currency),
            Quantity.milli(row.read<int>('qty_milli')),
          );
        }
        return SalesSummary(
          revenue: sold.revenue - refunded,
          cost: sold.cost - returnedCost,
          saleCount: sold.saleCount,
        );
      });

  Stream<List<TopProduct>> watchTopProducts(DayRange range, {int limit = 3}) =>
      _db
          .customSelect(
            _topProductsSql,
            variables: [
              Variable.withInt(range.first.serial),
              Variable.withInt(range.last.serial),
              Variable.withInt(startOfLocalDayMs(range.first)),
              Variable.withInt(startOfLocalDayMs(range.last.plusDays(1))),
              Variable.withInt(limit),
            ],
            readsFrom: {
              _db.sales,
              _db.saleItems,
              _db.products,
              _db.saleReturns,
            },
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

  static const String _dayOrderSql = '''
(SELECT COUNT(*) FROM sales earlier
         WHERE earlier.day_serial = s.day_serial
           AND (earlier.created_at < s.created_at
                OR (earlier.created_at = s.created_at
                    AND earlier.id <= s.id)))''';

  static const String _recentSalesSql =
      '''
SELECT s.id AS sale_id,
       s.created_at,
       s.day_serial,
       s.day_order,
       s.method,
       s.paid_minor,
       s.tendered_minor,
       s.ewallet_reference,
       s.cashier_name,
       c.name AS customer_name,
       (SELECT COALESCE(SUM(l.amount_minor), 0) FROM ledger_entries l
         WHERE l.sale_id = s.id AND l.kind = 'interest'
           AND l.is_deleted = 0) AS interest_minor,
       i.product_id,
       p.name AS product_name,
       p.unit AS product_unit,
       i.qty_milli,
       i.unit_price_minor
FROM (
  SELECT s.*, $_dayOrderSql AS day_order
  FROM (
    SELECT * FROM sales
    WHERE is_deleted = 0
      AND day_serial BETWEEN ? AND ?
    ORDER BY created_at DESC, id DESC
    LIMIT ?
  ) s
) s
JOIN sale_items i ON i.sale_id = s.id AND i.is_deleted = 0
JOIN products p ON p.id = i.product_id
LEFT JOIN customers c ON c.id = s.customer_id
ORDER BY s.created_at DESC, s.id DESC
''';

  Stream<List<SaleRecord>> watchRecentSales(
    DayRange range, {
    int? limit = 50,
  }) => _db
      .customSelect(
        _recentSalesSql,
        variables: [
          Variable.withInt(range.first.serial),
          Variable.withInt(range.last.serial),
          Variable.withInt(limit ?? -1),
        ],
        readsFrom: {
          _db.sales,
          _db.saleItems,
          _db.products,
          _db.customers,
          _db.saleReturns,
          _db.ledgerEntries,
        },
      )
      .watch()
      .asyncMap((rows) async {
        final returns = await _db
            .customSelect(
              _returnedByProductSql,
              variables: [
                Variable.withInt(range.first.serial),
                Variable.withInt(range.last.serial),
              ],
              readsFrom: {_db.sales, _db.saleReturns},
            )
            .get();
        return _groupSaleRecords(rows, returns);
      });

  Future<String?> receiptNumberOf(String saleId) async {
    try {
      final row = await _db
          .customSelect(
            '''
SELECT s.day_serial, $_dayOrderSql AS day_order
FROM sales s
WHERE s.id = ?
''',
            variables: [Variable.withString(saleId)],
            readsFrom: {_db.sales},
          )
          .getSingleOrNull();
      if (row == null) return null;
      return SaleMath.receiptNumber(
        daySerial: row.read<int>('day_serial'),
        dayOrder: row.read<int>('day_order'),
      );
    } on Object catch (error, stack) {
      _log.error('sale.receipt_number', error, stack);
      return null;
    }
  }

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

  @useResult
  Future<Result<void, SaleFailure>> voidSale(String saleId) async {
    final nowMs = _clock.now().toUtc().millisecondsSinceEpoch;
    try {
      final updatedCount = await _db.transaction(() async {
        await _rejectIfSaleHasReturns(saleId);
        final count =
            await (_db.update(_db.sales)..where(
                  (sale) =>
                      sale.id.equals(saleId) & sale.isDeleted.equals(false),
                ))
                .write(
                  SalesCompanion(
                    isDeleted: const Value(true),
                    updatedAt: Value(nowMs),
                  ),
                );
        if (count == 0) return 0;

        await (_db.update(
          _db.saleItems,
        )..where((i) => i.saleId.equals(saleId))).write(
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
        await _rejectIfCustomerBalanceNegative(saleId);
        return count;
      });
      if (updatedCount == 0) return const Err(SaleNotFound());
      return const Ok(null);
    } on _SaleRejected catch (rejection) {
      return Err(rejection.failure);
    } on Object catch (error, stack) {
      _log.error('sale.void', error, stack);
      return const Err(SaleStoreUnavailable());
    }
  }

  Future<void> _rejectIfSaleHasReturns(String saleId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS return_count FROM sale_returns '
          'WHERE sale_id = ? AND is_deleted = 0',
          variables: [Variable.withString(saleId)],
          readsFrom: {_db.saleReturns},
        )
        .getSingle();
    if (row.read<int>('return_count') > 0) {
      throw const _SaleRejected(SaleVoidAfterReturn());
    }
  }

  Future<void> _rejectIfCustomerBalanceNegative(String saleId) async {
    final row = await _db
        .customSelect(
          _customerBalanceAfterVoidSql,
          variables: [Variable.withString(saleId)],
          readsFrom: {_db.sales, _db.customers, _db.ledgerEntries},
        )
        .getSingleOrNull();
    if (row == null) return;
    if (row.read<int>('balance_minor') < 0) {
      throw const _SaleRejected(SaleVoidAfterPayment());
    }
  }

  List<SaleRecord> _groupSaleRecords(
    List<QueryRow> rows,
    List<QueryRow> returnRows,
  ) {
    final returnedMilli = <String, int>{};
    final refundedMinor = <String, int>{};
    for (final row in returnRows) {
      final saleId = row.read<String>('sale_id');
      final key = '$saleId|${row.read<String>('product_id')}';
      returnedMilli[key] = row.read<int>('returned_milli');
      refundedMinor[saleId] =
          (refundedMinor[saleId] ?? 0) + row.read<int>('refund_minor');
    }
    final grouped = <String, _MutableSale>{};
    for (final row in rows) {
      final saleId = row.read<String>('sale_id');
      var entry = grouped[saleId];
      if (entry == null) {
        final rawMethod = row.read<String>('method');
        final method = PaymentMethod.tryParse(rawMethod) ?? PaymentMethod.cash;
        entry = _MutableSale(
          id: saleId,
          createdAtMs: row.read<int>('created_at'),
          method: method,
          paid: Money(row.read<int>('paid_minor'), _currency),
          tendered: switch (row.readNullable<int>('tendered_minor')) {
            final int minorUnits => Money(minorUnits, _currency),
            null => null,
          },
          receiptNumber: SaleMath.receiptNumber(
            daySerial: row.read<int>('day_serial'),
            dayOrder: row.read<int>('day_order'),
          ),
          customerName: row.readNullable<String>('customer_name'),
          ewalletReference: row.readNullable<String>('ewallet_reference'),
          interest: Money(row.read<int>('interest_minor'), _currency),
          cashierName: row.readNullable<String>('cashier_name'),
        );
        grouped[saleId] = entry;
      }

      final rawUnit = row.read<String>('product_unit');
      final unit = ProductUnit.tryParse(rawUnit) ?? ProductUnit.piece;
      final quantity = Quantity.milli(row.read<int>('qty_milli'));
      final unitPrice = Money(row.read<int>('unit_price_minor'), _currency);
      final lineTotal = SaleMath.lineTotal(unitPrice, quantity);
      final productId = row.read<String>('product_id');
      final returnKey = '$saleId|$productId';
      final unallocatedMilli = returnedMilli[returnKey] ?? 0;
      final lineReturnedMilli = unallocatedMilli < quantity.milli
          ? unallocatedMilli
          : quantity.milli;
      returnedMilli[returnKey] = unallocatedMilli - lineReturnedMilli;
      entry.lines.add(
        SaleRecordLine(
          productId: productId,
          productName: row.read<String>('product_name'),
          unit: unit,
          quantity: quantity,
          unitPrice: unitPrice,
          lineTotal: lineTotal,
          returnedQuantity: Quantity.milli(lineReturnedMilli),
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
          tendered: sale.tendered,
          total: sale.total,
          lines: List<SaleRecordLine>.unmodifiable(sale.lines),
          receiptNumber: sale.receiptNumber,
          customerName: sale.customerName,
          ewalletReference: sale.ewalletReference,
          refundedAmount: Money(refundedMinor[sale.id] ?? 0, _currency),
          interestAmount: sale.interest,
          cashierName: sale.cashierName,
        ),
    ];
  }

  SaleFailure? _precheck(SaleDraft draft) {
    if (draft.lines.isEmpty) return const SaleHasNoLines();
    for (final line in draft.lines) {
      if (!line.quantity.isPositive) {
        return SaleQuantityInvalid(line.productId);
      }
      final override = line.unitPriceOverride;
      if (override != null && override.isNegative) {
        return SalePriceInvalid(line.productId);
      }
    }
    if (draft.method == PaymentMethod.utang && draft.customerId == null) {
      return const SaleCustomerRequired();
    }
    final interest = draft.interest;
    if (interest != null &&
        (!interest.isPositive ||
            draft.method != PaymentMethod.utang ||
            draft.customerId == null)) {
      return const SaleInterestInvalid();
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
        final paidNow = draft.paidNow ?? Money.zero(_currency);
        if (paidNow.isNegative || paidNow > total) {
          throw _SaleRejected(
            SalePaidNowInvalid(total: total, paidNow: paidNow),
          );
        }
        return paidNow;
    }
  }

  Future<_PricedLine> _price(
    SaleLineDraft line, {
    required Quantity earlierInDraft,
  }) async {
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
    if (row.tracksStock) {
      final stock = await readProductStock(_db, line.productId);
      final remaining = stock - earlierInDraft;
      if (line.quantity.compareTo(remaining) > 0) {
        throw _SaleRejected(
          SaleInsufficientStock(
            productId: line.productId,
            available: remaining.isNegative ? Quantity.zero : remaining,
          ),
        );
      }
    }
    return _PricedLine(
      productId: line.productId,
      tracksStock: row.tracksStock,
      quantity: line.quantity,
      unitPrice: line.unitPriceOverride ?? Money(row.priceMinor, _currency),
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
    await _db
        .into(_db.saleItems)
        .insert(
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
    if (!line.tracksStock) return;
    await _db
        .into(_db.stockMovements)
        .insert(
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
  const new({
    required this.productId,
    required this.tracksStock,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  final String productId;
  final bool tracksStock;
  final Quantity quantity;
  final Money unitPrice;
  final Money unitCost;
}

final class _SaleRejected implements Exception {
  const new(this.failure);

  final SaleFailure failure;
}

final class _MutableSale {
  new({
    required this.id,
    required this.createdAtMs,
    required this.method,
    required this.paid,
    required this.tendered,
    required this.receiptNumber,
    required this.customerName,
    required this.ewalletReference,
    required this.interest,
    required this.cashierName,
  }) : total = Money.zero(paid.currency);

  final String? cashierName;
  final String id;
  final int createdAtMs;
  final PaymentMethod method;
  final Money paid;
  final Money? tendered;
  final String receiptNumber;
  final String? customerName;
  final String? ewalletReference;
  final Money interest;
  final List<SaleRecordLine> lines = <SaleRecordLine>[];
  Money total;
}
