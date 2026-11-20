import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/intent_classifier.dart';

void main() {
  final classifier = IntentClassifier.fromJsonString(
    File('assets/ai/intent_model.json').readAsStringSync(),
  );
  final fixture = jsonDecode(
    File(
      'test/features/chat/intent_classifier_fixture.json',
    ).readAsStringSync(),
  ) as List<dynamic>;

  test('Dart classifier reproduces the Python predictions', () {
    for (final entry in fixture.cast<Map<String, dynamic>>()) {
      final prediction = classifier.classify(entry['query'] as String);
      expect(
        prediction.toolName,
        entry['tool'],
        reason: entry['query'] as String,
      );
      expect(
        prediction.confidence,
        closeTo((entry['confidence'] as num).toDouble(), 0.01),
        reason: entry['query'] as String,
      );
    }
  });

  test('empty and unknown text still returns a valid class', () {
    final empty = classifier.classify('');
    expect(classifier.classes, contains(empty.toolName));
    expect(empty.confidence, inInclusiveRange(0.0, 1.0));
    final gibberish = classifier.classify('zzzz qqqq xxxx');
    expect(classifier.classes, contains(gibberish.toolName));
  });

  test('probabilityFor matches the top prediction and sums to one', () {
    const query = 'sino ang may utang sa akin';
    final prediction = classifier.classify(query);
    expect(
      classifier.probabilityFor(query, prediction.toolName),
      closeTo(prediction.confidence, 1e-9),
    );
    final total = classifier.classes
        .map((toolName) => classifier.probabilityFor(query, toolName))
        .reduce((first, second) => first + second);
    expect(total, closeTo(1.0, 1e-6));
    expect(classifier.probabilityFor(query, 'not_a_tool'), 0.0);
  });
}
