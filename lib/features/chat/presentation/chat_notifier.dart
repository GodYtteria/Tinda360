import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/chat/presentation/chat_store_replies.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';

enum ChatRole {
  user,

  assistant,
}

final class ChatMessage {
  const new({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.source,
  });

  final String id;

  final ChatRole role;

  final String text;

  final String? source;

  final DateTime createdAt;
}

final class ChatState {
  const new({
    required this.messages,
    required this.mood,
    required this.isThinking,
  });

  final List<ChatMessage> messages;

  final TindaAvatarMood mood;

  final bool isThinking;

  ChatState copyWith({
    List<ChatMessage>? messages,
    TindaAvatarMood? mood,
    bool? isThinking,
  }) => ChatState(
    messages: messages ?? this.messages,
    mood: mood ?? this.mood,
    isThinking: isThinking ?? this.isThinking,
  );
}

final NotifierProvider<ChatNotifier, ChatState> chatNotifierProvider =
    NotifierProvider.autoDispose<ChatNotifier, ChatState>(
      ChatNotifier.new,
    );

class ChatNotifier extends Notifier<ChatState> {
  Timer? _moodResetTimer;
  IntentMatcher? _matcher;
  int _sequence = 0;

  @override
  ChatState build() {
    ref.onDispose(() {
      _moodResetTimer?.cancel();
      _moodResetTimer = null;
    });
    return const ChatState(
      messages: <ChatMessage>[],
      mood: TindaAvatarMood.idle,
      isThinking: false,
    );
  }

