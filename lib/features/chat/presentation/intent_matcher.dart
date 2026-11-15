import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Recognized user intent for offline Tinda AI queries.
enum ChatIntent {
  /// Greeting such as "kumusta" or "hello".
  greeting,

  /// Appreciation such as "salamat" or "thank you".
  thanks,

  /// Asking what Tinda AI can answer.
  help,

  /// Best-selling / top products query.
  topProducts,

  /// Low-stock / restock / inventory query.
  lowStock,

  /// Utang / suki debt query.
  utang,

  /// Sales, revenue, or profit query.
  sales,

  /// Today vs yesterday sales comparison.
  salesCompare,

  /// Slow-moving / unsold products query.
  slowMoving,

  /// Specific product price/stock lookup.
  productLookup,

  /// Credit risk and cashflow warning query.
  utangRisk,

  /// Estimated restock (palengke) budget query.
  restockBudget,

  /// Fallback store overview.
  overview,
}

/// Timeframe extracted from a user's question.
enum QueryTimeframe {
  /// Current local day.
  today,

  /// Last 7 local days.
  week,

  /// Last 30 local days.
  month,
}

/// Parsed intent and timeframe for a normalized user message.
final class MatchedQuery {
  /// Creates a matched query result.
  const MatchedQuery({
    required this.intent,
    required this.timeframe,
    required this.normalizedText,
  });

  /// Highest-scoring intent.
  final ChatIntent intent;

  /// Timeframe requested (defaults to [QueryTimeframe.today]).
  final QueryTimeframe timeframe;

  /// Lowercased, shortcut-expanded text used for entity lookups.
  final String normalizedText;
}

/// Offline Filipino + English intent matcher driven by `assets/ai/intents.json`.
final class IntentMatcher {
  /// Creates a matcher from parsed configuration maps.
  const IntentMatcher({
    required this.shortcuts,
    required this.timeframes,
    required this.intents,
  });

  /// Pinoy text-speak shortcuts mapped to canonical words.
  final Map<String, String> shortcuts;

  /// Timeframe keyword lists keyed by `today`, `week`, `month`.
  final Map<String, List<String>> timeframes;

  /// Ordered intent keyword lists keyed by intent id.
  final Map<ChatIntent, List<String>> intents;

  static const String _defaultAssetPath = 'assets/ai/intents.json';

  /// Loads `assets/ai/intents.json`, falling back to built-in defaults if
  /// unavailable in a unit test environment.
  static Future<IntentMatcher> loadFromAsset() async {
    try {
      final rawJson = await rootBundle.loadString(_defaultAssetPath);
      return IntentMatcher.fromJsonString(rawJson);
    } on Exception {
      return IntentMatcher.fallback();
    }
  }

  /// Parses an [IntentMatcher] from JSON string [rawJson].
  factory IntentMatcher.fromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final rawShortcuts =
        decoded['shortcuts'] as Map<String, dynamic>? ?? const {};
    final shortcuts = <String, String>{
      for (final entry in rawShortcuts.entries)
        entry.key.toLowerCase(): entry.value.toString().toLowerCase(),
    };

    final rawTimeframes =
        decoded['timeframes'] as Map<String, dynamic>? ?? const {};
    final timeframes = <String, List<String>>{
      for (final entry in rawTimeframes.entries)
        entry.key: (entry.value as List<dynamic>)
            .map((item) => item.toString().toLowerCase())
            .toList(),
    };

    final rawIntents = decoded['intents'] as List<dynamic>? ?? const [];
    final intents = <ChatIntent, List<String>>{};
    for (final item in rawIntents) {
      final map = item as Map<String, dynamic>;
      final intentId = _parseIntent(map['id'] as String? ?? '');
      if (intentId == null) continue;
      final keywords = (map['keywords'] as List<dynamic>? ?? const [])
          .map((keyword) => keyword.toString().toLowerCase())
          .toList();
      intents[intentId] = keywords;
    }

