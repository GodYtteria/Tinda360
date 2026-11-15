import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/id_generator.dart';

/// The single write path for products and their stock.
final class ProductRepository {
  /// Creates the repository.
  ProductRepository({
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

  static const String _activeWithStockSql = '''
SELECT p.id, p.name, p.unit, p.price_minor, p.cost_minor, p.category_id,
       p.barcode, p.low_stock_at_milli,
       COALESCE((SELECT SUM(m.qty_delta_milli) FROM stock_movements m
                 WHERE m.product_id = p.id AND m.is_deleted = 0), 0)
         AS stock_milli
FROM products p
WHERE p.is_deleted = 0
ORDER BY p.name COLLATE NOCASE
''';

  /// Every active product with its current stock, re-emitted on every
  /// committed change to products or stock.
  Stream<List<StockedProduct>> watchActive() => _db
      .customSelect(
        _activeWithStockSql,
        readsFrom: {_db.products, _db.stockMovements},
      )
      .watch()
      .map((rows) => [for (final row in rows) _toStocked(row)]);

  /// Adds a product and, if given, its starting stock, in one transaction.
  @useResult
  Future<Result<String, ProductFailure>> create(ProductDraft draft) async {
    final invalid = _validate(draft) ?? _validateStock(draft.unit, draft.initialStock);
    if (invalid != null) return Err(invalid);

    final id = _ids.next();
    final nowMs = _nowMs();
    try {
      await _db.transaction(() async {
        await _requireBarcodeFree(draft.barcode, exceptId: null);
        await _db.into(_db.products).insert(
          ProductsCompanion.insert(
            id: id,
            createdAt: nowMs,
            updatedAt: nowMs,
            name: draft.name.trim(),
            unit: draft.unit.storageName,
            priceMinor: draft.price.minorUnits,
            costMinor: draft.cost.minorUnits,
            categoryId: Value(draft.categoryId),
            barcode: Value(_cleanBarcode(draft.barcode)),
            lowStockAtMilli: Value(draft.lowStockAt?.milli),
          ),
        );
        if (draft.initialStock.isPositive) {
          await _insertMovement(id, draft.initialStock, 'initial', nowMs);
        }
      });
      return Ok(id);
    } on _ProductRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('product.create', error, stack);
      return const Err(ProductStoreUnavailable());
    }
  }

  /// Saves edits to an existing product. Stock is not changed here.
  @useResult
  Future<Result<void, ProductFailure>> update(
    String productId,
    ProductDraft draft,
  ) async {
    final invalid = _validate(draft);
    if (invalid != null) return Err(invalid);

    try {
      final changed = await _db.transaction(() async {
        await _requireBarcodeFree(draft.barcode, exceptId: productId);
        return _db.customUpdate(
          'UPDATE products SET name = ?, unit = ?, price_minor = ?, '
          'cost_minor = ?, category_id = ?, barcode = ?, '
          'low_stock_at_milli = ?, updated_at = ?, '
          'row_revision = row_revision + 1 '
          'WHERE id = ? AND is_deleted = 0',
          variables: [
            Variable.withString(draft.name.trim()),
            Variable.withString(draft.unit.storageName),
            Variable.withInt(draft.price.minorUnits),
            Variable.withInt(draft.cost.minorUnits),
            Variable<String>(draft.categoryId),
            Variable<String>(_cleanBarcode(draft.barcode)),
            Variable<int>(draft.lowStockAt?.milli),
            Variable.withInt(_nowMs()),
            Variable.withString(productId),
          ],
          updates: {_db.products},
          updateKind: UpdateKind.update,
        );
      });
      if (changed == 0) return Err(ProductNotFound(productId));
      return const Ok(null);
    } on _ProductRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('product.update', error, stack);
      return const Err(ProductStoreUnavailable());
    }
  }

