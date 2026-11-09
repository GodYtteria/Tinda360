import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failures/sale_return_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/cashier_name.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/core/sales/sale_return_line.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/id_generator.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';

final class SaleReturnOutcome {
  const new({
    required this.refund,
    required this.creditedToUtang,
  });

  final Money refund;
  final Money creditedToUtang;

  Money get cashBack => refund - creditedToUtang;
}

final class SaleReturnRepository {
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

  static const String _returnedQuantitiesSql = '''
SELECT product_id, SUM(qty_milli) AS returned_milli
FROM sale_returns
WHERE sale_id = ? AND is_deleted = 0
GROUP BY product_id
''';

  static const String _outstandingSaleDebtSql = '''
SELECT COALESCE(SUM(CASE kind WHEN 'debt' THEN amount_minor
                              ELSE -amount_minor END), 0) AS outstanding_minor
FROM ledger_entries
WHERE sale_id = ? AND is_deleted = 0 AND kind IN ('debt', 'payment')
''';

  static const String _customerBalanceSql =
      '''
SELECT $customerBalanceSqlForAliasC AS balance_minor
FROM customers c
WHERE c.id = ?
''';

  @useResult
  Future<Result<Money, SaleReturnFailure>> returnItems(
    String saleId,
    List<SaleReturnLine> lines, {
    String? reason,
    String? cashierName,
  }) async {
    final outcome = await returnItemsWithOutcome(
      saleId,
      lines,
      reason: reason,
      cashierName: cashierName,
    );
    return switch (outcome) {
      Ok(:final value) => Ok(value.refund),
      Err(:final failure) => Err(failure),
    };
  }

  @useResult
  Future<Result<SaleReturnOutcome, SaleReturnFailure>> returnItemsWithOutcome(
    String saleId,
    List<SaleReturnLine> lines, {
    String? reason,
    String? cashierName,
  }) async {
    final normalizedCashier = normalizeCashierName(cashierName);
    final requested = <String, Quantity>{};
    for (final line in lines) {
      if (!line.quantity.isPositive) {
        return Err(SaleReturnQuantityInvalid(line.productId));
      }
      requested[line.productId] =
          (requested[line.productId] ?? Quantity.zero) + line.quantity;
    }
    if (requested.isEmpty) return const Err(SaleReturnNothingSelected());

    final nowMs = _clock.now().toUtc().millisecondsSinceEpoch;
    final trimmedReason = reason?.trim();
    try {
      final outcome = await _db.transaction(() async {
        final sale = await (_db.select(
          _db.sales,
        )..where((row) => row.id.equals(saleId))).getSingleOrNull();
        if (sale == null) throw const _ReturnRejected(SaleReturnNotFound());
        if (sale.isDeleted) throw const _ReturnRejected(SaleReturnSaleVoided());

        var total = Money.zero(_currency);
        for (final entry in requested.entries) {
          total += await _returnProduct(
            saleId: saleId,
            productId: entry.key,
            quantity: entry.value,
            reason: (trimmedReason == null || trimmedReason.isEmpty)
                ? null
                : trimmedReason,
            cashierName: normalizedCashier,
            nowMs: nowMs,
          );
        }

        var creditedToUtang = Money.zero(_currency);
        final customerId = sale.customerId;
        if (sale.method == PaymentMethod.utang.storageName &&
            customerId != null &&
            total.isPositive) {
          final saleDebt = await _outstandingSaleDebt(saleId);
          final customerBalance = await _customerBalance(customerId);
          final outstanding = saleDebt < customerBalance
              ? saleDebt
              : customerBalance;
          final credit = total < outstanding ? total : outstanding;
          if (credit.isPositive) {
            creditedToUtang = credit;
            await _db
                .into(_db.ledgerEntries)
                .insert(
                  LedgerEntriesCompanion.insert(
                    id: _ids.next(),
                    createdAt: nowMs,
                    updatedAt: nowMs,
                    customerId: customerId,
                    kind: 'payment',
                    amountMinor: credit.minorUnits,
                    saleId: Value(saleId),
                  ),
                );
          }
        }
        return SaleReturnOutcome(
          refund: total,
          creditedToUtang: creditedToUtang,
        );
      });
      return Ok(outcome);
    } on _ReturnRejected catch (rejection) {
      return Err(rejection.failure);
    } on Object catch (error, stack) {
      _log.error('sale_return.returnItems', error, stack);
      return const Err(SaleReturnStoreUnavailable());
    }
  }

