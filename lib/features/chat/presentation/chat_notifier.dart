import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/calendar/time_greeting.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';

/// Author of a chat message.
enum ChatRole {
  /// Message sent by the store owner.
  user,

  /// Response generated on-device by Tinda AI.
  assistant,
}

/// A single message in the Tinda AI conversation.
final class ChatMessage {
  /// Creates a chat message.
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.source,
  });

  /// Unique message identifier.
  final String id;

  /// Sender role.
  final ChatRole role;

  /// Message body.
  final String text;

  /// Data source label shown under assistant replies.
  final String? source;

  /// Local timestamp when the message was created.
  final DateTime createdAt;
}

/// Immutable state for the Tinda AI chat sheet.
final class ChatState {
  /// Creates a chat state.
  const ChatState({
    required this.messages,
    required this.mood,
    required this.isThinking,
  });

  /// Ordered conversation history.
  final List<ChatMessage> messages;

  /// Current Tinda AI avatar expression.
  final TindaAvatarMood mood;

  /// True while querying on-device store data.
  final bool isThinking;

  /// Returns a copy with updated fields.
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

/// Riverpod provider for the offline Tinda AI chat assistant.
final chatNotifierProvider = NotifierProvider.autoDispose<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

/// Manages chat history, offline store queries, and avatar mood transitions.
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

  /// Sends [rawText] and generates an offline answer from live store data.
  Future<void> sendMessage(String rawText, AppLocalizations localizations) async {
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

    _AssistantReply reply;
    try {
      reply = await _answerFromStoreData(trimmed, now, localizations);
    } on Exception {
      reply = _AssistantReply(
        text: localizations.chatErrorReply,
        source: localizations.chatSourceSummary,
        mood: TindaAvatarMood.talking,
      );
    }

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
            ? 'Pwede mong itanong: "Magkano benta ngayon?", "Ano pinakamabenta?", "Ano mababa ang stock?", "Sino may utang?", o pangalan ng produkto/suki.'
            : 'You can ask: "How are sales today?", "Top products?", "What is low on stock?", "Who has utang?", or a product/suki name.',
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
      return _buildProductLookupReply(matchedProduct, isFilipino, localizations);
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
      final todaySummary =
          await ref.read(saleRepositoryProvider).watchSummary(todayRange).first;
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
  ) =>
      _AssistantReply(
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
    return _AssistantReply(
      text: isFilipino
          ? '${product.name}: $price bawat $unit. Natitirang stock: $stock $unit.'
          : '${product.name}: $price per $unit. Remaining stock: $stock $unit.',
      source: localizations.chatSourceInventory,
      mood: item.isLowOnStock ? TindaAvatarMood.talking : TindaAvatarMood.happy,
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
        QueryTimeframe.month => isFilipino ? 'nakaraang 30 araw' : 'last 30 days',
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
    final total = debtors.fold(
      Money.zero(currency),
      (sum, item) => sum + item.balance,
    );
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
    final totalUnpaidUtang = balances
        .where((customerBalance) => customerBalance.owes)
        .fold(Money.zero(currency), (total, entry) => total + entry.balance);

    final utangExceedsThirtyPercent = summary.revenue.isPositive
        ? totalUnpaidUtang.minorUnits * 100 > summary.revenue.minorUnits * 30
        : totalUnpaidUtang.isPositive;
    final hasRisk = netIncome.isNegative || utangExceedsThirtyPercent;

    final unpaidText = formatMoney(totalUnpaidUtang);
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

  _AssistantReply _buildOverviewReply(
    List<StockedProduct> products,
    SalesSummary summary,
    List<CustomerBalance> balances,
    Currency currency,
    AppLocalizations localizations,
  ) {
    final lowCount = products.where((item) => item.isLowOnStock).length;
    final totalUtang = balances.fold(
      Money.zero(currency),
      (sum, item) => sum + item.balance,
    );
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
  const _AssistantReply({
    required this.text,
    required this.source,
    required this.mood,
  });

  final String text;
  final String source;
  final TindaAvatarMood mood;
}
