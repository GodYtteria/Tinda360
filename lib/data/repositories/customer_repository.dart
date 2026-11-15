import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/failures/customer_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/id_generator.dart';

/// The single write path for customers and their utang ledger.
final class CustomerRepository {
  /// Creates the repository.
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

  static const String _balanceExpression = '''
COALESCE((SELECT SUM(CASE l.kind WHEN 'debt' THEN l.amount_minor
                                 ELSE -l.amount_minor END)
          FROM ledger_entries l
          WHERE l.customer_id = c.id AND l.is_deleted = 0), 0)
''';

  static const String _balancesSql =
      '''
SELECT c.id, c.name, c.phone, c.credit_limit_minor,
       $_balanceExpression AS balance_minor
FROM customers c
WHERE c.is_deleted = 0
ORDER BY balance_minor DESC, c.name COLLATE NOCASE
''';

  static const String _oneBalanceSql =
      '''
SELECT $_balanceExpression AS balance_minor
FROM customers c
WHERE c.id = ? AND c.is_deleted = 0
''';

  static const String _ledgerSql = '''
SELECT id, created_at, kind, amount_minor, sale_id
FROM ledger_entries
WHERE customer_id = ? AND is_deleted = 0
ORDER BY created_at DESC
''';

  /// Every active customer with their balance, biggest debt first.
  Stream<List<CustomerBalance>> watchBalances() => _db
      .customSelect(
        _balancesSql,
        readsFrom: {_db.customers, _db.ledgerEntries},
      )
      .watch()
      .map((rows) => [for (final row in rows) _toBalance(row)]);

  /// All active ledger entries for [customerId], newest first.
  Stream<List<LedgerRecord>> watchLedger(String customerId) => _db
      .customSelect(
        _ledgerSql,
        variables: [Variable.withString(customerId)],
        readsFrom: {_db.ledgerEntries},
      )
      .watch()
      .map((rows) => [for (final row in rows) _toLedgerRecord(row)]);

  /// Adds a customer.
  @useResult
  Future<Result<String, CustomerFailure>> create(CustomerDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) return const Err(CustomerNameRequired());
    final limit = draft.creditLimit;
    if (limit != null && !limit.isPositive) {
      return const Err(CustomerAmountInvalid());
    }

    final id = _ids.next();
    final nowMs = _nowMs();
    try {
      await _db.into(_db.customers).insert(
        CustomersCompanion.insert(
          id: id,
          createdAt: nowMs,
          updatedAt: nowMs,
          name: name,
          phone: Value(_blankToNull(draft.phone)),
          creditLimitMinor: Value(limit?.minorUnits),
        ),
      );
      return Ok(id);
    } on Exception catch (error, stack) {
      _log.error('customer.create', error, stack);
      return const Err(CustomerStoreUnavailable());
    }
  }

  /// Records a payment of [amount] against the customer's utang.
  ///
  /// A payment larger than the balance is rejected.
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
        final balance = Money(rows.single.read<int>('balance_minor'), _currency);
        if (amount > balance) {
          throw _CustomerRejected(PaymentExceedsBalance(balance));
        }
        final nowMs = _nowMs();
        await _db.into(_db.ledgerEntries).insert(
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

  CustomerBalance _toBalance(QueryRow row) => CustomerBalance(
    customer: Customer(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      phone: row.readNullable<String>('phone'),
      creditLimit: switch (row.readNullable<int>('credit_limit_minor')) {
        final int minor => Money(minor, _currency),
        null => null,
      },
    ),
    balance: Money(row.read<int>('balance_minor'), _currency),
  );

  LedgerRecord _toLedgerRecord(QueryRow row) => LedgerRecord(
    id: row.read<String>('id'),
    createdAtMs: row.read<int>('created_at'),
    kind: row.read<String>('kind'),
    amount: Money(row.read<int>('amount_minor'), _currency),
    saleId: row.readNullable<String>('sale_id'),
  );

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  int _nowMs() => _clock.now().toUtc().millisecondsSinceEpoch;
}

/// Aborts a transaction with a typed failure; caught in the same method.
final class _CustomerRejected implements Exception {
  const _CustomerRejected(this.failure);

  final CustomerFailure failure;
}
