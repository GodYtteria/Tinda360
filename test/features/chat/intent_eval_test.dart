import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';

const double _minimumOverallAccuracy = 0.90;
const double _minimumIntentAccuracy = 0.80;
const int _minimumExamplesPerIntent = 30;
const int _minimumTotalExamples = 600;
const String _intentsPath = 'assets/ai/intents.json';
const String _evalSetPath = 'test/fixtures/ai/chat_eval_set.json';

const Map<String, ChatIntent> _intentsById = {
  'greeting': ChatIntent.greeting,
  'thanks': ChatIntent.thanks,
  'help': ChatIntent.help,
  'top_products': ChatIntent.topProducts,
  'low_stock': ChatIntent.lowStock,
  'utang': ChatIntent.utang,
  'sales': ChatIntent.sales,
  'sales_compare': ChatIntent.salesCompare,
  'slow_moving': ChatIntent.slowMoving,
  'product_lookup': ChatIntent.productLookup,
  'utang_risk': ChatIntent.utangRisk,
  'restock_budget': ChatIntent.restockBudget,
  'store_info': ChatIntent.storeInfo,
  'product_count': ChatIntent.productCount,
  'expenses': ChatIntent.expenses,
};

void main() {
  final matcher = IntentMatcher.fromJsonString(
    File(_intentsPath).readAsStringSync(),
  );
  final evalSet = (jsonDecode(
    File(_evalSetPath).readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();

  test('eval set covers every intent with enough examples', () {
    final countsById = <String, int>{};
    for (final example in evalSet) {
      final id = example['intent'] as String;
      expect(_intentsById.containsKey(id), isTrue, reason: 'unknown id $id');
      countsById[id] = (countsById[id] ?? 0) + 1;
    }
    expect(evalSet.length, greaterThanOrEqualTo(_minimumTotalExamples));
    for (final id in _intentsById.keys) {
      expect(
        countsById[id] ?? 0,
        greaterThanOrEqualTo(_minimumExamplesPerIntent),
        reason: 'too few examples for $id',
      );
    }
  });

  test('intent accuracy on the labeled eval set meets the bar', () {
    final totalsById = <String, int>{
      for (final id in _intentsById.keys) id: 0,
    };
    final correctById = <String, int>{
      for (final id in _intentsById.keys) id: 0,
    };
    final misclassified = <String>[];

    for (final example in evalSet) {
      final text = example['text'] as String;
      final expectedId = example['intent'] as String;
      final actual = matcher.match(text).intent;
      totalsById[expectedId] = totalsById[expectedId]! + 1;
      if (actual == _intentsById[expectedId]) {
        correctById[expectedId] = correctById[expectedId]! + 1;
      } else {
        misclassified.add('[$expectedId -> ${actual.name}] $text');
      }
    }

    final totalCorrect = correctById.values.fold<int>(
      0,
      (runningTotal, correctCount) => runningTotal + correctCount,
    );
    final overallAccuracy = totalCorrect / evalSet.length;
    final report = StringBuffer()
      ..writeln('intent             correct/total  accuracy');
    final failingIntents = <String>[];
    for (final id in _intentsById.keys) {
      final accuracy = correctById[id]! / totalsById[id]!;
      if (accuracy < _minimumIntentAccuracy) failingIntents.add(id);
      report.writeln(
        '${id.padRight(18)} '
        '${'${correctById[id]}/${totalsById[id]}'.padRight(14)} '
        '${(accuracy * 100).toStringAsFixed(1)}%',
      );
    }
    report.writeln(
      'overall            $totalCorrect/${evalSet.length}'
      '${' ' * 6}${(overallAccuracy * 100).toStringAsFixed(1)}%',
    );
    final failed =
        overallAccuracy < _minimumOverallAccuracy || failingIntents.isNotEmpty;
    if (failed) {
      report
        ..writeln('misclassified examples:')
        ..writeAll(misclassified, '\n');
    }
    stdout.writeln(report);

    expect(
      overallAccuracy,
      greaterThanOrEqualTo(_minimumOverallAccuracy),
      reason: report.toString(),
    );
    expect(failingIntents, isEmpty, reason: report.toString());
  });
}