    return IntentMatcher(
      shortcuts: shortcuts,
      timeframes: timeframes,
      intents: intents,
    );
  }

  /// Built-in fallback matcher mirroring `assets/ai/intents.json`.
  factory IntentMatcher.fallback() => const IntentMatcher(
    shortcuts: {
      'mgkano': 'magkano',
      'cno': 'sino',
      'ngaun': 'ngayon',
      'lng': 'lang',
      'bnta': 'benta',
      'utng': 'utang',
      'imbntryo': 'imbentaryo',
      'ty': 'thank you',
      'slmat': 'salamat',
    },
    timeframes: {
      'week': ['linggo', 'week', '7 days'],
      'month': ['buwan', 'month', '30 days'],
      'today': ['ngayon', 'today'],
    },
    intents: {
      ChatIntent.greeting: ['kumusta', 'kamusta', 'hello', 'hi'],
      ChatIntent.thanks: ['salamat', 'thank you', 'thanks'],
      ChatIntent.help: ['help', 'tulong', 'what can you do'],
      ChatIntent.topProducts: ['pinakamabenta', 'best seller', 'top 3', 'top product'],
      ChatIntent.lowStock: ['stock', 'low', 'mababa', 'imbentaryo', 'ubos', 'restock'],
      ChatIntent.utang: ['utang', 'suki', 'bayad', 'credit', 'owes'],
      ChatIntent.sales: ['sale', 'sales', 'benta', 'kita', 'tubo', 'profit', 'revenue'],
      ChatIntent.salesCompare: ['kahapon', 'yesterday', 'kumpara', 'compare', 'vs'],
      ChatIntent.slowMoving: ['matumal', 'dead stock', 'slow moving', 'hindi mabenta'],
      ChatIntent.productLookup: ['presyo', 'price', 'halaga'],
      ChatIntent.utangRisk: [
        'naluluge',
        'lugi',
        'pautang ba',
        'wag pautang',
        'delikado',
        'singilin muna',
        'credit risk',
        'cashflow',
        'risk',
      ],
      ChatIntent.restockBudget: [
        'palengke',
        'puhunan',
        'kapital',
        'restock budget',
        'magkano bibilhin',
        'budget sa paninda',
      ],
    },
  );

  /// Normalizes [rawInput] and returns the best matching intent + timeframe.
  MatchedQuery match(String rawInput) {
    final normalized = _normalize(rawInput);
    final words = normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    final timeframe = _detectTimeframe(normalized);

    var bestIntent = ChatIntent.overview;
    var bestScore = 0;

    for (final entry in intents.entries) {
      final score = _scoreKeywords(normalized, words, entry.value);
      if (score > bestScore) {
        bestScore = score;
        bestIntent = entry.key;
      }
    }

    return MatchedQuery(
      intent: bestIntent,
      timeframe: timeframe,
      normalizedText: normalized,
    );
  }

  String _normalize(String rawInput) {
    final cleaned = rawInput
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .map((token) => shortcuts[token] ?? token)
        .join(' ');
  }

  QueryTimeframe _detectTimeframe(String normalized) {
    for (final keyword in timeframes['week'] ?? const <String>[]) {
      if (normalized.contains(keyword)) return QueryTimeframe.week;
    }
    for (final keyword in timeframes['month'] ?? const <String>[]) {
      if (normalized.contains(keyword)) return QueryTimeframe.month;
    }
    return QueryTimeframe.today;
  }

  int _scoreKeywords(
    String normalized,
    List<String> words,
    List<String> keywords,
  ) {
    var score = 0;
    for (final keyword in keywords) {
      if (keyword.contains(' ')) {
        if (normalized.contains(keyword)) {
          score += 3;
        }
        continue;
      }
      if (words.contains(keyword)) {
        score += 2;
        continue;
      }
      if (keyword.length >= 4 &&
          words.any((word) => word.length >= 4 && _levenshtein(word, keyword) <= 1)) {
        score += 1;
      }
    }
    return score;
  }

  static ChatIntent? _parseIntent(String id) => switch (id) {
    'greeting' => ChatIntent.greeting,
    'thanks' => ChatIntent.thanks,
    'help' => ChatIntent.help,
    'top_products' => ChatIntent.topProducts,
    'low_stock' => ChatIntent.lowStock,
    'utang' => ChatIntent.utang,
    'sales' => ChatIntent.sales,
    'sales_compare' => ChatIntent.salesCompare,
    'slow_moving' => ChatIntent.slowMoving,
    'product_lookup' => ChatIntent.productLookup,
    'utang_risk' => ChatIntent.utangRisk,
    'restock_budget' => ChatIntent.restockBudget,
    _ => null,
  };

  static int _levenshtein(String first, String second) {
    if ((first.length - second.length).abs() > 1) return 2;
    var previous = List<int>.generate(second.length + 1, (index) => index);
    var current = List<int>.filled(second.length + 1, 0);

    for (var row = 1; row <= first.length; row++) {
      current[0] = row;
      for (var col = 1; col <= second.length; col++) {
        final cost = first[row - 1] == second[col - 1] ? 0 : 1;
        current[col] = math.min(
          math.min(current[col - 1] + 1, previous[col] + 1),
          previous[col - 1] + cost,
        );
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[second.length];
  }
}
