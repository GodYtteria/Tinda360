import 'dart:math' as math;

import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/calendar/time_greeting.dart';
import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/unpaid_utang.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';

final class AssistantReply {
  const new({
    required this.text,
    required this.source,
    required this.mood,
  });

  final String text;
  final String source;
  final TindaAvatarMood mood;
}

AssistantReply buildGreetingReply(
  DateTime now,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final greeting = timeOfDayGreeting(now, isFilipino: isFilipino);
  return AssistantReply(
    text: isFilipino
        ? '$greeting Handa akong tumulong sa benta, stock, at utang ng tindahan mo.'
        : '$greeting I am ready to help with your store sales, stock, and utang.',
    source: localizations.chatSourceSummary,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply buildThanksReply(
  bool isFilipino,
  AppLocalizations localizations,
) => AssistantReply(
  text: isFilipino
      ? 'Walang anuman! Sabihin mo lang kung may itatanong ka pa.'
      : 'You are welcome! Ask anytime if you need anything else.',
  source: localizations.chatSourceSummary,
  mood: TindaAvatarMood.happy,
);

AssistantReply buildHelpReply(
  bool isFilipino,
  AppLocalizations localizations,
) => AssistantReply(
  text: isFilipino
      ? 'Pwede mong itanong: "Magkano benta ngayon?", "Ano pinakamabenta?", "Ano mababa ang stock?", "Sino may utang?", "Ano malapit mag-expire?", "Ano pinakamalaking tubo?", "Tumataas ba benta ko?", "Anong oras pinakamabenta?", "Sino laging bumibili?", "Ilan cash vs utang?", "Kailan mauubos ang X?", o pangalan ng produkto/suki.'
      : 'You can ask: "How are sales today?", "Top products?", "What is low on stock?", "Who has utang?", "What is expiring soon?", "Highest margin products?", "Are sales trending up?", "Busiest hours?", "Most loyal customers?", "Cash vs utang breakdown?", "When will X run out?", or a product/suki name.',
  source: localizations.chatSourceSummary,
  mood: TindaAvatarMood.talking,
);

AssistantReply buildSalesCompareReply(
  SalesSummary todaySummary,
  SalesSummary yesterdaySummary,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final todayText = formatMoney(todaySummary.revenue);
  final yesterdayText = formatMoney(yesterdaySummary.revenue);
  final diffMinor =
      todaySummary.revenue.minorUnits - yesterdaySummary.revenue.minorUnits;
  final diffText = formatMoney(
    Money(diffMinor.abs(), todaySummary.revenue.currency),
  );
  final trendText = diffMinor > 0
      ? (isFilipino ? 'Mas mataas ng $diffText' : 'Up by $diffText')
      : diffMinor < 0
      ? (isFilipino ? 'Mas mababa ng $diffText' : 'Down by $diffText')
      : (isFilipino ? 'Pareho lang' : 'Same');
  return AssistantReply(
    text: isFilipino
        ? 'Benta ngayon: $todayText (${todaySummary.saleCount} benta) vs kahapon: $yesterdayText (${yesterdaySummary.saleCount} benta). $trendText.'
        : 'Today: $todayText (${todaySummary.saleCount} sales) vs yesterday: $yesterdayText (${yesterdaySummary.saleCount} sales). $trendText.',
    source: localizations.chatSourceSales,
    mood: diffMinor >= 0 ? TindaAvatarMood.happy : TindaAvatarMood.talking,
  );
}

AssistantReply buildSlowMovingReply(
  List<StockedProduct> products,
  Set<String> soldIds,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final slowItems = products
      .where(
        (item) => item.stock.isPositive && !soldIds.contains(item.product.id),
      )
      .take(5)
      .map((item) => item.product.name)
      .toList();
  if (slowItems.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Maganda! Lahat ng may stock na produkto ay nabenta sa nakaraang 14 araw.'
          : 'Great! All stocked products had sales in the last 14 days.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }
  return AssistantReply(
    text: isFilipino
        ? 'Walang benta sa nakaraang 14 araw: ${slowItems.join(', ')}.'
        : 'No sales in the last 14 days: ${slowItems.join(', ')}.',
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );
}

const Set<String> _questionFillerWords = <String>{
  'magkano',
  'ang',
  'ng',
  'sa',
  'po',
  'ba',
  'presyo',
  'halaga',
  'price',
  'how',
  'much',
  'is',
  'the',
  'of',
  'what',
  'whats',
  'cost',
  'kailan',
  'kelan',
  'mauubos',
  'maubos',
  'ubos',
  'ilang',
  'araw',
  'tatagal',
  'bago',
  'pa',
  'long',
  'will',
  'last',
  'run',
  'out',
  'when',
  'days',
  'left',
  'stock',
  'forecast',
  'it',
};

bool namesUnknownProduct(String normalizedQuery) => normalizedQuery
    .split(' ')
    .any(
      (word) => word.isNotEmpty && !_questionFillerWords.contains(word),
    );

AssistantReply buildProductPromptReply(
  bool isFilipino,
  AppLocalizations localizations, {
  required bool namesUnknownProduct,
}) {
  final String text;
  if (namesUnknownProduct) {
    text = isFilipino
        ? 'Hindi ko nakita ang produktong iyon sa inventory. Subukan ang eksaktong pangalan.'
        : 'I could not find that product in your inventory. Try its exact name.';
  } else {
    text = isFilipino
        ? 'Pakilagay ang pangalan ng produkto (hal. "Magkano Pancit Canton?").'
        : 'Include the product name (e.g. "Price of Pancit Canton?").';
  }
  return AssistantReply(
    text: text,
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );
}

DayRange rangeForTimeframe(QueryTimeframe timeframe, LocalDay today) =>
    switch (timeframe) {
      QueryTimeframe.today => DayRange.single(today),
      QueryTimeframe.week => DayRange(today.plusDays(-6), today),
      QueryTimeframe.month => DayRange(today.plusDays(-29), today),
    };

const int _minimumMentionedNameLength = 3;
final RegExp _nonWordCharacters = RegExp(r'[^\w\s]');
final RegExp _whitespaceRun = RegExp(r'\s+');

String _normalizeForNameMatch(String text) => text
    .toLowerCase()
    .replaceAll(_nonWordCharacters, ' ')
    .replaceAll(_whitespaceRun, ' ')
    .trim();

T? _longestMentionedName<T>(
  String normalized,
  Iterable<T> candidates,
  String Function(T candidate) nameOf,
) {
  final paddedQuery = ' ${_normalizeForNameMatch(normalized)} ';
  T? best;
  var bestLength = 0;
  for (final candidate in candidates) {
    final name = _normalizeForNameMatch(nameOf(candidate));
    if (name.length < _minimumMentionedNameLength) continue;
    if (name.length > bestLength && paddedQuery.contains(' $name ')) {
      best = candidate;
      bestLength = name.length;
    }
  }
  return best;
}

StockedProduct? findMentionedProduct(
  String normalized,
  List<StockedProduct> products,
) => _longestMentionedName(
  normalized,
  products,
  (item) => item.product.name,
);

CustomerBalance? findMentionedCustomer(
  String normalized,
  List<CustomerBalance> balances,
) => _longestMentionedName(
  normalized,
  balances,
  (item) => item.customer.name,
);

AssistantReply buildProductLookupReply(
  StockedProduct item,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final product = item.product;
  final price = formatMoney(product.price);
  final unit = localizedUnit(localizations, product.unit);
  final stock = formatQuantity(item.stock, product.unit);
  final utangPrice = product.utangPrice;
  final stockText = product.tracksStock
      ? (isFilipino
            ? 'Natitirang stock: $stock $unit.'
            : 'Remaining stock: $stock $unit.')
      : (isFilipino ? 'Stock: walang bilang.' : 'Stock: no stock count.');
  final utangText = utangPrice == null
      ? ''
      : (isFilipino
            ? ' Presyong utang: ${formatMoney(utangPrice)}.'
            : ' Utang price: ${formatMoney(utangPrice)}.');
  return AssistantReply(
    text: isFilipino
        ? '${product.name}: $price bawat $unit. $stockText$utangText'
        : '${product.name}: $price per $unit. $stockText$utangText',
    source: localizations.chatSourceInventory,
    mood: product.tracksStock && item.isLowOnStock
        ? TindaAvatarMood.talking
        : TindaAvatarMood.happy,
  );
}

AssistantReply buildCustomerLookupReply(
  CustomerBalance item,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final balance = formatMoney(item.balance);
  return AssistantReply(
    text: isFilipino
        ? 'Si ${item.customer.name} ay may balanseng utang na $balance.'
        : '${item.customer.name} has an utang balance of $balance.',
    source: localizations.chatSourceUtang,
    mood: item.owes ? TindaAvatarMood.talking : TindaAvatarMood.happy,
  );
}

AssistantReply buildTopProductsReply(
  List<TopProduct> topProducts,
  QueryTimeframe timeframe,
  bool isFilipino,
  AppLocalizations localizations,
) {
  if (topProducts.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Wala pang nabebentang produkto sa panahong ito.'
          : 'No products sold in this period yet.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.talking,
    );
  }
  final summaryText = topProducts
      .asMap()
      .entries
      .map(
        (entry) =>
            '${entry.key + 1}. ${entry.value.productName} '
            '(${formatQuantity(entry.value.totalQuantity, entry.value.unit)}, '
            '${formatMoney(entry.value.totalRevenue)})',
      )
      .join(', ');
  final periodWord = timeframeLabel(timeframe, isFilipino);
  return AssistantReply(
    text: isFilipino
        ? 'Pinakamabenta ($periodWord): $summaryText.'
        : 'Top selling ($periodWord): $summaryText.',
    source: localizations.chatSourceSales,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply buildSalesReply(
  SalesSummary summary,
  QueryTimeframe timeframe,
  bool isFilipino,
  AppLocalizations localizations,
) {
  if (timeframe == QueryTimeframe.today) {
    if (summary.saleCount == 0) {
      return AssistantReply(
        text: localizations.chatReplySalesEmpty,
        source: localizations.chatSourceSales,
        mood: TindaAvatarMood.talking,
      );
    }
    return AssistantReply(
      text: localizations.chatReplySalesSummary(
        summary.saleCount,
        formatMoney(summary.revenue),
        formatMoney(summary.profit),
      ),
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.happy,
    );
  }
  final periodWord = timeframeLabel(timeframe, isFilipino);
  final revenue = formatMoney(summary.revenue);
  final profit = formatMoney(summary.profit);
  return AssistantReply(
    text: isFilipino
        ? 'Sa $periodWord ay may ${summary.saleCount} na benta: $revenue ang kabuuang benta at $profit ang tubo.'
        : 'For $periodWord there are ${summary.saleCount} sales: $revenue total revenue and $profit profit.',
    source: localizations.chatSourceSales,
    mood: summary.saleCount > 0
        ? TindaAvatarMood.happy
        : TindaAvatarMood.talking,
  );
}

String timeframeLabel(QueryTimeframe timeframe, bool isFilipino) =>
    switch (timeframe) {
      QueryTimeframe.today => isFilipino ? 'ngayon' : 'today',
      QueryTimeframe.week => isFilipino ? 'nakaraang 7 araw' : 'last 7 days',
      QueryTimeframe.month => isFilipino ? 'nakaraang 30 araw' : 'last 30 days',
    };

AssistantReply buildLowStockReply(
  List<StockedProduct> products,
  AppLocalizations localizations,
) {
  final lowItems = products.where((item) => item.isLowOnStock).toList();
  if (lowItems.isEmpty) {
    return AssistantReply(
      text: localizations.chatReplyLowStockNone(products.length),
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }
  final names = lowItems
      .take(3)
      .map(
        (item) =>
            '${item.product.name} (${formatQuantity(item.stock, item.product.unit)})',
      )
      .join(', ');
  return AssistantReply(
    text: localizations.chatReplyLowStockFound(lowItems.length, names),
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply buildUtangReply(
  List<CustomerBalance> balances,
  Currency currency,
  AppLocalizations localizations,
) {
  final debtors = balances.where((item) => item.owes).toList();
  if (debtors.isEmpty) {
    return AssistantReply(
      text: localizations.chatReplyUtangNone,
      source: localizations.chatSourceUtang,
      mood: TindaAvatarMood.happy,
    );
  }
  final total = totalUnpaidUtang(balances, currency: currency);
  final topNames = debtors
      .take(3)
      .map((item) => '${item.customer.name} (${formatMoney(item.balance)})')
      .join(', ');
  return AssistantReply(
    text: localizations.chatReplyUtangSummary(
      formatMoney(total),
      debtors.length,
      topNames,
    ),
    source: localizations.chatSourceUtang,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply buildUtangRiskReply(
  SalesSummary summary,
  List<CustomerBalance> balances,
  List<ExpenseEntry> expenses,
  Currency currency,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final totalExpenses = expenses.fold(
    Money.zero(currency),
    (total, entry) => total + entry.amount,
  );
  final netIncome = summary.profit - totalExpenses;
  final unpaidUtangTotal = totalUnpaidUtang(balances, currency: currency);

  final utangExceedsThirtyPercent = summary.revenue.isPositive
      ? unpaidUtangTotal.minorUnits * 100 > summary.revenue.minorUnits * 30
      : unpaidUtangTotal.isPositive;
  final hasRisk = netIncome.isNegative || utangExceedsThirtyPercent;

  final unpaidText = formatMoney(unpaidUtangTotal);
  final netIncomeText = formatMoney(netIncome);

  if (hasRisk) {
    return AssistantReply(
      text: isFilipino
          ? 'Babala: May $unpaidText pang hindi nababayarang utang / negatibo ang netong kita ($netIncomeText). Iwasan muna ang bagong pautang at maningil muna.'
          : 'Warning: $unpaidText in unpaid utang with net income of $netIncomeText. Hold off on new utang and collect payments first.',
      source: localizations.chatSourceUtang,
      mood: TindaAvatarMood.talking,
    );
  }

  return AssistantReply(
    text: isFilipino
        ? 'Maayos ang cashflow! Netong kita: $netIncomeText, hindi pa nababayarang utang: $unpaidText. Ligtas magpautang nang may ingat.'
        : 'Cashflow is healthy! Net income: $netIncomeText, unpaid utang: $unpaidText. Safe to extend credit carefully.',
    source: localizations.chatSourceUtang,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply buildRestockBudgetReply(
  List<StockedProduct> products,
  Currency currency,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final lowStockProducts = products
      .where((stockedProduct) => stockedProduct.isLowOnStock)
      .toList();
  if (lowStockProducts.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Kumpleto pa ang stock! Walang kailangang bilhin sa palengke ngayon.'
          : 'Stock is healthy! No items need restocking right now.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }

  var totalBudgetMinorUnits = 0;
  for (final stockedProduct in lowStockProducts) {
    final targetQuantity =
        stockedProduct.product.lowStockAt ?? const Quantity.whole(5);
    final deficitMilli = math.max(
      Quantity.milliPerUnit,
      targetQuantity.milli - stockedProduct.stock.milli,
    );
    totalBudgetMinorUnits +=
        (stockedProduct.product.cost.minorUnits *
                deficitMilli /
                Quantity.milliPerUnit)
            .round();
  }

  final totalBudget = Money(totalBudgetMinorUnits, currency);
  final budgetText = formatMoney(totalBudget);
  final itemCount = lowStockProducts.length;
  return AssistantReply(
    text: isFilipino
        ? 'Tinatayang puhunan sa palengke: $budgetText para sa $itemCount produkto na mababa ang stock.'
        : 'Estimated restock budget: $budgetText for $itemCount low-stock items.',
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply buildExpiryAlertReply(
  List<StockedProduct> products,
  LocalDay today,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final alerts = <String>[];
  for (final item in products) {
    final status = ExpiryRules.statusFor(item.product.expiryDay, today);
    if (status == null) continue;
    switch (status) {
      case ExpiryExpired():
        alerts.add(
          isFilipino
              ? '${item.product.name} (EXPIRED na)'
              : '${item.product.name} (EXPIRED)',
        );
      case ExpiryNear(:final daysLeft):
        alerts.add(
          isFilipino
              ? '${item.product.name} ($daysLeft araw na lang)'
              : '${item.product.name} ($daysLeft days left)',
        );
    }
  }
  if (alerts.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang produkto na malapit mag-expire o expired na.'
          : 'No products are expiring soon or already expired.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }
  return AssistantReply(
    text: isFilipino
        ? 'Mga produkto na mag-e-expire o expired na: ${alerts.join(', ')}.'
        : 'Products expiring or expired: ${alerts.join(', ')}.',
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );
}

AssistantReply buildProfitMarginReply(
  List<StockedProduct> products,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final withMargin =
      products.where((item) => item.product.price.minorUnits > 0).toList()
        ..sort(
          (first, second) =>
              (second.product.price.minorUnits - second.product.cost.minorUnits)
                  .compareTo(
                    first.product.price.minorUnits -
                        first.product.cost.minorUnits,
                  ),
        );
  if (withMargin.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang produkto na may presyo pa.'
          : 'No products with pricing found.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }
  final top = withMargin
      .take(3)
      .map((item) {
        final margin = Money(
          item.product.price.minorUnits - item.product.cost.minorUnits,
          item.product.price.currency,
        );
        return '${item.product.name} (${formatMoney(margin)})';
      })
      .join(', ');
  return AssistantReply(
    text: isFilipino
        ? 'Pinakamalaking tubo bawat benta: $top.'
        : 'Highest profit margin per sale: $top.',
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply buildSalesTrendReply(
  SalesSummary todaySummary,
  SalesSummary yesterdaySummary,
  SalesSummary twoDaysAgoSummary,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final todayRev = todaySummary.revenue.minorUnits;
  final yesterdayRev = yesterdaySummary.revenue.minorUnits;
  final twoDaysAgoRev = twoDaysAgoSummary.revenue.minorUnits;

  final String trendWord;
  if (todayRev > yesterdayRev && yesterdayRev > twoDaysAgoRev) {
    trendWord = isFilipino ? 'Pataas' : 'Up';
  } else if (todayRev < yesterdayRev && yesterdayRev < twoDaysAgoRev) {
    trendWord = isFilipino ? 'Pababa' : 'Down';
  } else {
    trendWord = isFilipino ? 'Paiba-iba' : 'Flat';
  }

  final todayText = formatMoney(todaySummary.revenue);
  final yesterdayText = formatMoney(yesterdaySummary.revenue);
  final twoDaysAgoText = formatMoney(twoDaysAgoSummary.revenue);
  return AssistantReply(
    text: isFilipino
        ? '$trendWord ang trend. 2 araw na nakalipas: $twoDaysAgoText → kahapon: $yesterdayText → ngayon: $todayText.'
        : '$trendWord trend. 2 days ago: $twoDaysAgoText → yesterday: $yesterdayText → today: $todayText.',
    source: localizations.chatSourceSales,
    mood: trendWord == (isFilipino ? 'Pataas' : 'Up')
        ? TindaAvatarMood.happy
        : TindaAvatarMood.talking,
  );
}

AssistantReply buildBusiestHoursReply(
  List<SaleRecord> sales,
  bool isFilipino,
  AppLocalizations localizations,
) {
  if (sales.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang benta pa sa panahong ito.'
          : 'No sales in this period yet.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.talking,
    );
  }
  final hourCounts = <int, int>{};
  for (final sale in sales) {
    final hour = DateTime.fromMillisecondsSinceEpoch(
      sale.createdAtMs,
      isUtc: true,
    ).toLocal().hour;
    hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
  }
  final sorted = hourCounts.entries.toList()
    ..sort((first, second) => second.value.compareTo(first.value));
  final top = sorted
      .take(3)
      .map((entry) {
        final hour = entry.key;
        final label = hour == 0
            ? '12 AM'
            : hour < 12
            ? '$hour AM'
            : hour == 12
            ? '12 PM'
            : '${hour - 12} PM';
        return isFilipino
            ? '$label (${entry.value} benta)'
            : '$label (${entry.value} sales)';
      })
      .join(', ');
  return AssistantReply(
    text: isFilipino ? 'Pinakamabentang oras: $top.' : 'Busiest hours: $top.',
    source: localizations.chatSourceSales,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply buildSukiLoyaltyReply(
  List<SaleRecord> sales,
  bool isFilipino,
  AppLocalizations localizations,
) {
  final customerCounts = <String, int>{};
  for (final sale in sales) {
    final name = sale.customerName;
    if (name == null) continue;
    customerCounts[name] = (customerCounts[name] ?? 0) + 1;
  }
  if (customerCounts.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang may pangalang suki sa mga benta sa panahong ito.'
          : 'No named customers in sales for this period.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.talking,
    );
  }
  final sorted = customerCounts.entries.toList()
    ..sort((first, second) => second.value.compareTo(first.value));
  final top = sorted
      .take(3)
      .map((entry) {
        return isFilipino
            ? '${entry.key} (${entry.value} benta)'
            : '${entry.key} (${entry.value} sales)';
      })
      .join(', ');
  return AssistantReply(
    text: isFilipino
        ? 'Pinaka-loyal na suki: $top.'
        : 'Most frequent buyers: $top.',
    source: localizations.chatSourceSales,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply buildPaymentBreakdownReply(
  List<SaleRecord> sales,
  Currency currency,
  bool isFilipino,
  AppLocalizations localizations,
) {
  if (sales.isEmpty) {
    return AssistantReply(
      text: isFilipino
          ? 'Walang benta pa sa panahong ito.'
          : 'No sales in this period yet.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.talking,
    );
  }
  final counts = <PaymentMethod, int>{};
  final totals = <PaymentMethod, Money>{};
  for (final sale in sales) {
    counts[sale.method] = (counts[sale.method] ?? 0) + 1;
    totals[sale.method] =
        (totals[sale.method] ?? Money.zero(currency)) + sale.netTotal;
  }
  final parts = <String>[];
  for (final method in PaymentMethod.values) {
    final count = counts[method] ?? 0;
    if (count == 0) continue;
    final total = formatMoney(totals[method]!);
    final label = switch (method) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.ewallet => 'e-wallet',
      PaymentMethod.utang => 'utang',
    };
    parts.add('$count $label ($total)');
  }
  return AssistantReply(
    text: isFilipino
        ? 'Breakdown ng bayad: ${parts.join(', ')}.'
        : 'Payment breakdown: ${parts.join(', ')}.',
    source: localizations.chatSourceSales,
    mood: TindaAvatarMood.happy,
  );
}

AssistantReply buildStockForecastReply(
  StockedProduct? mentionedProduct,
  List<StockedProduct> products,
  Map<String, int> soldQuantities,
  bool isFilipino,
  AppLocalizations localizations, {
  required bool namesUnknownProduct,
}) {
  if (mentionedProduct == null) {
    final text = namesUnknownProduct
        ? (isFilipino
              ? 'Hindi ko nakita ang produktong iyon sa inventory. Subukan ang eksaktong pangalan.'
              : 'I could not find that product in your inventory. Try its exact name.')
        : (isFilipino
              ? 'Pakilagay ang pangalan ng produkto (hal. "Kailan mauubos ang Bigas?").'
              : 'Include the product name (e.g. "When will Rice run out?").');
    return AssistantReply(
      text: text,
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }
  final product = mentionedProduct.product;
  if (!product.tracksStock) {
    return AssistantReply(
      text: isFilipino
          ? '${product.name} ay walang stock tracking.'
          : '${product.name} does not track stock.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }
  final soldMilli = soldQuantities[product.id] ?? 0;
  if (soldMilli == 0) {
    final stock = formatQuantity(mentionedProduct.stock, product.unit);
    final unit = localizedUnit(localizations, product.unit);
    return AssistantReply(
      text: isFilipino
          ? '${product.name} ay may $stock $unit na stock. Walang recent na benta sa nakaraang 14 araw.'
          : '${product.name} has $stock $unit in stock. No recent sales in the last 14 days.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }
  final dailyMilliRate = soldMilli ~/ 14;
  if (dailyMilliRate == 0) {
    return AssistantReply(
      text: isFilipino
          ? '${product.name} ay halos hindi nabebenta. Hindi kayang i-forecast.'
          : '${product.name} barely sells. Cannot forecast.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }
  final daysLeft = mentionedProduct.stock.milli ~/ dailyMilliRate;
  return AssistantReply(
    text: isFilipino
        ? '${product.name}: mga $daysLeft araw bago maubos sa kasalukuyang bilis ng benta.'
        : '${product.name}: about $daysLeft days of stock left at current sales rate.',
    source: localizations.chatSourceInventory,
    mood: daysLeft <= 3 ? TindaAvatarMood.talking : TindaAvatarMood.happy,
  );
}

AssistantReply buildOverviewReply(
  List<StockedProduct> products,
  SalesSummary summary,
  List<CustomerBalance> balances,
  Currency currency,
  AppLocalizations localizations,
) {
  final lowCount = products.where((item) => item.isLowOnStock).length;
  final totalUtang = totalUnpaidUtang(balances, currency: currency);
  return AssistantReply(
    text: localizations.chatReplyOverview(
      formatMoney(summary.revenue),
      summary.saleCount,
      lowCount,
      formatMoney(totalUtang),
    ),
    source: localizations.chatSourceSummary,
    mood: summary.saleCount > 0
        ? TindaAvatarMood.happy
        : TindaAvatarMood.talking,
  );
}
