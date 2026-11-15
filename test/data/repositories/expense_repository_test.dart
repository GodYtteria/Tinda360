import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/failures/expense_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/repositories/expense_repository.dart';

import '../../support/sequential_ids.dart';
import '../../support/test_repositories.dart';

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
};

Money _php(int minorUnits) => Money(minorUnits, Currency.php);

void main() {
  late TestRepositories repositories;
  late DateTime currentClockTime;
  late ExpenseRepository expenses;
  final today = LocalDay.fromLocal(DateTime(2026, 11, 17));
  final todayRange = DayRange.single(today);

  setUp(() {
    repositories = TestRepositories();
    currentClockTime = DateTime(2026, 11, 17, 10);
    expenses = ExpenseRepository(
      db: repositories.db,
      clock: Clock(() => currentClockTime),
      ids: SequentialIds(),
      log: repositories.log,
      currency: Currency.php,
    );
  });

  tearDown(() => repositories.close());

  test('addExpense records an entry and watchInRange returns it', () async {
    final expenseId = _ok(
      await expenses.addExpense(
        title: '  Ice for cooler  ',
        amount: _php(5000),
      ),
    );

    final entries = await expenses.watchInRange(todayRange).first;
    expect(entries, hasLength(1));
    expect(
      entries.first,
      ExpenseEntry(
        id: expenseId,
        createdAtMs: currentClockTime.toUtc().millisecondsSinceEpoch,
        daySerial: today.serial,
        title: 'Ice for cooler',
        amount: _php(5000),
      ),
    );
    expect(repositories.log.events, isEmpty);
  });

  test('watchInRange orders newest first and filters by day range', () async {
    currentClockTime = DateTime(2026, 11, 16, 9);
    _ok(
      await expenses.addExpense(title: 'Yesterday gas', amount: _php(10000)),
    );

    currentClockTime = DateTime(2026, 11, 17, 8);
    final morningId = _ok(
      await expenses.addExpense(title: 'Morning ice', amount: _php(3000)),
    );

    currentClockTime = DateTime(2026, 11, 17, 15);
    final afternoonId = _ok(
      await expenses.addExpense(title: 'Afternoon bags', amount: _php(2500)),
    );

    final todayEntries = await expenses.watchInRange(todayRange).first;
    expect(todayEntries.map((entry) => entry.id), [afternoonId, morningId]);

    final twoDayRange = DayRange(today.plusDays(-1), today);
    final twoDayEntries = await expenses.watchInRange(twoDayRange).first;
    expect(twoDayEntries, hasLength(3));
    expect(twoDayEntries.first.id, afternoonId);
    expect(twoDayEntries.last.title, 'Yesterday gas');
  });

  test('addExpense rejects empty title and non-positive amount', () async {
    final emptyTitleResult = await expenses.addExpense(
      title: '   ',
      amount: _php(1000),
    );
    expect(
      emptyTitleResult,
      isA<Err<String, ExpenseFailure>>().having(
        (error) => error.failure,
        'failure',
        isA<ExpenseTitleRequired>(),
      ),
    );

    final zeroAmountResult = await expenses.addExpense(
      title: 'Plastic bags',
      amount: const Money.zero(Currency.php),
    );
    expect(
      zeroAmountResult,
      isA<Err<String, ExpenseFailure>>().having(
        (error) => error.failure,
        'failure',
        isA<ExpenseAmountInvalid>(),
      ),
    );

    final negativeAmountResult = await expenses.addExpense(
      title: 'Plastic bags',
      amount: _php(-500),
    );
    expect(
      negativeAmountResult,
      isA<Err<String, ExpenseFailure>>().having(
        (error) => error.failure,
        'failure',
        isA<ExpenseAmountInvalid>(),
      ),
    );

    expect(await expenses.watchInRange(todayRange).first, isEmpty);
  });

  test('deleteExpense soft-deletes the row and updates watchInRange', () async {
    final firstId = _ok(
      await expenses.addExpense(title: 'Ice', amount: _php(2000)),
    );
    currentClockTime = DateTime(2026, 11, 17, 11);
    final secondId = _ok(
      await expenses.addExpense(title: 'Sacks', amount: _php(4000)),
    );

    final emitted = <List<ExpenseEntry>>[];
    final subscription = expenses.watchInRange(todayRange).listen(emitted.add);
    await pumpEventQueue();
    expect(emitted.last.map((entry) => entry.id), [secondId, firstId]);

    await expenses.deleteExpense(firstId);
    await pumpEventQueue();
    await subscription.cancel();

    expect(emitted.last.map((entry) => entry.id), [secondId]);

    final rawRows = await repositories.db
        .customSelect(
          'SELECT is_deleted FROM expenses WHERE id = ?',
          variables: [Variable.withString(firstId)],
        )
        .get();
    expect(rawRows.single.read<int>('is_deleted'), 1);
  });
}
