import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/chat/presentation/chat_reply_builders.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';

AssistantReply? replyFromToolResult({
  required String toolName,
  required Map<String, dynamic> result,
  required bool isFilipino,
  required AppLocalizations localizations,
  required Currency currency,
}) {
  if (result['error'] == 'not_found' || result['found'] == false) {
    return _notFoundReply(toolName, result, isFilipino, localizations);
  }
  return switch (toolName) {
    'get_sales_summary' => _salesSummary(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_top_products' => _topProducts(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_product_info' => _productInfo(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_low_stock' => _lowStock(result, isFilipino, localizations),
    'get_stock_forecast' => _stockForecast(result, isFilipino, localizations),
    'get_utang_list' => _utangList(result, isFilipino, localizations, currency),
    'get_utang_risk' => _utangRisk(result, isFilipino, localizations, currency),
    'get_expenses' => _expenses(result, isFilipino, localizations, currency),
    'get_expiry_alerts' => _expiryAlerts(result, isFilipino, localizations),
    'get_slow_moving' => _slowMoving(result, isFilipino, localizations),
    'get_profit_margins' => _profitMargins(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_sales_compare' => _salesCompare(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_sales_trend' => _salesTrend(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_busiest_hours' => _busiestHours(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_suki_loyalty' => _sukiLoyalty(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_payment_breakdown' => _paymentBreakdown(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_store_info' => _storeInfo(result, isFilipino, localizations),
    'get_product_count' => _productCount(result, isFilipino, localizations),
    'get_restock_suggestions' => _restockSuggestions(
      result,
      isFilipino,
      localizations,
      currency,
    ),
    'get_overview' => _overview(result, isFilipino, localizations, currency),
    _ => null,
  };
}

AssistantReply _notFoundReply(
  String toolName,
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final query = result['query']?.toString();
  final text = switch (toolName) {
    'get_product_info' || 'get_stock_forecast' =>
      isFilipino
          ? (query == null || query.isEmpty
                ? 'Hindi ko nakita ang produktong hinahanap mo sa inventory.'
                : 'Hindi ko nakita ang "$query" sa inventory.')
          : (query == null || query.isEmpty
                ? 'I could not find that product in inventory.'
                : 'I could not find "$query" in inventory.'),
    _ => isFilipino ? 'Walang nahanap na datos.' : 'No data found.',
  };
  return AssistantReply(
    text: text,
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.thinking,
  );
}

String _money(int minor, Currency currency) =>
    formatMoney(Money(minor, currency));

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return 0;
}

num _asNum(Object? value) {
  if (value is num) return value;
  return 0;
}

String _tfLabel(String? timeframe, bool isFilipino) => switch (timeframe) {
  'today' => isFilipino ? 'ngayong araw' : 'today',
  'week' => isFilipino ? 'sa nakaraang 7 araw' : 'in the last 7 days',
  'month' => isFilipino ? 'sa nakaraang 30 araw' : 'in the last 30 days',
  _ => isFilipino ? 'sa napiling panahon' : 'for the selected period',
};

String _qtyWithLocal(
  int milli,
  String? unitName,
  AppLocalizations localizations,
) {
  final unit = ProductUnit.tryParse(unitName ?? 'piece') ?? ProductUnit.piece;
  final qtyText = formatQuantity(Quantity.milli(milli), unit);
  final unitText = localizedUnit(localizations, unit);
  return '$qtyText $unitText';
}

AssistantReply _salesSummary(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final tf = result['timeframe']?.toString();
  final revenue = _asInt(result['revenue_minor']);
  final profit = _asInt(result['profit_minor']);
  final count = _asInt(result['sale_count']);
  final text = isFilipino
      ? 'Benta ${_tfLabel(tf, true)}: ${_money(revenue, currency)} kita, $count transaksyon, ${_money(profit, currency)} tubo.'
      : 'Sales ${_tfLabel(tf, false)}: ${_money(revenue, currency)} revenue, $count transactions, ${_money(profit, currency)} profit.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSales,
    mood: revenue > 0 ? TindaAvatarMood.happy : TindaAvatarMood.talking,
  );
}

AssistantReply _topProducts(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final products = (result['products'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  if (products.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Wala pang sapat na benta para sa top products ${_tfLabel(result['timeframe']?.toString(), true)}.'
          : 'Not enough sales yet for top products ${_tfLabel(result['timeframe']?.toString(), false)}.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.thinking,
    );
  }
  final lines = <String>[];
  for (var i = 0; i < products.length && i < 5; i++) {
    final product = products[i];
    final name = product['product_name']?.toString() ?? '';
    final rev = _asInt(product['total_revenue_minor']);
    final qty = _asInt(product['total_qty_milli']);
    final unit = product['unit']?.toString();
    lines.add(
      '${i + 1}. $name (${_qtyWithLocal(qty, unit, localizations)}, ${_money(rev, currency)})',
    );
  }
  final text = isFilipino
      ? 'Top products ${_tfLabel(result['timeframe']?.toString(), true)}: ${lines.join('; ')}.'
      : 'Top products ${_tfLabel(result['timeframe']?.toString(), false)}: ${lines.join('; ')}.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSales,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply _productInfo(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final product = Map<String, dynamic>.from(
    (result['product'] as Map?) ?? const {},
  );
  if (product.isEmpty) {
    return _notFoundReply(
      'get_product_info',
      result,
      isFilipino,
      localizations,
    );
  }
  final name = product['name']?.toString() ?? '';
  final unitName = product['unit']?.toString() ?? 'piece';
  final unit = ProductUnit.tryParse(unitName) ?? ProductUnit.piece;
  final unitText = localizedUnit(localizations, unit);
  final price = _money(_asInt(product['price_minor']), currency);
  final tracks = product['tracks_stock'] == true;
  final stockText = tracks
      ? (isFilipino
            ? 'Natitirang stock: ${_qtyWithLocal(_asInt(product['stock_milli']), unitName, localizations)}.'
            : 'Remaining stock: ${_qtyWithLocal(_asInt(product['stock_milli']), unitName, localizations)}.')
      : (isFilipino ? 'Stock: walang bilang.' : 'Stock: no stock count.');
  final utangMinor = product['utang_price_minor'];
  final utangText = utangMinor is num
      ? (isFilipino
            ? ' Presyong utang: ${_money(_asInt(utangMinor), currency)}.'
            : ' Utang price: ${_money(_asInt(utangMinor), currency)}.')
      : '';
  final text = isFilipino
      ? '$name: $price bawat $unitText. $stockText$utangText'
      : '$name: $price per $unitText. $stockText$utangText';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply _lowStock(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final items = (result['items'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  if (items.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang produktong mababa ang stock ngayon.'
          : 'No products are low on stock right now.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }
  final parts = items
      .take(8)
      .map((i) {
        final name = i['name']?.toString() ?? '';
        final stock = _qtyWithLocal(
          _asInt(i['stock_milli']),
          i['unit']?.toString(),
          localizations,
        );
        return '$name ($stock)';
      })
      .join(', ');
  final text = isFilipino
      ? 'Mababa ang stock: $parts.'
      : 'Low on stock: $parts.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.thinking,
  );
}

AssistantReply _stockForecast(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final name = result['product_name']?.toString() ?? '';
  if (result['tracks_stock'] == false) {
    return AssistantReply(
      text: isFilipino
          ? '$name ay walang stock tracking.'
          : '$name does not track stock.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }
  final unitName = result['unit']?.toString();
  final stock = _qtyWithLocal(
    _asInt(result['current_stock_milli']),
    unitName,
    localizations,
  );
  final avg = _asNum(result['avg_daily_sales_units']);
  final days = result['days_remaining'];
  if (avg <= 0 || days == null) {
    final text = isFilipino
        ? '$name ay may $stock na stock. Walang sapat na recent benta para tantiyahin kung kailan mauubos.'
        : '$name has $stock in stock. Not enough recent sales to estimate when it will run out.';
    return AssistantReply(
      text: text,
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }
  final daysNum = (days is num) ? days.toDouble() : 0.0;
  final daysText = daysNum.isFinite ? daysNum.toStringAsFixed(1) : '';
  final text = isFilipino
      ? '$name ay may $stock na stock, ~${avg.toStringAsFixed(2)} benta/araw; tinatayang mauubos sa ~$daysText araw.'
      : '$name has $stock in stock, ~${avg.toStringAsFixed(2)} sold/day; estimated to run out in ~$daysText days.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _utangList(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final customers = (result['customers'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  final total = _money(_asInt(result['total_balance_minor']), currency);
  if (customers.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang utang na may balanse ngayon.'
          : 'No customers have an outstanding utang balance.',
      source: localizations.chatSourceUtang,
      mood: TindaAvatarMood.happy,
    );
  }
  final parts = customers
      .take(8)
      .map((c) {
        final name = c['name']?.toString() ?? '';
        final bal = _money(_asInt(c['balance_minor']), currency);
        return '$name ($bal)';
      })
      .join(', ');
  final text = isFilipino
      ? 'May utang: $parts. Kabuuang balanse: $total.'
      : 'Outstanding utang: $parts. Total balance: $total.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceUtang,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _utangRisk(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final highRisk = (result['high_risk'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  final total = _money(_asInt(result['total_at_risk_minor']), currency);
  if (highRisk.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang high-risk na utang sa ngayon.'
          : 'No high-risk utang right now.',
      source: localizations.chatSourceUtang,
      mood: TindaAvatarMood.happy,
    );
  }
  final parts = highRisk
      .take(5)
      .map((c) {
        final name = c['name']?.toString() ?? '';
        final bal = _money(_asInt(c['balance_minor']), currency);
        final age = c['oldest_debt_age_days'];
        final ageText = age is num
            ? (isFilipino ? ', ${age.toInt()} araw' : ', ${age.toInt()} days')
            : '';
        return '$name ($bal$ageText)';
      })
      .join('; ');
  final text = isFilipino
      ? 'High-risk utang: $parts. Kabuuang nasa panganib: $total.'
      : 'High-risk utang: $parts. Total at risk: $total.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceUtang,
    mood: TindaAvatarMood.thinking,
  );
}

AssistantReply _expenses(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final total = _money(_asInt(result['total_minor']), currency);
  final count = _asInt(result['count']);
  final tf = result['timeframe']?.toString();
  final text = count == 0
      ? (isFilipino
            ? 'Walang naitalang gastusin ${_tfLabel(tf, true)}.'
            : 'No recorded expenses ${_tfLabel(tf, false)}.')
      : (isFilipino
            ? 'Gastos ${_tfLabel(tf, true)}: $total ($count entry).'
            : 'Expenses ${_tfLabel(tf, false)}: $total ($count entries).');
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSummary,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _expiryAlerts(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final soon = (result['expiring_soon'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .toList();
  final expired = (result['already_expired'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .toList();
  if (soon.isEmpty && expired.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang produktong malapit nang mag-expire o expired.'
          : 'No products expiring soon or already expired.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }
  final parts = <String>[];
  for (final expiredItem in expired.take(5)) {
    final fields = Map<String, dynamic>.from(expiredItem);
    parts.add('${fields['name']} (${isFilipino ? 'expired' : 'expired'})');
  }
  for (final soonItem in soon.take(5)) {
    final fields = Map<String, dynamic>.from(soonItem);
    final days = fields['days_left'];
    final daysLeft = days is num ? days.toInt() : null;
    parts.add(
      '${fields['name']} (${daysLeft == null ? '' : (isFilipino ? '$daysLeft araw' : '$daysLeft days')})',
    );
  }
  final text = isFilipino
      ? 'Expiry alerts: ${parts.join(', ')}.'
      : 'Expiry alerts: ${parts.join(', ')}.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.thinking,
  );
}

AssistantReply _slowMoving(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final items = (result['items'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  if (items.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang slow-moving na produkto sa napiling panahon.'
          : 'No slow-moving products in the selected period.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }
  final names = items
      .take(8)
      .map((i) => i['name']?.toString() ?? '')
      .where((name) => name.isNotEmpty)
      .join(', ');
  final days = result['days'];
  final dayText = days is num ? days.toInt().toString() : '';
  final text = isFilipino
      ? 'Mabagal/hindi nabibili${dayText.isEmpty ? '' : ' sa $dayText araw'}: $names.'
      : 'Slow/no sales${dayText.isEmpty ? '' : ' in $dayText days'}: $names.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _profitMargins(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final products = (result['products'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  if (products.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang datos ng profit margin.'
          : 'No profit margin data.',
      source: localizations.chatSourceSummary,
      mood: TindaAvatarMood.thinking,
    );
  }
  final parts = products
      .take(5)
      .map((p) {
        final name = p['name']?.toString() ?? '';
        final pct = _asNum(p['margin_pct']).toStringAsFixed(1);
        return '$name ($pct%)';
      })
      .join(', ');
  final sort = result['sort']?.toString() == 'lowest';
  final text = isFilipino
      ? '${sort ? 'Pinakamababang' : 'Pinakamataas na'} margin: $parts.'
      : '${sort ? 'Lowest' : 'Highest'} margins: $parts.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSummary,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _salesCompare(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final current = Map<String, dynamic>.from(
    (result['current'] as Map?) ?? const {},
  );
  final previous = Map<String, dynamic>.from(
    (result['previous'] as Map?) ?? const {},
  );
  final delta = Map<String, dynamic>.from(
    (result['delta'] as Map?) ?? const {},
  );
  final curRev = _money(_asInt(current['revenue_minor']), currency);
  final prevRev = _money(_asInt(previous['revenue_minor']), currency);
  final revenueChange = _asInt(delta['revenue_minor']);
  final dir = revenueChange > 0
      ? (isFilipino ? 'tumaas' : 'up')
      : revenueChange < 0
      ? (isFilipino ? 'bumaba' : 'down')
      : (isFilipino ? 'pareho' : 'flat');
  final dText = _money(revenueChange.abs(), currency);
  final period = result['period']?.toString() ?? 'day';
  final text = isFilipino
      ? 'Kumpara ($period): ngayon $curRev vs dati $prevRev — $dir ng $dText.'
      : 'Compare ($period): current $curRev vs previous $prevRev — $dir by $dText.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSales,
    mood: revenueChange >= 0 ? TindaAvatarMood.happy : TindaAvatarMood.talking,
  );
}

AssistantReply _salesTrend(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final series = (result['series'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  if (series.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang datos ng sales trend.'
          : 'No sales trend data.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.thinking,
    );
  }
  final last = series.last;
  final first = series.first;
  final lastRev = _money(_asInt(last['revenue_minor']), currency);
  final firstRev = _money(_asInt(first['revenue_minor']), currency);
  final text = isFilipino
      ? 'Sales trend (${series.length} araw): mula $firstRev hanggang $lastRev (pinakabago).'
      : 'Sales trend (${series.length} days): from $firstRev to $lastRev (latest).';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSales,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _busiestHours(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final hours = (result['hours'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  if (hours.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang datos ng busiest hours.'
          : 'No busiest-hours data.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.thinking,
    );
  }
  final sorted = [...hours]
    ..sort(
      (first, second) => _asInt(
        second['transaction_count'],
      ).compareTo(_asInt(first['transaction_count'])),
    );
  final parts = sorted
      .take(3)
      .map((h) {
        final hour = _asInt(h['hour']);
        final transactionCount = _asInt(h['transaction_count']);
        return '$hour:00 ($transactionCount)';
      })
      .join(', ');
  final text = isFilipino
      ? 'Pinakaabalang oras: $parts.'
      : 'Busiest hours: $parts.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSales,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _sukiLoyalty(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final customers = (result['customers'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  if (customers.isEmpty) {
    return AssistantReply(
      text: isFilipino ? 'Walang datos ng suki/loyalty.' : 'No loyalty data.',
      source: localizations.chatSourceUtang,
      mood: TindaAvatarMood.thinking,
    );
  }
  final parts = customers
      .take(5)
      .map((c) {
        final name =
            c['customer_name']?.toString() ?? c['name']?.toString() ?? '';
        final spend = _money(_asInt(c['total_spend_minor']), currency);
        final visits = _asInt(c['visits']);
        return '$name ($spend, $visits)';
      })
      .join(', ');
  final text = isFilipino
      ? 'Top suki: $parts.'
      : 'Top loyal customers: $parts.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceUtang,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply _paymentBreakdown(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final methods = (result['methods'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  if (methods.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang datos ng payment breakdown.'
          : 'No payment breakdown data.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.thinking,
    );
  }
  final parts = methods
      .map((m) {
        final method = m['method']?.toString() ?? '';
        final amount = _money(_asInt(m['amount_minor']), currency);
        final count = _asInt(m['count']);
        return '$method $amount ($count)';
      })
      .join(', ');
  final total = _money(_asInt(result['total_amount_minor']), currency);
  final text = isFilipino
      ? 'Payment breakdown: $parts. Kabuuan: $total.'
      : 'Payment breakdown: $parts. Total: $total.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSales,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _storeInfo(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final name = (result['name']?.toString() ?? '').trim();
  final text = name.isEmpty
      ? (isFilipino
            ? 'Walang nakatakdang pangalan ng tindahan.'
            : 'Store name is not set.')
      : (isFilipino ? 'Ang tindahan mo ay $name.' : 'Your store is $name.');
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSummary,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply _productCount(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final active = _asInt(result['active_count']);
  final tracked = result['tracked_count'];
  final untracked = result['untracked_count'];
  final extras = <String>[];
  if (tracked is num) {
    extras.add(
      isFilipino ? '${tracked.toInt()} tracked' : '${tracked.toInt()} tracked',
    );
  }
  if (untracked is num) {
    extras.add(
      isFilipino
          ? '${untracked.toInt()} untracked'
          : '${untracked.toInt()} untracked',
    );
  }
  final extraText = extras.isEmpty ? '' : ' (${extras.join(', ')})';
  final text = active == 0
      ? (isFilipino
            ? 'Wala ka pang produkto sa inventory.'
            : 'You have no products in inventory.')
      : (isFilipino
            ? 'May $active aktibong produkto ka$extraText.'
            : 'You have $active active products$extraText.');
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSummary,
    mood: active == 0 ? TindaAvatarMood.thinking : TindaAvatarMood.happy,
  );
}

AssistantReply _restockSuggestions(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final suggestions = (result['suggestions'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .map(Map<String, dynamic>.from)
      .toList();
  final totalCost = _money(_asInt(result['total_cost_minor']), currency);
  if (suggestions.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang restock suggestion ngayon.'
          : 'No restock suggestions right now.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }
  final parts = suggestions
      .take(5)
      .map((s) {
        final name = s['name']?.toString() ?? '';
        final qty = s['qty_to_order'] ?? s['qty'];
        final quantityText = qty is num ? qty.toInt().toString() : '';
        return quantityText.isEmpty ? name : '$name x$quantityText';
      })
      .join(', ');
  final text = isFilipino
      ? 'Restock suggestion ($totalCost): $parts.'
      : 'Restock suggestions ($totalCost): $parts.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply _overview(
  Map<String, dynamic> result,
  bool isFilipino,
  AppLocalizations localizations,
  Currency currency,
) {
  final salesToday = Map<String, dynamic>.from(
    (result['sales_today'] as Map?) ?? const {},
  );
  final rev = _money(_asInt(salesToday['revenue_minor']), currency);
  final profit = _money(_asInt(salesToday['profit_minor']), currency);
  final low = _asInt(result['low_stock_count']);
  final utang = _money(_asInt(result['utang_total_minor']), currency);
  final expSoon = _asInt(result['expiring_soon_count']);
  final expired = _asInt(result['expired_count']);
  final text = isFilipino
      ? 'Overview: benta ngayon $rev (tubo $profit), mababang stock $low, utang $utang, expiring soon $expSoon, expired $expired.'
      : 'Overview: sales today $rev (profit $profit), low stock $low, utang $utang, expiring soon $expSoon, expired $expired.';
  return AssistantReply(
    text: text,
    source: localizations.chatSourceSummary,
    mood: TindaAvatarMood.talking,
  );
}
