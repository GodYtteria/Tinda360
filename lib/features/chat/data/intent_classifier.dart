import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

final class IntentPrediction {
  const new({required this.toolName, required this.confidence});

  final String toolName;

  final double confidence;
}

final class IntentClassifier {
  const new _({
    required this.classes,
    required this.bias,
    required this.featureWeights,
    required this.normalizationPower,
  });

  factory fromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final rawFeatures = decoded['features'] as Map<String, dynamic>;
    return IntentClassifier._(
      classes: (decoded['classes'] as List<dynamic>).cast<String>(),
      bias: (decoded['bias'] as List<dynamic>)
          .map((value) => (value as num).toDouble())
          .toList(growable: false),
      featureWeights: <String, List<double>>{
        for (final entry in rawFeatures.entries)
          entry.key: (entry.value as List<dynamic>)
              .map((value) => (value as num).toDouble())
              .toList(growable: false),
      },
      normalizationPower: (decoded['normalization_power'] as num).toDouble(),
    );
  }

  static const String _defaultAssetPath = 'assets/ai/intent_model.json';
  static final RegExp _wordPattern = RegExp('[a-zñ0-9]+');
  static const List<int> _characterNgramSizes = <int>[3, 4];

  final List<String> classes;

  final List<double> bias;

  final Map<String, List<double>> featureWeights;

  final double normalizationPower;

  static Future<IntentClassifier> loadFromAsset() async =>
      IntentClassifier.fromJsonString(
        await rootBundle.loadString(_defaultAssetPath),
      );

  IntentPrediction classify(String text) {
    final features = _knownFeatures(text);
    final scale = features.isEmpty
        ? 1.0
        : 1.0 / math.pow(features.length, normalizationPower);
    final scores = List<double>.of(bias);
    for (final feature in features) {
      final weights = featureWeights[feature]!;
      for (var index = 0; index < scores.length; index++) {
        scores[index] += weights[index] * scale;
      }
    }
    final peak = scores.reduce(math.max);
    final exponentials = scores
        .map((score) => math.exp(score - peak))
        .toList(growable: false);
    final total = exponentials.reduce((first, second) => first + second);
    final bestIndex = exponentials.indexOf(exponentials.reduce(math.max));
    return IntentPrediction(
      toolName: classes[bestIndex],
      confidence: exponentials[bestIndex] / total,
    );
  }

  Set<String> _knownFeatures(String text) {
    final words = _wordPattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final features = <String>{
      for (final word in words) 'w:$word',
      for (var index = 0; index + 1 < words.length; index++)
        'b:${words[index]}_${words[index + 1]}',
    };
    for (final word in words) {
      final padded = '^$word\$';
      for (final size in _characterNgramSizes) {
        for (var start = 0; start + size <= padded.length; start++) {
          features.add('c:${padded.substring(start, start + size)}');
        }
      }
    }
    return features.where(featureWeights.containsKey).toSet();
  }
}