  /// Adds [amount] to a product's stock.
  @useResult
  Future<Result<void, ProductFailure>> restock(
    String productId,
    Quantity amount,
  ) async {
    try {
      await _db.transaction(() async {
        final unit = await _requireActiveUnit(productId);
        final invalid = _validateStock(unit, amount);
        if (invalid != null || !amount.isPositive) {
          throw const _ProductRejected(ProductQuantityInvalid());
        }
        await _insertMovement(productId, amount, 'restock', _nowMs());
      });
      return const Ok(null);
    } on _ProductRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('product.restock', error, stack);
      return const Err(ProductStoreUnavailable());
    }
  }

  /// Corrects stock by [delta] after a physical count (can be negative).
  @useResult
  Future<Result<void, ProductFailure>> adjust(
    String productId,
    Quantity delta,
  ) async {
    if (delta == Quantity.zero) return const Ok(null);
    try {
      await _db.transaction(() async {
        final unit = await _requireActiveUnit(productId);
        if (!unit.allowsFraction && !delta.isWhole) {
          throw const _ProductRejected(ProductQuantityInvalid());
        }
        await _insertMovement(productId, delta, 'adjust', _nowMs());
      });
      return const Ok(null);
    } on _ProductRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('product.adjust', error, stack);
      return const Err(ProductStoreUnavailable());
    }
  }

  /// Records a stock adjustment of [delta] with [reason] in a transaction.
  @useResult
  Future<Result<void, ProductFailure>> adjustStock(
    String productId,
    Quantity delta, {
    String reason = 'adjust',
  }) async {
    if (delta == Quantity.zero) return const Err(ProductQuantityInvalid());
    final movementReason = reason == 'adjustment' ? 'adjust' : reason;
    try {
      await _db.transaction(() async {
        final unit = await _requireActiveUnit(productId);
        if (!unit.allowsFraction && !delta.isWhole) {
          throw const _ProductRejected(ProductQuantityInvalid());
        }
        await _insertMovement(productId, delta, movementReason, _nowMs());
      });
      return const Ok(null);
    } on _ProductRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('product.adjust_stock', error, stack);
      return const Err(ProductStoreUnavailable());
    }
  }

  /// Hides a product. Past sales keep pointing to it.
  @useResult
  Future<Result<void, ProductFailure>> softDelete(String productId) async {
    try {
      final nowMs = _nowMs();
      final changed = await _db.customUpdate(
        'UPDATE products SET is_deleted = 1, deleted_at = ?, updated_at = ?, '
        'row_revision = row_revision + 1 WHERE id = ? AND is_deleted = 0',
        variables: [
          Variable.withInt(nowMs),
          Variable.withInt(nowMs),
          Variable.withString(productId),
        ],
        updates: {_db.products},
        updateKind: UpdateKind.update,
      );
      if (changed == 0) return Err(ProductNotFound(productId));
      return const Ok(null);
    } on Exception catch (error, stack) {
      _log.error('product.soft_delete', error, stack);
      return const Err(ProductStoreUnavailable());
    }
  }

  ProductFailure? _validate(ProductDraft draft) {
    if (draft.name.trim().isEmpty) return const ProductNameRequired();
    if (draft.price.isNegative || draft.cost.isNegative) {
      return const ProductAmountInvalid();
    }
    final lowStockAt = draft.lowStockAt;
    if (lowStockAt != null) return _validateStock(draft.unit, lowStockAt);
    return null;
  }

  ProductFailure? _validateStock(ProductUnit unit, Quantity amount) {
    if (amount.isNegative) return const ProductQuantityInvalid();
    if (!unit.allowsFraction && !amount.isWhole) {
      return const ProductQuantityInvalid();
    }
    return null;
  }

  Future<ProductUnit> _requireActiveUnit(String productId) async {
    final row =
        await (_db.select(_db.products)..where(
              (p) => p.id.equals(productId) & p.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) throw _ProductRejected(ProductNotFound(productId));
    return _parseUnit(row.unit);
  }

  Future<void> _requireBarcodeFree(
    String? barcode, {
    required String? exceptId,
  }) async {
    final cleaned = _cleanBarcode(barcode);
    if (cleaned == null) return;
    final rows = await _db
        .customSelect(
          'SELECT id FROM products '
          'WHERE barcode = ? AND is_deleted = 0 AND id <> ?',
          variables: [
            Variable.withString(cleaned),
            Variable.withString(exceptId ?? ''),
          ],
          readsFrom: {_db.products},
        )
        .get();
    if (rows.isNotEmpty) throw _ProductRejected(ProductBarcodeTaken(cleaned));
  }

  Future<void> _insertMovement(
    String productId,
    Quantity delta,
    String reason,
    int nowMs,
  ) => _db.into(_db.stockMovements).insert(
    StockMovementsCompanion.insert(
      id: _ids.next(),
      createdAt: nowMs,
      updatedAt: nowMs,
      productId: productId,
      qtyDeltaMilli: delta.milli,
      reason: reason,
    ),
  );

  StockedProduct _toStocked(QueryRow row) => StockedProduct(
    product: Product(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      unit: _parseUnit(row.read<String>('unit')),
      price: Money(row.read<int>('price_minor'), _currency),
      cost: Money(row.read<int>('cost_minor'), _currency),
      categoryId: row.readNullable<String>('category_id'),
      barcode: row.readNullable<String>('barcode'),
      lowStockAt: switch (row.readNullable<int>('low_stock_at_milli')) {
        final int milli => Quantity.milli(milli),
        null => null,
      },
    ),
    stock: Quantity.milli(row.read<int>('stock_milli')),
  );

  ProductUnit _parseUnit(String stored) =>
      ProductUnit.tryParse(stored) ??
      (throw StateError('Unknown product unit "$stored"'));

  String? _cleanBarcode(String? barcode) {
    final trimmed = barcode?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  int _nowMs() => _clock.now().toUtc().millisecondsSinceEpoch;
}

/// Aborts a transaction with a typed failure; caught in the same method.
final class _ProductRejected implements Exception {
  const _ProductRejected(this.failure);

  final ProductFailure failure;
}
