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
}