  Future<void> sendMessage(
    String rawText,
    AppLocalizations localizations,
  ) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty || state.isThinking) return;

    _moodResetTimer?.cancel();
    final now = ref.read(clockProvider).now();
    final userMessage = ChatMessage(
      id: 'user_${++_sequence}',
      role: ChatRole.user,
      text: trimmed,
      createdAt: now,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      mood: TindaAvatarMood.thinking,
      isThinking: true,
    );

    final thinkingStarted = DateTime.now();
    _AssistantReply reply;
    try {
      reply = await _answerFromStoreData(trimmed, now, localizations);
    } on Exception catch (error, stack) {
      ref.read(appLogProvider).error('chat.answer', error, stack);
      reply = _AssistantReply(
        text: localizations.chatErrorReply,
        source: localizations.chatSourceSummary,
        mood: TindaAvatarMood.talking,
      );
    }
    final elapsed = DateTime.now().difference(thinkingStarted);
    const minimumThinking = Duration(milliseconds: 900);
    if (elapsed < minimumThinking) {
      await Future<void>.delayed(minimumThinking - elapsed);
    }
    if (!ref.mounted) return;

    final assistantMessage = ChatMessage(
      id: 'assistant_${++_sequence}',
      role: ChatRole.assistant,
      text: reply.text,
      source: reply.source,
      createdAt: ref.read(clockProvider).now(),
    );

    state = state.copyWith(
      messages: [...state.messages, assistantMessage],
      mood: reply.mood,
      isThinking: false,
    );

    _moodResetTimer = Timer(const Duration(milliseconds: 1800), () {
      state = state.copyWith(mood: TindaAvatarMood.idle);
    });
  }

  Future<_AssistantReply> _answerFromStoreData(
    String query,
    DateTime now,
    AppLocalizations localizations,
  ) async {
    final matcher = _matcher ??= await IntentMatcher.loadFromAsset();
    final matched = matcher.match(query);
    final isFilipino = localizations.localeName.startsWith('fil');

    if (matched.intent == ChatIntent.greeting) {
      final greeting = timeOfDayGreeting(now, isFilipino: isFilipino);
      return _AssistantReply(
        text: isFilipino
            ? '$greeting Handa akong tumulong sa benta, stock, at utang ng tindahan mo.'
            : '$greeting I am ready to help with your store sales, stock, and utang.',
        source: localizations.chatSourceSummary,
        mood: TindaAvatarMood.happy,
      );
    }
    if (matched.intent == ChatIntent.thanks) {
      return _AssistantReply(
        text: isFilipino
            ? 'Walang anuman! Sabihin mo lang kung may itatanong ka pa.'
            : 'You are welcome! Ask anytime if you need anything else.',
        source: localizations.chatSourceSummary,
        mood: TindaAvatarMood.happy,
      );
    }
    if (matched.intent == ChatIntent.help) {
      return _AssistantReply(
        text: isFilipino
            ? 'Pwede mong itanong: "Magkano benta ngayon?", "Ano pinakamabenta?", "Ano mababa ang stock?", "Sino may utang?", "Ano malapit mag-expire?", "Ano pinakamalaking tubo?", "Tumataas ba benta ko?", "Anong oras pinakamabenta?", "Sino laging bumibili?", "Ilan cash vs utang?", "Kailan mauubos ang X?", o pangalan ng produkto/suki.'
            : 'You can ask: "How are sales today?", "Top products?", "What is low on stock?", "Who has utang?", "What is expiring soon?", "Highest margin products?", "Are sales trending up?", "Busiest hours?", "Most loyal customers?", "Cash vs utang breakdown?", "When will X run out?", or a product/suki name.',
        source: localizations.chatSourceSummary,
        mood: TindaAvatarMood.talking,
      );
    }

    final currency = ref.read(storeCurrencyProvider);
    final today = LocalDay.fromLocal(now);
    final range = _rangeForTimeframe(matched.timeframe, today);

    final results = await Future.wait([
      ref.read(productRepositoryProvider).watchActive().first,
      ref.read(saleRepositoryProvider).watchSummary(range).first,
      ref.read(saleRepositoryProvider).watchTopProducts(range).first,
      ref.read(customerRepositoryProvider).watchBalances().first,
    ]);

    final products = results[0] as List<StockedProduct>;
    final summary = results[1] as SalesSummary;
    final topProducts = results[2] as List<TopProduct>;
    final balances = results[3] as List<CustomerBalance>;

    final matchedProduct = _findMentionedProduct(
      matched.normalizedText,
      products,
    );
    if (matchedProduct != null) {
      return _buildProductLookupReply(
        matchedProduct,
        isFilipino,
        localizations,
      );
    }

    final matchedCustomer = _findMentionedCustomer(
      matched.normalizedText,
      balances,
    );
    if (matchedCustomer != null) {
      return _buildCustomerLookupReply(
        matchedCustomer,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.salesCompare) {
      final todayRange = DayRange.single(today);
      final yesterdayRange = DayRange.single(today.plusDays(-1));
      final todaySummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(todayRange)
          .first;
      final yesterdaySummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(yesterdayRange)
          .first;
      return _buildSalesCompareReply(
        todaySummary,
        yesterdaySummary,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.slowMoving) {
      final twoWeeksRange = DayRange(today.plusDays(-13), today);
      final soldIds = await ref
          .read(saleRepositoryProvider)
          .soldProductIdsInRange(twoWeeksRange);
      return _buildSlowMovingReply(
        products,
        soldIds,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.utangRisk) {
      final expenses = await ref
          .read(expenseRepositoryProvider)
          .watchInRange(range)
          .first;
      return _buildUtangRiskReply(
        summary,
        balances,
        expenses,
        currency,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.storeInfo) {
      final storeProfile = await ref
          .read(storeProfileRepositoryProvider)
          .watch()
          .first;
      return _fromStoreReply(
        storeInfoReply(
          storeName: storeProfile.name,
          products: products,
          isFilipino: isFilipino,
        ),
        localizations,
      );
    }

    if (matched.intent == ChatIntent.productCount) {
      return _fromStoreReply(
        productCountReply(products: products, isFilipino: isFilipino),
        localizations,
      );
    }

    if (matched.intent == ChatIntent.expenses) {
      final expenses = await ref
          .read(expenseRepositoryProvider)
          .watchInRange(range)
          .first;
      return _fromStoreReply(
        expensesReply(
          expenses: expenses,
          summary: summary,
          periodLabel: _timeframeLabel(matched.timeframe, isFilipino),
          isFilipino: isFilipino,
        ),
        localizations,
      );
    }

    if (matched.intent == ChatIntent.expiryAlert) {
      return _buildExpiryAlertReply(products, today, isFilipino, localizations);
    }

    if (matched.intent == ChatIntent.profitMargin) {
      return _buildProfitMarginReply(products, isFilipino, localizations);
    }

    if (matched.intent == ChatIntent.salesTrend) {
      final todaySummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(DayRange.single(today))
          .first;
      final yesterdaySummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(DayRange.single(today.plusDays(-1)))
          .first;
      final twoDaysAgoSummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(DayRange.single(today.plusDays(-2)))
          .first;
      return _buildSalesTrendReply(
        todaySummary,
        yesterdaySummary,
        twoDaysAgoSummary,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.busiestHours) {
      final recentSales = await ref
          .read(saleRepositoryProvider)
          .watchRecentSales(range, limit: null)
          .first;
      return _buildBusiestHoursReply(
        recentSales,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.sukiLoyalty) {
      final recentSales = await ref
          .read(saleRepositoryProvider)
          .watchRecentSales(range, limit: null)
          .first;
      return _buildSukiLoyaltyReply(
        recentSales,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.paymentBreakdown) {
      final recentSales = await ref
          .read(saleRepositoryProvider)
          .watchRecentSales(range, limit: null)
          .first;
      return _buildPaymentBreakdownReply(
        recentSales,
        currency,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.stockForecast) {
      final mentionedProduct = _findMentionedProduct(
        matched.normalizedText,
        products,
      );
      final twoWeeksRange = DayRange(today.plusDays(-13), today);
      final soldQuantities = await ref
          .read(saleRepositoryProvider)
          .soldProductQuantitiesInRange(twoWeeksRange);
      return _buildStockForecastReply(
        mentionedProduct,
        products,
        soldQuantities,
        isFilipino,
        localizations,
      );
    }

    return switch (matched.intent) {
      ChatIntent.topProducts => _buildTopProductsReply(
        topProducts,
        matched.timeframe,
        isFilipino,
        localizations,
      ),
      ChatIntent.lowStock => _buildLowStockReply(products, localizations),
      ChatIntent.restockBudget => _buildRestockBudgetReply(
        products,
        currency,
        isFilipino,
        localizations,
      ),
      ChatIntent.utang => _buildUtangReply(balances, currency, localizations),
      ChatIntent.sales => _buildSalesReply(
        summary,
        matched.timeframe,
        isFilipino,
        localizations,
      ),
      ChatIntent.productLookup => _buildProductPromptReply(
        isFilipino,
        localizations,
      ),
      _ => _buildOverviewReply(
        products,
        summary,
        balances,
        currency,
        localizations,
      ),
    };
  }

  _AssistantReply _buildSalesCompareReply(
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
    return _AssistantReply(
      text: isFilipino
          ? 'Benta ngayon: $todayText (${todaySummary.saleCount} benta) vs kahapon: $yesterdayText (${yesterdaySummary.saleCount} benta). $trendText.'
          : 'Today: $todayText (${todaySummary.saleCount} sales) vs yesterday: $yesterdayText (${yesterdaySummary.saleCount} sales). $trendText.',
      source: localizations.chatSourceSales,
      mood: diffMinor >= 0 ? TindaAvatarMood.happy : TindaAvatarMood.talking,
    );
  }

  _AssistantReply _buildSlowMovingReply(
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
      return _AssistantReply(
        text: isFilipino
            ? 'Maganda! Lahat ng may stock na produkto ay nabenta sa nakaraang 14 araw.'
            : 'Great! All stocked products had sales in the last 14 days.',
        source: localizations.chatSourceInventory,
        mood: TindaAvatarMood.happy,
      );
    }
    return _AssistantReply(
      text: isFilipino
          ? 'Walang benta sa nakaraang 14 araw: ${slowItems.join(', ')}.'
          : 'No sales in the last 14 days: ${slowItems.join(', ')}.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }

  _AssistantReply _buildProductPromptReply(
    bool isFilipino,
    AppLocalizations localizations,
  ) => _AssistantReply(
    text: isFilipino
        ? 'Pakilagay ang pangalan ng produkto (hal. "Magkano Pancit Canton?").'
        : 'Include the product name (e.g. "Price of Pancit Canton?").',
    source: localizations.chatSourceInventory,
    mood: TindaAvatarMood.talking,
  );

  DayRange _rangeForTimeframe(QueryTimeframe timeframe, LocalDay today) =>
      switch (timeframe) {
        QueryTimeframe.today => DayRange.single(today),
        QueryTimeframe.week => DayRange(today.plusDays(-6), today),
        QueryTimeframe.month => DayRange(today.plusDays(-29), today),
      };

  StockedProduct? _findMentionedProduct(
    String normalized,
    List<StockedProduct> products,
  ) {
    for (final item in products) {
      final name = item.product.name.toLowerCase().trim();
      if (name.length >= 3 && normalized.contains(name)) {
        return item;
      }
    }
    return null;
  }

  CustomerBalance? _findMentionedCustomer(
    String normalized,
    List<CustomerBalance> balances,
  ) {
    for (final item in balances) {
      final name = item.customer.name.toLowerCase().trim();
      if (name.length >= 3 && normalized.contains(name)) {
        return item;
      }
    }
    return null;
  }

  _AssistantReply _buildProductLookupReply(
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
    return _AssistantReply(
      text: isFilipino
          ? '${product.name}: $price bawat $unit. $stockText$utangText'
          : '${product.name}: $price per $unit. $stockText$utangText',
      source: localizations.chatSourceInventory,
      mood: product.tracksStock && item.isLowOnStock
          ? TindaAvatarMood.talking
          : TindaAvatarMood.happy,
    );
  }

  _AssistantReply _buildCustomerLookupReply(
    CustomerBalance item,
    bool isFilipino,
    AppLocalizations localizations,
  ) {
    final balance = formatMoney(item.balance);
    return _AssistantReply(
      text: isFilipino
          ? 'Si ${item.customer.name} ay may balanseng utang na $balance.'
          : '${item.customer.name} has an utang balance of $balance.',
      source: localizations.chatSourceUtang,
      mood: item.owes ? TindaAvatarMood.talking : TindaAvatarMood.happy,
    );
  }

  _AssistantReply _buildTopProductsReply(
    List<TopProduct> topProducts,
    QueryTimeframe timeframe,
    bool isFilipino,
    AppLocalizations localizations,
  ) {
    if (topProducts.isEmpty) {
      return _AssistantReply(
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
    final periodWord = _timeframeLabel(timeframe, isFilipino);
    return _AssistantReply(
      text: isFilipino
          ? 'Pinakamabenta ($periodWord): $summaryText.'
          : 'Top selling ($periodWord): $summaryText.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.happy,
    );
  }

  _AssistantReply _buildSalesReply(
    SalesSummary summary,
    QueryTimeframe timeframe,
    bool isFilipino,
    AppLocalizations localizations,
  ) {
    if (timeframe == QueryTimeframe.today) {
      if (summary.saleCount == 0) {
        return _AssistantReply(
          text: localizations.chatReplySalesEmpty,
          source: localizations.chatSourceSales,
          mood: TindaAvatarMood.talking,
        );
      }
      return _AssistantReply(
        text: localizations.chatReplySalesSummary(
          summary.saleCount,
          formatMoney(summary.revenue),
          formatMoney(summary.profit),
        ),
        source: localizations.chatSourceSales,
        mood: TindaAvatarMood.happy,
      );
    }
    final periodWord = _timeframeLabel(timeframe, isFilipino);
    final revenue = formatMoney(summary.revenue);
    final profit = formatMoney(summary.profit);
    return _AssistantReply(
      text: isFilipino
          ? 'Sa $periodWord ay may ${summary.saleCount} na benta: $revenue ang kabuuang benta at $profit ang tubo.'
          : 'For $periodWord there are ${summary.saleCount} sales: $revenue total revenue and $profit profit.',
      source: localizations.chatSourceSales,
      mood: summary.saleCount > 0
          ? TindaAvatarMood.happy
          : TindaAvatarMood.talking,
    );
  }

  String _timeframeLabel(QueryTimeframe timeframe, bool isFilipino) =>
      switch (timeframe) {
        QueryTimeframe.today => isFilipino ? 'ngayon' : 'today',
        QueryTimeframe.week => isFilipino ? 'nakaraang 7 araw' : 'last 7 days',
        QueryTimeframe.month =>
          isFilipino ? 'nakaraang 30 araw' : 'last 30 days',
      };

  _AssistantReply _buildLowStockReply(
    List<StockedProduct> products,
    AppLocalizations localizations,
  ) {
    final lowItems = products.where((item) => item.isLowOnStock).toList();
    if (lowItems.isEmpty) {
      return _AssistantReply(
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
    return _AssistantReply(
      text: localizations.chatReplyLowStockFound(lowItems.length, names),
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }

  _AssistantReply _buildUtangReply(
    List<CustomerBalance> balances,
    Currency currency,
    AppLocalizations localizations,
  ) {
    final debtors = balances.where((item) => item.owes).toList();
    if (debtors.isEmpty) {
      return _AssistantReply(
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
    return _AssistantReply(
      text: localizations.chatReplyUtangSummary(
        formatMoney(total),
        debtors.length,
        topNames,
      ),
      source: localizations.chatSourceUtang,
      mood: TindaAvatarMood.talking,
    );
  }

  _AssistantReply _buildUtangRiskReply(
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
      return _AssistantReply(
        text: isFilipino
            ? 'Babala: May $unpaidText pang hindi nababayarang utang / negatibo ang netong kita ($netIncomeText). Iwasan muna ang bagong pautang at maningil muna.'
            : 'Warning: $unpaidText in unpaid utang with net income of $netIncomeText. Hold off on new utang and collect payments first.',
        source: localizations.chatSourceUtang,
        mood: TindaAvatarMood.talking,
      );
    }

    return _AssistantReply(
      text: isFilipino
          ? 'Maayos ang cashflow! Netong kita: $netIncomeText, hindi pa nababayarang utang: $unpaidText. Ligtas magpautang nang may ingat.'
          : 'Cashflow is healthy! Net income: $netIncomeText, unpaid utang: $unpaidText. Safe to extend credit carefully.',
      source: localizations.chatSourceUtang,
      mood: TindaAvatarMood.happy,
    );
  }

  _AssistantReply _buildRestockBudgetReply(
    List<StockedProduct> products,
    Currency currency,
    bool isFilipino,
    AppLocalizations localizations,
  ) {
    final lowStockProducts = products
        .where((stockedProduct) => stockedProduct.isLowOnStock)
        .toList();
    if (lowStockProducts.isEmpty) {
      return _AssistantReply(
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
    return _AssistantReply(
      text: isFilipino
          ? 'Tinatayang puhunan sa palengke: $budgetText para sa $itemCount produkto na mababa ang stock.'
          : 'Estimated restock budget: $budgetText for $itemCount low-stock items.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }

  _AssistantReply _buildExpiryAlertReply(
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
          alerts.add(isFilipino
              ? '${item.product.name} (EXPIRED na)'
              : '${item.product.name} (EXPIRED)');
        case ExpiryNear(:final daysLeft):
          alerts.add(isFilipino
              ? '${item.product.name} ($daysLeft araw na lang)'
              : '${item.product.name} ($daysLeft days left)');
      }
    }
    if (alerts.isEmpty) {
      return _AssistantReply(
        text: isFilipino
            ? 'Walang produkto na malapit mag-expire o expired na.'
            : 'No products are expiring soon or already expired.',
        source: localizations.chatSourceInventory,
        mood: TindaAvatarMood.happy,
      );
    }
    return _AssistantReply(
      text: isFilipino
          ? 'Mga produkto na mag-e-expire o expired na: ${alerts.join(', ')}.'
          : 'Products expiring or expired: ${alerts.join(', ')}.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.talking,
    );
  }

  _AssistantReply _buildProfitMarginReply(
    List<StockedProduct> products,
    bool isFilipino,
    AppLocalizations localizations,
  ) {
    final withMargin = products
        .where((item) => item.product.price.minorUnits > 0)
        .toList()
      ..sort(
        (first, second) =>
            (second.product.price.minorUnits - second.product.cost.minorUnits)
                .compareTo(
              first.product.price.minorUnits - first.product.cost.minorUnits,
            ),
      );
    if (withMargin.isEmpty) {
      return _AssistantReply(
        text: isFilipino
            ? 'Walang produkto na may presyo pa.'
            : 'No products with pricing found.',
        source: localizations.chatSourceInventory,
        mood: TindaAvatarMood.talking,
      );
    }
    final top = withMargin.take(3).map((item) {
      final margin = Money(
        item.product.price.minorUnits - item.product.cost.minorUnits,
        item.product.price.currency,
      );
      return '${item.product.name} (${formatMoney(margin)})';
    }).join(', ');
    return _AssistantReply(
      text: isFilipino
          ? 'Pinakamalaking tubo bawat benta: $top.'
          : 'Highest profit margin per sale: $top.',
      source: localizations.chatSourceInventory,
      mood: TindaAvatarMood.happy,
    );
  }

  _AssistantReply _buildSalesTrendReply(
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
    return _AssistantReply(
      text: isFilipino
          ? '$trendWord ang trend. 2 araw na nakalipas: $twoDaysAgoText → kahapon: $yesterdayText → ngayon: $todayText.'
          : '$trendWord trend. 2 days ago: $twoDaysAgoText → yesterday: $yesterdayText → today: $todayText.',
      source: localizations.chatSourceSales,
      mood: trendWord == (isFilipino ? 'Pataas' : 'Up')
          ? TindaAvatarMood.happy
          : TindaAvatarMood.talking,
    );
  }

  _AssistantReply _buildBusiestHoursReply(
    List<SaleRecord> sales,
    bool isFilipino,
    AppLocalizations localizations,
  ) {
    if (sales.isEmpty) {
      return _AssistantReply(
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
    final top = sorted.take(3).map((entry) {
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
    }).join(', ');
    return _AssistantReply(
      text: isFilipino
          ? 'Pinakamabentang oras: $top.'
          : 'Busiest hours: $top.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.happy,
    );
  }

  _AssistantReply _buildSukiLoyaltyReply(
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
      return _AssistantReply(
        text: isFilipino
            ? 'Walang may pangalang suki sa mga benta sa panahong ito.'
            : 'No named customers in sales for this period.',
        source: localizations.chatSourceSales,
        mood: TindaAvatarMood.talking,
      );
    }
    final sorted = customerCounts.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    final top = sorted.take(3).map((entry) {
      return isFilipino
          ? '${entry.key} (${entry.value} benta)'
          : '${entry.key} (${entry.value} sales)';
    }).join(', ');
    return _AssistantReply(
      text: isFilipino
          ? 'Pinaka-loyal na suki: $top.'
          : 'Most frequent buyers: $top.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.happy,
    );
  }

  _AssistantReply _buildPaymentBreakdownReply(
    List<SaleRecord> sales,
    Currency currency,
    bool isFilipino,
    AppLocalizations localizations,
  ) {
    if (sales.isEmpty) {
      return _AssistantReply(
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
          (totals[sale.method] ?? Money.zero(currency)) + sale.total;
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
    return _AssistantReply(
      text: isFilipino
          ? 'Breakdown ng bayad: ${parts.join(', ')}.'
          : 'Payment breakdown: ${parts.join(', ')}.',
      source: localizations.chatSourceSales,
      mood: TindaAvatarMood.happy,
    );
  }

  _AssistantReply _buildStockForecastReply(
    StockedProduct? mentionedProduct,
    List<StockedProduct> products,
    Map<String, int> soldQuantities,
    bool isFilipino,
    AppLocalizations localizations,
  ) {
    if (mentionedProduct == null) {
      return _AssistantReply(
        text: isFilipino
            ? 'Pakilagay ang pangalan ng produkto (hal. "Kailan mauubos ang Bigas?").'
            : 'Include the product name (e.g. "When will Rice run out?").',
        source: localizations.chatSourceInventory,
        mood: TindaAvatarMood.talking,
      );
    }
    final product = mentionedProduct.product;
    if (!product.tracksStock) {
      return _AssistantReply(
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
      return _AssistantReply(
        text: isFilipino
            ? '${product.name} ay may $stock $unit na stock. Walang recent na benta sa nakaraang 14 araw.'
            : '${product.name} has $stock $unit in stock. No recent sales in the last 14 days.',
        source: localizations.chatSourceInventory,
        mood: TindaAvatarMood.talking,
      );
    }
    final dailyMilliRate = soldMilli ~/ 14;
    if (dailyMilliRate == 0) {
      return _AssistantReply(
        text: isFilipino
            ? '${product.name} ay halos hindi nabebenta. Hindi kayang i-forecast.'
            : '${product.name} barely sells. Cannot forecast.',
        source: localizations.chatSourceInventory,
        mood: TindaAvatarMood.talking,
      );
    }
    final daysLeft = mentionedProduct.stock.milli ~/ dailyMilliRate;
    return _AssistantReply(
      text: isFilipino
          ? '${product.name}: mga $daysLeft araw bago maubos sa kasalukuyang bilis ng benta.'
          : '${product.name}: about $daysLeft days of stock left at current sales rate.',
      source: localizations.chatSourceInventory,
      mood: daysLeft <= 3 ? TindaAvatarMood.talking : TindaAvatarMood.happy,
    );
  }

  _AssistantReply _fromStoreReply(
    StoreReplyText storeReply,
    AppLocalizations localizations,
  ) => _AssistantReply(
    text: storeReply.text,
    source: localizations.chatSourceSummary,
    mood: storeReply.mood,
  );

  _AssistantReply _buildOverviewReply(
    List<StockedProduct> products,
    SalesSummary summary,
    List<CustomerBalance> balances,
    Currency currency,
    AppLocalizations localizations,
  ) {
    final lowCount = products.where((item) => item.isLowOnStock).length;
    final totalUtang = totalUnpaidUtang(balances, currency: currency);
    return _AssistantReply(
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
}

final class _AssistantReply {
  const new({
    required this.text,
    required this.source,
    required this.mood,
  });

  final String text;
  final String source;
  final TindaAvatarMood mood;
}
