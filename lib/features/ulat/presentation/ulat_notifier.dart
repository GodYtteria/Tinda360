import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/unpaid_utang.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/services/service_providers.dart';

enum ReportPeriod {
  today,

  week,

  month,

  custom,
}

DayRange dayRangeForPeriod(
  ReportPeriod period,
  LocalDay today, {
  DayRange? customRange,
}) => switch (period) {
  ReportPeriod.today => DayRange.single(today),
  ReportPeriod.week => DayRange(today.plusDays(-6), today),
  ReportPeriod.month => DayRange(today.plusDays(-29), today),
  ReportPeriod.custom => customRange ?? DayRange.single(today),
};

@immutable
final class UlatState {
  const new({
    required this.period,
    required this.range,
    required this.summary,
    required this.totalUtang,
    required this.sukiWithUtangCount,
    required this.topProducts,
  });

  final ReportPeriod period;

  final DayRange range;

  final SalesSummary summary;

  final Money totalUtang;

  final int sukiWithUtangCount;

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

final NotifierProvider<UlatPeriodNotifier, ReportPeriod> ulatPeriodProvider =
    NotifierProvider.autoDispose<UlatPeriodNotifier, ReportPeriod>(
      UlatPeriodNotifier.new,
    );

class UlatPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.today;

  void select(ReportPeriod period) {
    state = period;
  }
}

final NotifierProvider<UlatCustomRangeNotifier, DayRange?>
ulatCustomRangeProvider =
    NotifierProvider.autoDispose<UlatCustomRangeNotifier, DayRange?>(
      UlatCustomRangeNotifier.new,
    );

class UlatCustomRangeNotifier extends Notifier<DayRange?> {
  @override
  DayRange? build() => null;

  void choose(DayRange range) {
    state = range;
    ref.read(ulatPeriodProvider.notifier).select(ReportPeriod.custom);
  }
}

final Provider<LocalDay> ulatTodayProvider = Provider.autoDispose<LocalDay>((
  ref,
) {
  final now = ref.watch(clockProvider).now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextMidnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return LocalDay.fromLocal(now);
});

final Provider<DayRange> ulatRangeProvider = Provider.autoDispose<DayRange>((
  ref,
) {
  final period = ref.watch(ulatPeriodProvider);
  final today = ref.watch(ulatTodayProvider);
  final customRange = ref.watch(ulatCustomRangeProvider);
  return dayRangeForPeriod(period, today, customRange: customRange);
});

final StreamNotifierProvider<UlatNotifier, UlatState> ulatNotifierProvider =
    StreamNotifierProvider.autoDispose<UlatNotifier, UlatState>(
      UlatNotifier.new,
    );

class UlatNotifier extends StreamNotifier<UlatState> {
  @override
  Stream<UlatState> build() {
    final period = ref.watch(ulatPeriodProvider);
    final currency = ref.watch(storeCurrencyProvider);
    final range = ref.watch(ulatRangeProvider);

    final saleRepository = ref.watch(saleRepositoryProvider);
    final summaryStream = saleRepository.watchSummary(range);
    final topProductsStream = saleRepository.watchTopProducts(range);
    final balancesStream = ref
        .watch(customerRepositoryProvider)
        .watchBalances();

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
    final totalUtang = totalUnpaidUtang(balances, currency: currency);
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

final StreamProvider<List<SaleRecord>> ulatRecentSalesProvider =
    StreamProvider.autoDispose<List<SaleRecord>>((
      ref,
    ) {
      final range = ref.watch(ulatRangeProvider);
      return ref.watch(saleRepositoryProvider).watchRecentSales(range);
    });

final StreamProvider<List<ExpenseEntry>> ulatExpensesProvider =
    StreamProvider.autoDispose<List<ExpenseEntry>>((
      ref,
    ) {
      final range = ref.watch(ulatRangeProvider);
      return ref.watch(expenseRepositoryProvider).watchInRange(range);
    });