  Stream<Map<String, Quantity>> watchReturnedQuantities(String saleId) => _db
      .customSelect(
        _returnedQuantitiesSql,
        variables: [Variable.withString(saleId)],
        readsFrom: {_db.saleReturns},
      )
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            row.read<String>('product_id'): Quantity.milli(
              row.read<int>('returned_milli'),
            ),
        },
      );

  Future<Money> _returnProduct({
    required String saleId,
    required String productId,
    required Quantity quantity,
    required String? reason,
    required String? cashierName,
    required int nowMs,
  }) async {
    final soldLines =
        await (_db.select(_db.saleItems)
              ..where(
                (item) =>
                    item.saleId.equals(saleId) &
                    item.productId.equals(productId) &
                    item.isDeleted.equals(false),
              )
              ..orderBy([
                (item) => OrderingTerm.asc(item.createdAt),
                (item) => OrderingTerm.asc(item.id),
              ]))
            .get();
    final sold = Quantity.milli(
      soldLines.fold<int>(0, (sum, item) => sum + item.qtyMilli),
    );
    final returnedBefore = await _returnedQuantity(saleId, productId);
    final returnable = sold - returnedBefore;
    if (quantity.compareTo(returnable) > 0) {
      throw _ReturnRejected(
        SaleReturnTooMany(
          productId: productId,
          returnable: returnable.isNegative ? Quantity.zero : returnable,
        ),
      );
    }

    final productRow = await (_db.select(
      _db.products,
    )..where((row) => row.id.equals(productId))).getSingle();
    final unit =
        ProductUnit.tryParse(productRow.unit) ??
        (throw StateError('Unknown product unit "${productRow.unit}"'));
    if (!unit.allowsFraction && !quantity.isWhole) {
      throw _ReturnRejected(SaleReturnQuantityInvalid(productId));
    }

    final refund = _refundFor(soldLines, returnedBefore, quantity);
    await _db
        .into(_db.saleReturns)
        .insert(
          SaleReturnsCompanion.insert(
            id: _ids.next(),
            createdAt: nowMs,
            updatedAt: nowMs,
            saleId: saleId,
            productId: productId,
            qtyMilli: quantity.milli,
            refundMinor: refund.minorUnits,
            reason: Value(reason),
            cashierName: Value(cashierName),
          ),
        );
    if (!productRow.tracksStock) return refund;
    await _db
        .into(_db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            id: _ids.next(),
            createdAt: nowMs,
            updatedAt: nowMs,
            productId: productId,
            qtyDeltaMilli: quantity.milli,
            reason: 'return',
            saleId: Value(saleId),
          ),
        );
    return refund;
  }

  Future<Money> _outstandingSaleDebt(String saleId) async {
    final row = await _db
        .customSelect(
          _outstandingSaleDebtSql,
          variables: [Variable.withString(saleId)],
          readsFrom: {_db.ledgerEntries},
        )
        .getSingle();
    return Money(row.read<int>('outstanding_minor'), _currency);
  }

  Future<Money> _customerBalance(String customerId) async {
    final row = await _db
        .customSelect(
          _customerBalanceSql,
          variables: [Variable.withString(customerId)],
          readsFrom: {_db.customers, _db.ledgerEntries},
        )
        .getSingle();
    return Money(row.read<int>('balance_minor'), _currency);
  }

  Future<Quantity> _returnedQuantity(String saleId, String productId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(qty_milli), 0) AS returned_milli '
          'FROM sale_returns '
          'WHERE sale_id = ? AND product_id = ? AND is_deleted = 0',
          variables: [
            Variable.withString(saleId),
            Variable.withString(productId),
          ],
          readsFrom: {_db.saleReturns},
        )
        .getSingle();
    return Quantity.milli(row.read<int>('returned_milli'));
  }

  Money _refundFor(
    List<SaleItemRow> soldLines,
    Quantity returnedBefore,
    Quantity quantity,
  ) {
    var skipMilli = returnedBefore.milli;
    var remainingMilli = quantity.milli;
    var refund = Money.zero(_currency);
    for (final line in soldLines) {
      if (remainingMilli == 0) break;
      if (skipMilli >= line.qtyMilli) {
        skipMilli -= line.qtyMilli;
        continue;
      }
      final availableMilli = line.qtyMilli - skipMilli;
      final takeMilli = availableMilli < remainingMilli
          ? availableMilli
          : remainingMilli;
      final unitPrice = Money(line.unitPriceMinor, _currency);
      refund +=
          SaleMath.lineTotal(unitPrice, Quantity.milli(skipMilli + takeMilli)) -
          SaleMath.lineTotal(unitPrice, Quantity.milli(skipMilli));
      skipMilli = 0;
      remainingMilli -= takeMilli;
    }
    return refund;
  }
}

final class _ReturnRejected implements Exception {
  const new(this.failure);

  final SaleReturnFailure failure;
}
