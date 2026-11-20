import 'package:tinda360/features/chat/data/yumi_engine.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';

ChatClassification yumiResultToClassification(
  YumiInferResult result,
  String originalQuery,
) {
  final intent = toolNameToIntent(result.toolName);
  final timeframe = _argsToTimeframe(result.toolArgs);
  final rawProduct = result.toolArgs?['product_name'];
  final extractedProduct = rawProduct is String ? rawProduct : null;
  final normalizedText = extractedProduct != null
      ? '${originalQuery.toLowerCase()} ${extractedProduct.toLowerCase()}'
      : originalQuery.toLowerCase();
  return ChatClassification(
    matched: MatchedQuery(
      intent: intent,
      timeframe: timeframe,
      normalizedText: normalizedText,
    ),
    toolName: result.toolName,
    toolArgs: result.toolArgs,
  );
}

ChatIntent toolNameToIntent(String? toolName) => switch (toolName) {
  'get_sales_summary' => ChatIntent.sales,
  'get_top_products' => ChatIntent.topProducts,
  'get_product_info' => ChatIntent.productLookup,
  'get_low_stock' => ChatIntent.lowStock,
  'get_stock_forecast' => ChatIntent.stockForecast,
  'get_utang_list' => ChatIntent.utang,
  'get_utang_risk' => ChatIntent.utangRisk,
  'get_expenses' => ChatIntent.expenses,
  'get_expiry_alerts' => ChatIntent.expiryAlert,
  'get_slow_moving' => ChatIntent.slowMoving,
  'get_profit_margins' => ChatIntent.profitMargin,
  'get_sales_compare' => ChatIntent.salesCompare,
  'get_sales_trend' => ChatIntent.salesTrend,
  'get_busiest_hours' => ChatIntent.busiestHours,
  'get_suki_loyalty' => ChatIntent.sukiLoyalty,
  'get_payment_breakdown' => ChatIntent.paymentBreakdown,
  'get_store_info' => ChatIntent.storeInfo,
  'get_product_count' => ChatIntent.productCount,
  'get_restock_suggestions' => ChatIntent.restockBudget,
  _ => ChatIntent.overview,
};

QueryTimeframe _argsToTimeframe(Map<String, dynamic>? args) {
  return switch (args?['timeframe']) {
    'week' => QueryTimeframe.week,
    'month' => QueryTimeframe.month,
    _ => QueryTimeframe.today,
  };
}
