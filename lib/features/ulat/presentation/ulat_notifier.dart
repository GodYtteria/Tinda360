import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/services/service_providers.dart';

/// Timeframe selector for the Reports (Ulat) tab.
enum ReportPeriod {
  /// Only today's local calendar day.
  today,

  /// Last 7 local days inclusive.
  week,

  /// Last 30 local days inclusive.
  month,
}

/// Computes the inclusive [DayRange] for [period] ending on [today].
DayRange dayRangeForPeriod(ReportPeriod period, LocalDay today) =>
    switch (period) {
      ReportPeriod.today => DayRange.single(today),
      ReportPeriod.week => DayRange(today.plusDays(-6), today),
      ReportPeriod.month => DayRange(today.plusDays(-29), today),
    };

/// View state for the Reports (Ulat) screen.
final class UlatState {
  /// Creates an immutable report state.
  const UlatState({
    required this.period,
    required this.range,
    required this.summary,
    required this.totalUtang,
    required this.sukiWithUtangCount,
    required this.topProducts,
  });

  /// Selected report period.
  final ReportPeriod period;

  /// Inclusive local day range for [period].
  final DayRange range;

  /// Aggregated sales summary for [range].
  final SalesSummary summary;

  /// Total outstanding utang across all suki.
  final Money totalUtang;

  /// Number of suki with a positive utang balance.
  final int sukiWithUtangCount;

  /// Top-selling products for [range].
  final List<TopProduct> topProducts;

  @override
  bool operator ==(Object other) =>
      other is UlatState &&
      other.period == period &&
      other.range == range &&
      other.summary == summary &&
      other.totalUtang == totalUtang &&
      other.sukiWithUtangCount == sukiWithUtangCount &&
      listEquals(other.topProducts, topProducts);

  @override
  int get hashCode => Object.hash(
    period,
    range,
    summary,
    totalUtang,
    sukiWithUtangCount,
    Object.hashAll(topProducts),
  );
}

/// Holds the currently selected [ReportPeriod].
final ulatPeriodProvider =
    NotifierProvider.autoDispose<UlatPeriodNotifier, ReportPeriod>(
      UlatPeriodNotifier.new,
    );

/// Notifier managing [ReportPeriod] selection.
class UlatPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.today;

  /// Switches the active report period.
  void select(ReportPeriod period) {
    state = period;
  }
}

/// Live report projection combining sales summary and utang balances.
final ulatNotifierProvider =
    StreamNotifierProvider.autoDispose<UlatNotifier, UlatState>(
      UlatNotifier.new,
    );

/// Re-emits whenever the selected period, sales, or utang balances change.
class UlatNotifier extends StreamNotifier<UlatState> {
  @override
  Stream<UlatState> build() {
    final period = ref.watch(ulatPeriodProvider);
    final clock = ref.watch(clockProvider);
    final currency = ref.watch(storeCurrencyProvider);
    final today = LocalDay.fromLocal(clock.now());
    final range = dayRangeForPeriod(period, today);

    final saleRepository = ref.watch(saleRepositoryProvider);
    final summaryStream = saleRepository.watchSummary(range);
    final topProductsStream = saleRepository.watchTopProducts(range);
    final balancesStream = ref.watch(customerRepositoryProvider).watchBalances();

    return _combineStreams(
      period: period,
      range: range,
      currency: currency,
      summaryStream: summaryStream,
      balancesStream: balancesStream,
      topProductsStream: topProductsStream,
    );
  }
}

Stream<UlatState> _combineStreams({
  required ReportPeriod period,
  required DayRange range,
  required Currency currency,
  required Stream<SalesSummary> summaryStream,
  required Stream<List<CustomerBalance>> balancesStream,
  required Stream<List<TopProduct>> topProductsStream,
}) {
  late StreamController<UlatState> controller;
  StreamSubscription<SalesSummary>? summarySubscription;
  StreamSubscription<List<CustomerBalance>>? balancesSubscription;
  StreamSubscription<List<TopProduct>>? topProductsSubscription;

  SalesSummary? latestSummary;
  List<CustomerBalance>? latestBalances;
  List<TopProduct>? latestTopProducts;

  void emitIfReady() {
    final summary = latestSummary;
    final balances = latestBalances;
    final topProducts = latestTopProducts;
    if (summary == null ||
        balances == null ||
        topProducts == null ||
        controller.isClosed) {
      return;
    }
    final totalUtang = balances.fold(
      Money.zero(currency),
      (runningTotal, item) => runningTotal + item.balance,
    );
    final sukiWithUtang = balances.where((item) => item.owes).length;
    controller.add(
      UlatState(
        period: period,
        range: range,
        summary: summary,
        totalUtang: totalUtang,
        sukiWithUtangCount: sukiWithUtang,
        topProducts: topProducts,
      ),
    );
  }

  controller = StreamController<UlatState>(
    onListen: () {
      summarySubscription = summaryStream.listen(
        (summary) {
          latestSummary = summary;
          emitIfReady();
        },
        onError: controller.addError,
      );
      balancesSubscription = balancesStream.listen(
        (balances) {
          latestBalances = balances;
          emitIfReady();
        },
        onError: controller.addError,
      );
      topProductsSubscription = topProductsStream.listen(
        (topProducts) {
          latestTopProducts = topProducts;
          emitIfReady();
        },
        onError: controller.addError,
      );
    },
    onCancel: () => Future.wait<void>([
      if (summarySubscription != null) summarySubscription!.cancel(),
      if (balancesSubscription != null) balancesSubscription!.cancel(),
      if (topProductsSubscription != null) topProductsSubscription!.cancel(),
    ]),
  );

  return controller.stream;
}

/// Live recent sales list for the currently selected [ulatPeriodProvider].
final ulatRecentSalesProvider = StreamProvider.autoDispose<List<SaleRecord>>((
  ref,
) {
  final period = ref.watch(ulatPeriodProvider);
  final today = LocalDay.fromLocal(ref.watch(clockProvider).now());
  final range = dayRangeForPeriod(period, today);
  return ref.watch(saleRepositoryProvider).watchRecentSales(range);
});

/// Live expenses (gastos) list for the currently selected [ulatPeriodProvider].
final ulatExpensesProvider = StreamProvider.autoDispose<List<ExpenseEntry>>((
  ref,
) {
  final period = ref.watch(ulatPeriodProvider);
  final today = LocalDay.fromLocal(ref.watch(clockProvider).now());
  final range = dayRangeForPeriod(period, today);
  return ref.watch(expenseRepositoryProvider).watchInRange(range);
});
