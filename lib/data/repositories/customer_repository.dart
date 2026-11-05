import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/customers/interest_rate.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/customers/utang_breakdown.dart';
import 'package:tinda360/core/failures/customer_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/cashier_name.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/id_generator.dart';

const String customerBalanceSqlForAliasC = '''
COALESCE((SELECT SUM(CASE WHEN l.kind IN ('debt', 'interest') THEN l.amount_minor
                                 ELSE -l.amount_minor END)
          FROM ledger_entries l
          WHERE l.customer_id = c.id AND l.is_deleted = 0), 0)
''';

LedgerRecord ledgerRecordFromRow(QueryRow row, Currency currency) =>
    LedgerRecord(
      id: row.read<String>('id'),
      createdAtMs: row.read<int>('created_at'),
      kind: row.read<String>('kind'),
      amount: Money(row.read<int>('amount_minor'), currency),
      saleId: row.readNullable<String>('sale_id'),
      isDeleted: row.read<int>('is_deleted') == 1,
      deleteReason: row.readNullable<String>('delete_reason'),
      deletedAtMs: row.readNullable<int>('deleted_at'),
      deletedByName: row.readNullable<String>('deleted_by_name'),
    );

final class CustomerRepository {
  CustomerRepository({
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

  static const String _balancesSql =
      '''
SELECT c.id, c.name, c.phone, c.credit_limit_minor, c.interest_percent_tenths,
       $customerBalanceSqlForAliasC AS balance_minor
FROM customers c
WHERE c.is_deleted = 0
ORDER BY balance_minor DESC, c.name COLLATE NOCASE
''';

  static const String _allLedgerSql = '''
SELECT l.id, l.created_at, l.kind, l.amount_minor, l.sale_id, l.customer_id,
       l.is_deleted, l.deleted_at, l.delete_reason,
       l.deleted_by_name
FROM ledger_entries l
JOIN customers c ON c.id = l.customer_id
WHERE l.is_deleted = 0 AND c.is_deleted = 0
  AND l.customer_id IN (
    SELECT customer_id FROM ledger_entries
    WHERE kind = 'interest' AND is_deleted = 0
  )
''';

  static const String _oneBalanceSql =
      '''
SELECT $customerBalanceSqlForAliasC AS balance_minor
FROM customers c
WHERE c.id = ? AND c.is_deleted = 0
''';

  static const String _interestContextSql =
      '''
SELECT c.interest_percent_tenths,
       $customerBalanceSqlForAliasC AS balance_minor
FROM customers c
WHERE c.id = ? AND c.is_deleted = 0
''';

  static const String _ledgerSql = '''
SELECT id, created_at, kind, amount_minor, sale_id,
       is_deleted, deleted_at, delete_reason, deleted_by_name
FROM ledger_entries
WHERE customer_id = ? AND (is_deleted = 0 OR sale_id IS NULL)
ORDER BY created_at DESC, id DESC
''';

  static const String _activeLedgerSql = '''
SELECT id, created_at, kind, amount_minor, sale_id,
       is_deleted, deleted_at, delete_reason, deleted_by_name
FROM ledger_entries
WHERE customer_id = ? AND is_deleted = 0
ORDER BY created_at DESC
''';

  static const String _ledgerEntryLookupSql = '''
SELECT l.id, l.customer_id, l.kind, l.amount_minor, l.sale_id, l.is_deleted,
       (SELECT SUM(CASE WHEN x.kind IN ('debt', 'interest') THEN x.amount_minor
                        ELSE -x.amount_minor END)
        FROM ledger_entries x
        WHERE x.customer_id = l.customer_id AND x.is_deleted = 0) AS balance_minor
FROM ledger_entries l
WHERE l.id = ?
''';

  static const int maxDeleteReasonLength = 120;

  Stream<List<CustomerBalance>> watchBalances() => _db
      .customSelect(
        _balancesSql,
        readsFrom: {_db.customers, _db.ledgerEntries},
      )
      .watch()
      .asyncMap(_withInterestBreakdown);

  Future<List<CustomerBalance>> _withInterestBreakdown(
    List<QueryRow> balanceRows,
  ) async {
    final ledgerRows = await _db
        .customSelect(_allLedgerSql, readsFrom: {_db.ledgerEntries})
        .get();
    final entriesByCustomer = <String, List<LedgerRecord>>{};
    for (final row in ledgerRows) {
      entriesByCustomer
          .putIfAbsent(row.read<String>('customer_id'), () => [])
          .add(_toLedgerRecord(row));
    }
    return [
      for (final row in balanceRows)
        _toBalance(
          row,
          computeUtangBreakdown(
            entriesByCustomer[row.read<String>('id')] ?? const [],
            _currency,
          ).interest,
        ),
    ];
  }

  Stream<List<LedgerRecord>> watchLedger(String customerId) => _db
      .customSelect(
        _ledgerSql,
        variables: [Variable.withString(customerId)],
        readsFrom: {_db.ledgerEntries},
      )
      .watch()
      .map((rows) => [for (final row in rows) _toLedgerRecord(row)]);

  @useResult
  Future<Result<String, CustomerFailure>> create(CustomerDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) return const Err(CustomerNameRequired());
    final limit = draft.creditLimit;
    if (limit != null && !limit.isPositive) {
      return const Err(CustomerAmountInvalid());
    }
    if (!_isValidRate(draft.interestPercentTenths)) {
      return const Err(CustomerAmountInvalid());
    }

    final id = _ids.next();
    final nowMs = _nowMs();
    try {
      await _db
          .into(_db.customers)
          .insert(
            CustomersCompanion.insert(
              id: id,
              createdAt: nowMs,
              updatedAt: nowMs,
              name: name,
              phone: Value(_blankToNull(draft.phone)),
              creditLimitMinor: Value(limit?.minorUnits),
              interestPercentTenths: Value(draft.interestPercentTenths),
            ),
          );
      return Ok(id);
    } on Exception catch (error, stack) {
      _log.error('customer.create', error, stack);
      return const Err(CustomerStoreUnavailable());
    }
  }

  @useResult
  Future<Result<void, CustomerFailure>> update(
    String customerId,
    CustomerDraft draft,
  ) async {
    final name = draft.name.trim();
    if (name.isEmpty) return const Err(CustomerNameRequired());
    final limit = draft.creditLimit;
    if (limit != null && !limit.isPositive) {
      return const Err(CustomerAmountInvalid());
    }
    if (!_isValidRate(draft.interestPercentTenths)) {
      return const Err(CustomerAmountInvalid());
    }
    try {
      final changed = await _db.customUpdate(
        'UPDATE customers SET name = ?, phone = ?, credit_limit_minor = ?, '
        'interest_percent_tenths = ?, '
        'updated_at = ?, row_revision = row_revision + 1 '
        'WHERE id = ? AND is_deleted = 0',
        variables: [
          Variable.withString(name),
          Variable<String>(_blankToNull(draft.phone)),
          Variable<int>(limit?.minorUnits),
          Variable<int>(draft.interestPercentTenths),
          Variable.withInt(_nowMs()),
          Variable.withString(customerId),
        ],
        updates: {_db.customers},
        updateKind: UpdateKind.update,
      );
      if (changed == 0) return Err(CustomerNotFound(customerId));
      return const Ok(null);
    } on Exception catch (error, stack) {
      _log.error('customer.update', error, stack);
      return const Err(CustomerStoreUnavailable());
    }
  }

  @useResult
  Future<Result<void, CustomerFailure>> softDelete(String customerId) async {
    try {
      await _db.transaction(() async {
        final rows = await _db
            .customSelect(
              _oneBalanceSql,
              variables: [Variable.withString(customerId)],
              readsFrom: {_db.customers, _db.ledgerEntries},
            )
            .get();
        if (rows.isEmpty) {
          throw _CustomerRejected(CustomerNotFound(customerId));
        }
        final balance = Money(
          rows.single.read<int>('balance_minor'),
          _currency,
        );
        if (balance != Money(0, _currency)) {
          throw _CustomerRejected(CustomerHasBalance(balance));
        }
        final nowMs = _nowMs();
        await _db.customUpdate(
          'UPDATE customers SET is_deleted = 1, deleted_at = ?, '
          'updated_at = ?, row_revision = row_revision + 1 '
          'WHERE id = ? AND is_deleted = 0',
          variables: [
            Variable.withInt(nowMs),
            Variable.withInt(nowMs),
            Variable.withString(customerId),
          ],
          updates: {_db.customers},
          updateKind: UpdateKind.update,
        );
      });
      return const Ok(null);
    } on _CustomerRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('customer.soft_delete', error, stack);
      return const Err(CustomerStoreUnavailable());
    }
  }

