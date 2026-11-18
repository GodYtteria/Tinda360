import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';

void main() {
  final jsonContent = File('assets/ai/intents.json').readAsStringSync();
  final matcher = IntentMatcher.fromJsonString(jsonContent);

  test('normalizes Pinoy text shortcuts for sales queries', () {
    final result = matcher.match('mgkano bnta ngaun?');
    expect(result.intent, ChatIntent.sales);
    expect(result.timeframe, QueryTimeframe.today);
  });

  test('detects week and month timeframes in English and Filipino', () {
    final week = matcher.match('how are sales this week?');
    expect(week.intent, ChatIntent.sales);
    expect(week.timeframe, QueryTimeframe.week);

    final month = matcher.match('ano pinakamabenta ngayong buwan?');
    expect(month.intent, ChatIntent.topProducts);
    expect(month.timeframe, QueryTimeframe.month);
  });

  test('matches typos via Levenshtein tolerance', () {
    expect(matcher.match('cno may utng?').intent, ChatIntent.utang);
    expect(matcher.match('check imbntryo').intent, ChatIntent.lowStock);
    expect(matcher.match('ano mababa stock').intent, ChatIntent.lowStock);
  });

  test('matches greetings, thanks, and help intents', () {
    expect(matcher.match('Kumusta!').intent, ChatIntent.greeting);
    expect(matcher.match('slmat!').intent, ChatIntent.thanks);
    expect(matcher.match('what can you do?').intent, ChatIntent.help);
  });

  test('matches salesCompare, slowMoving, and productLookup intents', () {
    expect(
      matcher.match('kumusta benta vs kahapon?').intent,
      ChatIntent.salesCompare,
    );
    expect(
      matcher.match('ano mga matumal o hindi mabenta?').intent,
      ChatIntent.slowMoving,
    );
    expect(
      matcher.match('ano presyo ng kape?').intent,
      ChatIntent.productLookup,
    );
  });

  test('matches utangRisk and restockBudget intents', () {
    expect(
      matcher.match('naluluge ba ako, wag pautang muna?').intent,
      ChatIntent.utangRisk,
    );
    expect(
      matcher.match('credit risk sa cashflow?').intent,
      ChatIntent.utangRisk,
    );
    expect(
      matcher.match('magkano puhunan sa palengke?').intent,
      ChatIntent.restockBudget,
    );
    expect(
      matcher.match('magkano restock budget sa paninda?').intent,
      ChatIntent.restockBudget,
    );
  });

  test('matches expiryAlert intent in Filipino and English', () {
    expect(
      matcher.match('ano malapit mag expire?').intent,
      ChatIntent.expiryAlert,
    );
    expect(
      matcher.match('what is expiring soon?').intent,
      ChatIntent.expiryAlert,
    );
    expect(
      matcher.match('expired na ba may produkto?').intent,
      ChatIntent.expiryAlert,
    );
  });

  test('matches profitMargin intent in Filipino and English', () {
    expect(
      matcher.match('ano pinakamalaking tubo?').intent,
      ChatIntent.profitMargin,
    );
    expect(
      matcher.match('which has highest margin?').intent,
      ChatIntent.profitMargin,
    );
    expect(
      matcher.match('most profitable product?').intent,
      ChatIntent.profitMargin,
    );
  });

  test('matches salesTrend intent in Filipino and English', () {
    expect(
      matcher.match('tumataas ba benta ko?').intent,
      ChatIntent.salesTrend,
    );
    expect(
      matcher.match('is my sales trend going up?').intent,
      ChatIntent.salesTrend,
    );
  });

  test('matches busiestHours intent in Filipino and English', () {
    expect(
      matcher.match('anong oras pinakamabenta?').intent,
      ChatIntent.busiestHours,
    );
    expect(
      matcher.match('what are my busiest hours?').intent,
      ChatIntent.busiestHours,
    );
    expect(
      matcher.match('peak hours ng benta?').intent,
      ChatIntent.busiestHours,
    );
  });

  test('matches sukiLoyalty intent in Filipino and English', () {
    expect(
      matcher.match('sino laging bumibili?').intent,
      ChatIntent.sukiLoyalty,
    );
    expect(
      matcher.match('who are my most frequent buyers?').intent,
      ChatIntent.sukiLoyalty,
    );
    expect(
      matcher.match('top suki ko?').intent,
      ChatIntent.sukiLoyalty,
    );
  });

  test('matches paymentBreakdown intent in Filipino and English', () {
    expect(
      matcher.match('ilan cash vs utang?').intent,
      ChatIntent.paymentBreakdown,
    );
    expect(
      matcher.match('payment breakdown ng benta?').intent,
      ChatIntent.paymentBreakdown,
    );
    expect(
      matcher.match('breakdown ng bayad?').intent,
      ChatIntent.paymentBreakdown,
    );
  });

  test('matches stockForecast intent in Filipino and English', () {
    expect(
      matcher.match('gaano katagal matatagal ang bigas?').intent,
      ChatIntent.stockForecast,
    );
    expect(
      matcher.match('how long will it last?').intent,
      ChatIntent.stockForecast,
    );
    expect(
      matcher.match('ilang araw bago maubos supply?').intent,
      ChatIntent.stockForecast,
    );
  });
}
