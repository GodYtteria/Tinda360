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
}