  @useResult
  Future<Result<void, CustomerFailure>> recordPayment(
    String customerId,
    Money amount,
  ) async {
    if (!amount.isPositive) return const Err(CustomerAmountInvalid());
    try {
      await _db.transaction(() async {
        final rows = await _db
            .customSelect(
              _oneBalanceSql,
              variables: [Variable.withString(customerId)],
              readsFrom: {_db.customers, _db.ledgerEntries},
            )
            .get();
        if (rows.isEmpty) {
          throw _CustomerRejected(CustomerNotFound(customerId));
        }
        final balance = Money(
          rows.single.read<int>('balance_minor'),
          _currency,
        );
        if (amount > balance) {
          throw _CustomerRejected(PaymentExceedsBalance(balance));
        }
        final nowMs = _nowMs();
        await _db
            .into(_db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: _ids.next(),
                createdAt: nowMs,
                updatedAt: nowMs,
                customerId: customerId,
                kind: 'payment',
                amountMinor: amount.minorUnits,
              ),
            );
      });
      return const Ok(null);
    } on _CustomerRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('customer.record_payment', error, stack);
      return const Err(CustomerStoreUnavailable());
    }
  }

  @useResult
  Future<Result<Money, CustomerFailure>> addInterest(
    String customerId,
    Money expectedAmount,
  ) async {
    try {
      late final Money interest;
      await _db.transaction(() async {
        final rows = await _db
            .customSelect(
              _interestContextSql,
              variables: [Variable.withString(customerId)],
              readsFrom: {_db.customers, _db.ledgerEntries},
            )
            .get();
        if (rows.isEmpty) {
          throw _CustomerRejected(CustomerNotFound(customerId));
        }
        final rateTenths = rows.single.readNullable<int>(
          'interest_percent_tenths',
        );
        if (rateTenths == null) {
          throw const _CustomerRejected(InterestRateNotSet());
        }
        final ledgerRows = await _db
            .customSelect(
              _activeLedgerSql,
              variables: [Variable.withString(customerId)],
              readsFrom: {_db.ledgerEntries},
            )
            .get();
        final utang = computeUtangBreakdown(
          [for (final row in ledgerRows) _toLedgerRecord(row)],
          _currency,
        ).utang;
        if (!utang.isPositive) {
          throw const _CustomerRejected(InterestNoBalance());
        }
        interest = computeInterest(utang, rateTenths);
        if (!interest.isPositive) {
          throw const _CustomerRejected(InterestNoBalance());
        }
        if (interest != expectedAmount) {
          throw _CustomerRejected(InterestAmountChanged(interest));
        }
        final nowMs = _nowMs();
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
              ),
            );
      });
      return Ok(interest);
    } on _CustomerRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('customer.add_interest', error, stack);
      return const Err(CustomerStoreUnavailable());
    }
  }

  @useResult
  Future<Result<void, CustomerFailure>> deleteLedgerEntry(
    String entryId, {
    String? reason,
    String? deletedByName,
  }) async {
    final storedDeletedBy = normalizeCashierName(deletedByName);
    final trimmedReason = _blankToNull(reason);
    final storedReason =
        trimmedReason != null && trimmedReason.length > maxDeleteReasonLength
        ? trimmedReason.substring(0, maxDeleteReasonLength).trimRight()
        : trimmedReason;
    try {
      await _db.transaction(() async {
        final rows = await _db
            .customSelect(
              _ledgerEntryLookupSql,
              variables: [Variable.withString(entryId)],
              readsFrom: {_db.ledgerEntries},
            )
            .get();
        if (rows.isEmpty) throw _CustomerRejected(LedgerEntryNotFound(entryId));
        final row = rows.single;
        if (row.read<int>('is_deleted') == 1) {
          throw _CustomerRejected(LedgerEntryAlreadyDeleted(entryId));
        }
        final kind = row.read<String>('kind');
        final isManualKind = kind == 'payment' || kind == 'interest';
        if (!isManualKind || row.readNullable<String>('sale_id') != null) {
          throw _CustomerRejected(LedgerEntryNotDeletable(entryId));
        }
        if (kind == 'interest') {
          final balance = Money(row.read<int>('balance_minor'), _currency);
          final amount = Money(row.read<int>('amount_minor'), _currency);
          if (balance - amount < Money(0, _currency)) {
            throw _CustomerRejected(LedgerDeleteWouldGoNegative(balance));
          }
        }
        final nowMs = _nowMs();
        final changed = await _db.customUpdate(
          'UPDATE ledger_entries SET is_deleted = 1, deleted_at = ?, '
          'delete_reason = ?, deleted_by_name = ?, updated_at = ?, '
          'row_revision = row_revision + 1 '
          'WHERE id = ? AND is_deleted = 0',
          variables: [
            Variable.withInt(nowMs),
            Variable<String>(storedReason),
            Variable<String>(storedDeletedBy),
            Variable.withInt(nowMs),
            Variable.withString(entryId),
          ],
          updates: {_db.ledgerEntries},
          updateKind: UpdateKind.update,
        );
        if (changed == 0) {
          throw _CustomerRejected(LedgerEntryAlreadyDeleted(entryId));
        }
      });
      return const Ok(null);
    } on _CustomerRejected catch (rejection) {
      return Err(rejection.failure);
    } on Exception catch (error, stack) {
      _log.error('customer.delete_ledger_entry', error, stack);
      return const Err(CustomerStoreUnavailable());
    }
  }

  bool _isValidRate(int? tenths) =>
      tenths == null || isValidInterestPercentTenths(tenths);

  CustomerBalance _toBalance(QueryRow row, Money outstandingInterest) =>
      CustomerBalance(
        customer: Customer(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          phone: row.readNullable<String>('phone'),
          creditLimit: switch (row.readNullable<int>('credit_limit_minor')) {
            final int minor => Money(minor, _currency),
            null => null,
          },
          interestPercentTenths: row.readNullable<int>(
            'interest_percent_tenths',
          ),
        ),
        balance: Money(row.read<int>('balance_minor'), _currency),
        outstandingInterestOrNull: outstandingInterest,
      );

  LedgerRecord _toLedgerRecord(QueryRow row) =>
      ledgerRecordFromRow(row, _currency);

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  int _nowMs() => _clock.now().toUtc().millisecondsSinceEpoch;
}

final class _CustomerRejected implements Exception {
  const _CustomerRejected(this.failure);

  final CustomerFailure failure;
}
