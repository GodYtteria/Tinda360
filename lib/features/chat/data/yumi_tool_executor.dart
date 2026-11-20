import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/customers/unpaid_utang.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';
import 'package:tinda360/data/repositories/expense_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';
import 'package:tinda360/data/repositories/store_profile_repository.dart';
import 'package:tinda360/data/repositories/utang_age_repository.dart';

final class YumiToolExecutor {
  new({
    required AppDatabase db,
    required ProductRepository products,
    required SaleRepository sales,
    required CustomerRepository customers,
    required ExpenseRepository expenses,
    required StoreProfileRepository storeProfile,
    required Clock clock,
    required Currency currency,
  }) : _db = db,
       _products = products,
       _sales = sales,
       _customers = customers,
       _expenses = expenses,
       _storeProfile = storeProfile,
       _clock = clock,
       _currency = currency;

  final AppDatabase _db;
  final ProductRepository _products;
  final SaleRepository _sales;
  final CustomerRepository _customers;
  final ExpenseRepository _expenses;
  final StoreProfileRepository _storeProfile;
  final Clock _clock;
  final Currency _currency;

  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'get_sales_summary':
        return _salesSummary(_timeframe(args));
      case 'get_top_products':
        return _topProducts(_timeframe(args), _intArg(args, 'limit', 5));
      case 'get_product_info':
        return _productInfo(_strArg(args, 'product_name'));
      case 'get_low_stock':
        final threshold = args['threshold'];
        return _lowStock(threshold is num ? threshold.toInt() : null);
      case 'get_stock_forecast':
        return _stockForecast(_strArg(args, 'product_name'));
      case 'get_utang_list':
        return _utangList(_numArg(args, 'min_balance', 0));
      case 'get_utang_risk':
        return _utangRisk(_intArg(args, 'days_overdue', 30));
      case 'get_expenses':
        return _getExpenses(_timeframe(args));
      case 'get_expiry_alerts':
        return _expiryAlerts(_intArg(args, 'days_ahead', 7));
      case 'get_slow_moving':
        return _slowMoving(_intArg(args, 'days', 14));
      case 'get_profit_margins':
        return _profitMargins(
          _strArg(args, 'sort', fallback: 'highest'),
          _intArg(args, 'limit', 10),
        );
      case 'get_sales_compare':
        return _salesCompare(_strArg(args, 'period', fallback: 'day'));
      case 'get_sales_trend':
        return _salesTrend(_intArg(args, 'days', 7));
      case 'get_busiest_hours':
        return _busiestHours(_timeframe(args, fallback: 'week'));
      case 'get_suki_loyalty':
        return _sukiLoyalty(
          _strArg(args, 'sort_by', fallback: 'spend'),
          _intArg(args, 'limit', 10),
        );
      case 'get_payment_breakdown':
        return _paymentBreakdown(_timeframe(args, fallback: 'today'));
      case 'get_store_info':
        return _storeInfo();
      case 'get_product_count':
        return _productCount();
      case 'get_restock_suggestions':
        return _restockSuggestions(
          _numArg(args, 'budget', 0),
          _intArg(args, 'limit', 10),
        );
      case 'get_overview':
        return _overview();
      default:
        return <String, dynamic>{'error': 'unknown_tool', 'tool': name};
    }
  }

  LocalDay get _today => LocalDay.fromLocal(_clock.now());

  DayRange _rangeFor(String timeframe) {
    final today = _today;
    switch (timeframe) {
      case 'week':
        return DayRange(today.plusDays(-6), today);
      case 'month':
        return DayRange(today.plusDays(-29), today);
      case 'today':
      default:
        return DayRange.single(today);
    }
  }

  String _timeframe(Map<String, dynamic> args, {String fallback = 'today'}) {
    final raw = args['timeframe'];
    if (raw == 'week' || raw == 'month' || raw == 'today') return raw as String;
    return fallback;
  }

  String _strArg(
    Map<String, dynamic> args,
    String key, {
    String fallback = '',
  }) {
    final value = args[key];
    if (value is String) return value;
    return fallback;
  }

  int _intArg(Map<String, dynamic> args, String key, int fallback) {
    final value = args[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  num _numArg(Map<String, dynamic> args, String key, num fallback) {
    final value = args[key];
    if (value is num) return value;
    return fallback;
  }

  int _startOfLocalDayMs(LocalDay day) {
    final local = day.toLocalDate();
    return DateTime(
      local.year,
      local.month,
      local.day,
    ).toUtc().millisecondsSinceEpoch;
  }

  String _isoDate(LocalDay day) {
    final date = day.toLocalDate();
    final month = date.month.toString().padLeft(2, '0');
    final dayOfMonth = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$dayOfMonth';
  }

  Map<String, dynamic> _summaryJson(SalesSummary summary) => <String, dynamic>{
    'revenue_minor': summary.revenue.minorUnits,
    'cost_minor': summary.cost.minorUnits,
    'profit_minor': summary.profit.minorUnits,
    'sale_count': summary.saleCount,
  };

  StockedProduct? _findProductByName(
    List<StockedProduct> products,
    String query,
  ) {
    final needle = query.toLowerCase().trim();
    if (needle.length < _minProductMatchLength) return null;
    for (final item in products) {
      if (item.product.name.toLowerCase().trim() == needle) return item;
    }
    StockedProduct? best;
    var bestLength = 0;
    for (final item in products) {
      final name = item.product.name.toLowerCase().trim();
      if (name.length < _minProductMatchLength) continue;
      final matches =
          _containsWord(name, needle) || _containsWord(needle, name);
      if (matches && name.length > bestLength) {
        best = item;
        bestLength = name.length;
      }
    }
    return best;
  }

  static const int _minProductMatchLength = 3;

  static bool _containsWord(String haystack, String word) => RegExp(
    '(^|[^\\p{L}\\p{N}])${RegExp.escape(word)}(\$|[^\\p{L}\\p{N}])',
    unicode: true,
  ).hasMatch(haystack);

  Future<Map<String, dynamic>> _salesSummary(String timeframe) async {
    final range = _rangeFor(timeframe);
    final summary = await _sales.watchSummary(range).first;
    final itemsSoldMilli = await _queryItemsSoldMilli(range);
    return <String, dynamic>{
      'timeframe': timeframe,
      'start_day_serial': range.first.serial,
      'end_day_serial': range.last.serial,
      ..._summaryJson(summary),
      'items_sold_milli': itemsSoldMilli,
    };
  }

  Future<int> _queryItemsSoldMilli(DayRange range) async {
    final soldRows = await _db
        .customSelect(
          '''
SELECT COALESCE(SUM(i.qty_milli), 0) AS sold_milli
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
        .getSingle();
    final returnRows = await _db
        .customSelect(
          '''
SELECT COALESCE(SUM(r.qty_milli), 0) AS returned_milli
FROM sale_returns r
JOIN sales s ON s.id = r.sale_id
WHERE r.is_deleted = 0 AND s.is_deleted = 0
  AND r.created_at >= ? AND r.created_at < ?
''',
          variables: [
            Variable.withInt(_startOfLocalDayMs(range.first)),
            Variable.withInt(_startOfLocalDayMs(range.last.plusDays(1))),
          ],
          readsFrom: {_db.saleReturns, _db.sales},
        )
        .getSingle();
    final sold = soldRows.read<int>('sold_milli');
    final returned = returnRows.read<int>('returned_milli');
    final net = sold - returned;
    return net < 0 ? 0 : net;
  }

  Future<Map<String, int>> _netSoldMilliByProduct(DayRange range) async {
    final sold = await _sales.soldProductQuantitiesInRange(range);
    final returnRows = await _db
        .customSelect(
          '''
SELECT r.product_id, SUM(r.qty_milli) AS returned_milli
FROM sale_returns r
JOIN sales s ON s.id = r.sale_id
WHERE r.is_deleted = 0 AND s.is_deleted = 0
  AND r.created_at >= ? AND r.created_at < ?
GROUP BY r.product_id
''',
          variables: [
            Variable.withInt(_startOfLocalDayMs(range.first)),
            Variable.withInt(_startOfLocalDayMs(range.last.plusDays(1))),
          ],
          readsFrom: {_db.saleReturns, _db.sales},
        )
        .get();
    final net = <String, int>{...sold};
    for (final row in returnRows) {
      final productId = row.read<String>('product_id');
      final remaining = (net[productId] ?? 0) - row.read<int>('returned_milli');
      net[productId] = remaining < 0 ? 0 : remaining;
    }
    return net;
  }

  Future<Map<String, dynamic>> _topProducts(String timeframe, int limit) async {
    final range = _rangeFor(timeframe);
    final safeLimit = limit <= 0 ? 5 : limit;
    final products = await _sales
        .watchTopProducts(range, limit: safeLimit)
        .first;
    return <String, dynamic>{
      'timeframe': timeframe,
      'start_day_serial': range.first.serial,
      'end_day_serial': range.last.serial,
      'limit': safeLimit,
      'products': products
          .map(
            (TopProduct product) => <String, dynamic>{
              'product_id': product.productId,
              'product_name': product.productName,
              'unit': product.unit.storageName,
              'total_qty_milli': product.totalQuantity.milli,
              'total_revenue_minor': product.totalRevenue.minorUnits,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _productInfo(String productName) async {
    final products = await _products.watchActive().first;
    final match = _findProductByName(products, productName);
    if (match == null) {
      return <String, dynamic>{
        'found': false,
        'query': productName,
        'error': 'not_found',
      };
    }
    final product = match.product;
    return <String, dynamic>{
      'found': true,
      'product': <String, dynamic>{
        'id': product.id,
        'name': product.name,
        'unit': product.unit.storageName,
        'price_minor': product.price.minorUnits,
        'cost_minor': product.cost.minorUnits,
        'category_id': product.categoryId,
        'barcode': product.barcode,
        'low_stock_at_milli': product.lowStockAt?.milli,
        'utang_price_minor': product.utangPrice?.minorUnits,
        'tracks_stock': product.tracksStock,
        'expiry_day_serial': product.expiryDay?.serial,
        'expiry_date': product.expiryDay == null
            ? null
            : _isoDate(product.expiryDay!),
        'stock_milli': match.stock.milli,
      },
    };
  }

  Future<Map<String, dynamic>> _lowStock(int? thresholdUnits) async {
    final products = await _products.watchActive().first;
    final thresholdMilli = thresholdUnits == null
        ? null
        : thresholdUnits * Quantity.milliPerUnit;
    final items = products.where((item) {
      if (!item.product.tracksStock) return false;
      final limit = thresholdMilli ?? item.product.lowStockAt?.milli;
      return limit != null && item.stock.milli <= limit;
    }).toList();
    return <String, dynamic>{
      'threshold_units': thresholdUnits,
      'count': items.length,
      'items': items
          .map(
            (item) => <String, dynamic>{
              'product_id': item.product.id,
              'name': item.product.name,
              'unit': item.product.unit.storageName,
              'stock_milli': item.stock.milli,
              'low_stock_at_milli': item.product.lowStockAt?.milli,
              'tracks_stock': item.product.tracksStock,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _stockForecast(String productName) async {
    final products = await _products.watchActive().first;
    final match = _findProductByName(products, productName);
    if (match == null) {
      return <String, dynamic>{
        'found': false,
        'query': productName,
        'error': 'not_found',
      };
    }
    if (!match.product.tracksStock) {
      return <String, dynamic>{
        'found': true,
        'product_id': match.product.id,
        'product_name': match.product.name,
        'tracks_stock': false,
      };
    }
    const windowDays = 14;
    final today = _today;
    final range = DayRange(today.plusDays(-(windowDays - 1)), today);
    final soldById = await _netSoldMilliByProduct(range);
    final soldMilli = soldById[match.product.id] ?? 0;
    final currentMilli = match.stock.milli;
    final avgDailyUnits = soldMilli / (windowDays * Quantity.milliPerUnit);
    final daysRemaining = avgDailyUnits > 0
        ? currentMilli / (avgDailyUnits * Quantity.milliPerUnit)
        : null;
    return <String, dynamic>{
      'found': true,
      'product_id': match.product.id,
      'product_name': match.product.name,
      'tracks_stock': true,
      'unit': match.product.unit.storageName,
      'current_stock_milli': currentMilli,
      'window_days': windowDays,
      'sold_qty_milli_window': soldMilli,
      'avg_daily_sales_units': double.parse(avgDailyUnits.toStringAsFixed(4)),
      'days_remaining': daysRemaining == null
          ? null
          : double.parse(daysRemaining.toStringAsFixed(4)),
    };
  }

  Future<Map<String, dynamic>> _utangList(num minBalance) async {
    final balances = await _customers.watchBalances().first;
    final minMinor = (minBalance * _currency.minorPerMajor).round();
    final filtered = balances
        .where((entry) => entry.owes && entry.balance.minorUnits >= minMinor)
        .toList();
    final totalMinor = filtered.fold<int>(
      0,
      (sum, entry) => sum + entry.balance.minorUnits,
    );
    return <String, dynamic>{
      'min_balance_minor': minMinor,
      'count': filtered.length,
      'total_balance_minor': totalMinor,
      'customers': filtered
          .map(
            (entry) => <String, dynamic>{
              'customer_id': entry.customer.id,
              'name': entry.customer.name,
              'phone': entry.customer.phone,
              'credit_limit_minor': entry.customer.creditLimit?.minorUnits,
              'interest_percent_tenths': entry.customer.interestPercentTenths,
              'balance_minor': entry.balance.minorUnits,
              'outstanding_utang_minor': entry.outstandingUtang.minorUnits,
              'outstanding_interest_minor':
                  entry.outstandingInterest.minorUnits,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _utangRisk(int daysOverdue) async {
    final balances = await _customers.watchBalances().first;
    final ageRepo = UtangAgeRepository(db: _db, currency: _currency);
    final ledgerByCustomer = await ageRepo.loadLedgerByCustomer();
    final now = _clock.now();
    final highRisk = <Map<String, dynamic>>[];
    var totalAtRisk = 0;
    for (final entry in balances) {
      final ledger =
          ledgerByCustomer[entry.customer.id] ?? const <LedgerRecord>[];
      final ageDays = oldestOutstandingDebtAgeDays(ledger, now);
      if (ageDays == null || ageDays < daysOverdue) continue;
      highRisk.add(<String, dynamic>{
        'customer_id': entry.customer.id,
        'name': entry.customer.name,
        'balance_minor': entry.balance.minorUnits,
        'outstanding_utang_minor': entry.outstandingUtang.minorUnits,
        'outstanding_interest_minor': entry.outstandingInterest.minorUnits,
        'oldest_debt_age_days': ageDays,
        'is_overdue': ageDays >= utangOverdueDays,
      });
      totalAtRisk += entry.balance.minorUnits;
    }
    highRisk.sort(
      (first, second) => (second['oldest_debt_age_days'] as int).compareTo(
        first['oldest_debt_age_days'] as int,
      ),
    );
    return <String, dynamic>{
      'days_overdue': daysOverdue,
      'count': highRisk.length,
      'total_at_risk_minor': totalAtRisk,
      'high_risk': highRisk,
    };
  }

  Future<Map<String, dynamic>> _getExpenses(String timeframe) async {
    final range = _rangeFor(timeframe);
    final expenses = await _expenses.watchInRange(range).first;
    final totalMinor = expenses.fold<int>(
      0,
      (total, expense) => total + expense.amount.minorUnits,
    );
    return <String, dynamic>{
      'timeframe': timeframe,
      'start_day_serial': range.first.serial,
      'end_day_serial': range.last.serial,
      'total_minor': totalMinor,
      'count': expenses.length,
      'expenses': expenses
          .map(
            (expense) => <String, dynamic>{
              'id': expense.id,
              'created_at_ms': expense.createdAtMs,
              'day_serial': expense.daySerial,
              'title': expense.title,
              'amount_minor': expense.amount.minorUnits,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _expiryAlerts(int daysAhead) async {
    final today = _today;
    final products = await _products.watchActive().first;
    final expiringSoon = <Map<String, dynamic>>[];
    final alreadyExpired = <Map<String, dynamic>>[];
    for (final item in products) {
      final expiryDay = item.product.expiryDay;
      if (expiryDay == null) continue;
      final daysLeft = expiryDay.serial - today.serial;
      final status = ExpiryRules.statusFor(expiryDay, today);
      if (status is ExpiryExpired) {
        alreadyExpired.add(<String, dynamic>{
          'product_id': item.product.id,
          'name': item.product.name,
          'expiry_date': _isoDate(expiryDay),
          'days_left': daysLeft,
          'stock_milli': item.stock.milli,
          'unit': item.product.unit.storageName,
        });
      } else if (daysLeft >= 0 && daysLeft <= daysAhead) {
        expiringSoon.add(<String, dynamic>{
          'product_id': item.product.id,
          'name': item.product.name,
          'expiry_date': _isoDate(expiryDay),
          'days_left': daysLeft,
          'stock_milli': item.stock.milli,
          'unit': item.product.unit.storageName,
        });
      }
    }
    expiringSoon.sort(
      (first, second) =>
          (first['days_left'] as int).compareTo(second['days_left'] as int),
    );
    alreadyExpired.sort(
      (first, second) =>
          (first['days_left'] as int).compareTo(second['days_left'] as int),
    );
    return <String, dynamic>{
      'as_of_day_serial': today.serial,
      'days_ahead': daysAhead,
      'expiring_soon': expiringSoon,
      'already_expired': alreadyExpired,
    };
  }

  Future<Map<String, dynamic>> _slowMoving(int days) async {
    final today = _today;
    final window = days <= 0 ? 14 : days;
    final range = DayRange(today.plusDays(-(window - 1)), today);
    final products = await _products.watchActive().first;
    final soldQty = await _netSoldMilliByProduct(range);
    final items = <Map<String, dynamic>>[];
    for (final item in products) {
      final sold = soldQty[item.product.id] ?? 0;
      if (sold == 0 && item.stock.isPositive) {
        items.add(<String, dynamic>{
          'product_id': item.product.id,
          'name': item.product.name,
          'unit': item.product.unit.storageName,
          'stock_milli': item.stock.milli,
          'sold_qty_milli_window': 0,
          'last_sold_day_serial': null,
        });
      }
    }
    return <String, dynamic>{
      'days': window,
      'count': items.length,
      'items': items,
    };
  }

  Future<Map<String, dynamic>> _profitMargins(String sort, int limit) async {
    final products = await _products.watchActive().first;
    final entries = products.map((item) {
      final price = item.product.price.minorUnits;
      final cost = item.product.cost.minorUnits;
      final marginMinor = price - cost;
      final marginPct = price == 0 ? 0.0 : (marginMinor / price) * 100.0;
      return <String, dynamic>{
        'product_id': item.product.id,
        'name': item.product.name,
        'unit': item.product.unit.storageName,
        'price_minor': price,
        'cost_minor': cost,
        'margin_minor': marginMinor,
        'margin_pct': double.parse(marginPct.toStringAsFixed(2)),
      };
    }).toList();
    entries.sort((first, second) {
      final firstMargin = first['margin_pct'] as double;
      final secondMargin = second['margin_pct'] as double;
      return sort == 'lowest'
          ? firstMargin.compareTo(secondMargin)
          : secondMargin.compareTo(firstMargin);
    });
    final safeLimit = limit <= 0 ? 10 : limit;
    final limited = entries.take(safeLimit).toList();
    return <String, dynamic>{
      'sort': sort == 'lowest' ? 'lowest' : 'highest',
      'limit': safeLimit,
      'count': limited.length,
      'products': limited,
    };
  }

  Future<Map<String, dynamic>> _salesCompare(String period) async {
    final today = _today;
    final normalizedPeriod = switch (period) {
      'week' => 'week',
      'month' => 'month',
      _ => 'day',
    };
    late DayRange currentRange;
    late DayRange previousRange;
    switch (normalizedPeriod) {
      case 'week':
        currentRange = DayRange(today.plusDays(-6), today);
        previousRange = DayRange(today.plusDays(-13), today.plusDays(-7));
      case 'month':
        currentRange = DayRange(today.plusDays(-29), today);
        previousRange = DayRange(today.plusDays(-59), today.plusDays(-30));
      case 'day':
      default:
        currentRange = DayRange.single(today);
        previousRange = DayRange.single(today.plusDays(-1));
    }
    final current = await _sales.watchSummary(currentRange).first;
    final previous = await _sales.watchSummary(previousRange).first;
    Map<String, dynamic> rangeJson(DayRange r, SalesSummary s) =>
        <String, dynamic>{
          'start_day_serial': r.first.serial,
          'end_day_serial': r.last.serial,
          ..._summaryJson(s),
        };
    return <String, dynamic>{
      'period': normalizedPeriod,
      'current': rangeJson(currentRange, current),
      'previous': rangeJson(previousRange, previous),
      'delta': <String, dynamic>{
        'revenue_minor':
            current.revenue.minorUnits - previous.revenue.minorUnits,
        'cost_minor': current.cost.minorUnits - previous.cost.minorUnits,
        'profit_minor': current.profit.minorUnits - previous.profit.minorUnits,
        'sale_count': current.saleCount - previous.saleCount,
      },
    };
  }

  static const int _maxTrendDays = 90;

  Future<Map<String, dynamic>> _salesTrend(int days) async {
    final window = days <= 0 ? 7 : days.clamp(1, _maxTrendDays);
    final today = _today;
    final series = <Map<String, dynamic>>[];
    for (var i = window - 1; i >= 0; i--) {
      final day = today.plusDays(-i);
      final summary = await _sales.watchSummary(DayRange.single(day)).first;
      series.add(<String, dynamic>{
        'day_serial': day.serial,
        'date': _isoDate(day),
        ..._summaryJson(summary),
      });
    }
    return <String, dynamic>{
      'days': window,
      'series': series,
    };
  }

  Future<Map<String, dynamic>> _busiestHours(String timeframe) async {
    final range = _rangeFor(timeframe);
    final sales = await _sales.watchRecentSales(range, limit: null).first;
    final buckets = <int, Map<String, int>>{};
    for (final sale in sales) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        sale.createdAtMs,
        isUtc: true,
      ).toLocal();
      final hour = dt.hour;
      final bucket = buckets.putIfAbsent(hour, () => {'count': 0, 'amount': 0});
      bucket['count'] = bucket['count']! + 1;
      bucket['amount'] = bucket['amount']! + sale.netTotal.minorUnits;
    }
    final hours =
        buckets.entries
            .map(
              (bucket) => <String, dynamic>{
                'hour': bucket.key,
                'transaction_count': bucket.value['count'],
                'revenue_minor': bucket.value['amount'],
              },
            )
            .toList()
          ..sort(
            (first, second) => (second['transaction_count'] as int).compareTo(
              first['transaction_count'] as int,
            ),
          );
    return <String, dynamic>{
      'timeframe': timeframe,
      'start_day_serial': range.first.serial,
      'end_day_serial': range.last.serial,
      'hours': hours,
    };
  }

  Future<Map<String, dynamic>> _sukiLoyalty(String sortBy, int limit) async {
    final range = _rangeFor('month');
    final sales = await _sales.watchRecentSales(range, limit: null).first;
    final agg = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      final name = sale.customerName?.trim();
      if (name == null || name.isEmpty) continue;
      final entry = agg.putIfAbsent(
        name,
        () => {'customer_name': name, 'total_spend_minor': 0, 'visits': 0},
      );
      entry['total_spend_minor'] =
          (entry['total_spend_minor'] as int) + sale.netTotal.minorUnits;
      entry['visits'] = (entry['visits'] as int) + 1;
    }
    final list = agg.values.toList();
    list.sort((first, second) {
      if (sortBy == 'visits') {
        return (second['visits'] as int).compareTo(first['visits'] as int);
      }
      return (second['total_spend_minor'] as int).compareTo(
        first['total_spend_minor'] as int,
      );
    });
    final safeLimit = limit <= 0 ? 10 : limit;
    final limited = list.take(safeLimit).toList();
    return <String, dynamic>{
      'sort_by': sortBy == 'visits' ? 'visits' : 'spend',
      'limit': safeLimit,
      'start_day_serial': range.first.serial,
      'end_day_serial': range.last.serial,
      'customers': limited,
    };
  }

  Future<Map<String, dynamic>> _paymentBreakdown(String timeframe) async {
    final range = _rangeFor(timeframe);
    final sales = await _sales.watchRecentSales(range, limit: null).first;
    final agg = <String, Map<String, int>>{
      'cash': {'count': 0, 'amount_minor': 0},
      'ewallet': {'count': 0, 'amount_minor': 0},
      'utang': {'count': 0, 'amount_minor': 0},
    };
    for (final sale in sales) {
      final method = switch (sale.method) {
        PaymentMethod.cash => 'cash',
        PaymentMethod.ewallet => 'ewallet',
        PaymentMethod.utang => 'utang',
      };
      final bucket = agg[method]!;
      bucket['count'] = bucket['count']! + 1;
      bucket['amount_minor'] =
          bucket['amount_minor']! + sale.netTotal.minorUnits;
    }
    final methods = agg.entries
        .where((method) => method.value['count']! > 0)
        .map(
          (method) => <String, dynamic>{
            'method': method.key,
            'count': method.value['count'],
            'amount_minor': method.value['amount_minor'],
          },
        )
        .toList();
    final totalCount = sales.length;
    final totalAmount = sales.fold<int>(
      0,
      (total, sale) => total + sale.netTotal.minorUnits,
    );
    return <String, dynamic>{
      'timeframe': timeframe,
      'start_day_serial': range.first.serial,
      'end_day_serial': range.last.serial,
      'methods': methods,
      'total_count': totalCount,
      'total_amount_minor': totalAmount,
    };
  }

  Future<Map<String, dynamic>> _storeInfo() async {
    final profile = await _storeProfile.watch().first;
    return <String, dynamic>{
      'name': profile.name,
      'currency': profile.currency.code,
      'onboarding_done': profile.onboardingDone,
      'address': profile.address,
      'phone': profile.phone,
    };
  }

  Future<Map<String, dynamic>> _productCount() async {
    final products = await _products.watchActive().first;
    var tracked = 0;
    var untracked = 0;
    for (final item in products) {
      if (item.product.tracksStock) {
        tracked++;
      } else {
        untracked++;
      }
    }
    return <String, dynamic>{
      'active_count': products.length,
      'tracked_count': tracked,
      'untracked_count': untracked,
    };
  }

  Future<Map<String, dynamic>> _restockSuggestions(
    num budget,
    int limit,
  ) async {
    final budgetMinor = (budget * _currency.minorPerMajor).round();
    final products = await _products.watchActive().first;
    const windowDays = 14;
    final today = _today;
    final range = DayRange(today.plusDays(-(windowDays - 1)), today);
    final soldQty = await _netSoldMilliByProduct(range);

    final candidates = <Map<String, dynamic>>[];
    for (final item in products) {
      if (!item.product.tracksStock) continue;
      final sold = soldQty[item.product.id] ?? 0;
      final low = item.product.lowStockAt != null
          ? item.stock.milli <= item.product.lowStockAt!.milli
          : item.stock.milli <= 5 * Quantity.milliPerUnit;
      if (!low && sold == 0) continue;
      final avgDailyMilli = sold / windowDays;
      var suggestMilli = (avgDailyMilli * 7).round() - item.stock.milli;
      if (!low && suggestMilli <= 0) continue;
      if (suggestMilli < Quantity.milliPerUnit) {
        suggestMilli = Quantity.milliPerUnit;
      }
      final qtyToOrder = (suggestMilli / Quantity.milliPerUnit).ceil();
      final unitCost = item.product.cost.minorUnits;
      final total = unitCost * qtyToOrder;
      candidates.add(<String, dynamic>{
        'product_id': item.product.id,
        'name': item.product.name,
        'unit': item.product.unit.storageName,
        'qty_to_order': qtyToOrder,
        'unit_cost_minor': unitCost,
        'total_minor': total,
        'reason': low ? 'low_stock' : 'demand',
        'current_stock_milli': item.stock.milli,
      });
    }
    candidates.sort((first, second) {
      final firstRank = first['reason'] == 'low_stock' ? 0 : 1;
      final secondRank = second['reason'] == 'low_stock' ? 0 : 1;
      if (firstRank != secondRank) return firstRank.compareTo(secondRank);
      return (second['total_minor'] as int).compareTo(
        first['total_minor'] as int,
      );
    });

    final safeLimit = limit <= 0 ? 10 : limit;
    final suggestions = <Map<String, dynamic>>[];
    var spent = 0;
    for (final candidate in candidates) {
      if (suggestions.length >= safeLimit) break;
      final cost = candidate['total_minor'] as int;
      if (budgetMinor > 0 && spent + cost > budgetMinor) continue;
      suggestions.add(candidate);
      spent += cost;
    }
    return <String, dynamic>{
      'budget_minor': budgetMinor,
      'limit': safeLimit,
      'total_cost_minor': spent,
      'remaining_budget_minor': budgetMinor > 0 ? budgetMinor - spent : 0,
      'candidate_count': candidates.length,
      'suggestions': suggestions,
    };
  }

  Future<Map<String, dynamic>> _overview() async {
    final today = _today;
    final salesToday = await _sales.watchSummary(DayRange.single(today)).first;
    final products = await _products.watchActive().first;
    final balances = await _customers.watchBalances().first;

    var lowStockCount = 0;
    var expiringSoonCount = 0;
    var expiredCount = 0;
    for (final item in products) {
      if (item.isLowOnStock) lowStockCount++;
      final status = ExpiryRules.statusFor(item.product.expiryDay, today);
      if (status is ExpiryExpired) {
        expiredCount++;
      } else if (status is ExpiryNear) {
        if (status.daysLeft <= 7) expiringSoonCount++;
      }
    }
    final utangTotal = totalUnpaidUtang(
      balances,
      currency: _currency,
    ).minorUnits;

    return <String, dynamic>{
      'as_of_day_serial': today.serial,
      'sales_today': _summaryJson(salesToday),
      'low_stock_count': lowStockCount,
      'utang_total_minor': utangTotal,
      'expiring_soon_count': expiringSoonCount,
      'expired_count': expiredCount,
    };
  }
}
