import 'package:meta/meta.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/customer_balance.dart';

enum ResolutionKind { single, ambiguous, none }

@immutable
final class EntityCandidate {
  const new({required this.id, required this.name});

  final String id;

  final String name;
}

@immutable
final class EntityResolution {
  const new({
    required this.kind,
    required this.mention,
    this.candidates = const <EntityCandidate>[],
  });

  final ResolutionKind kind;

  final String mention;

  final List<EntityCandidate> candidates;

  EntityCandidate? get single =>
      kind == ResolutionKind.single && candidates.isNotEmpty
      ? candidates.first
      : null;
}

@immutable
final class EntityResolver {
  const new();

  static const int maximumCandidates = 3;

  static const int _minimumPartialLetters = 3;

  static const String _wordSeparator = ' ';

  static const Map<String, String> _foldedCharacters = {
    'ñ': 'n',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };

  EntityResolution resolveProduct(String text, List<StockedProduct> products) =>
      _resolve(text, [
        for (final item in products)
          EntityCandidate(id: item.product.id, name: item.product.name),
      ]);

  EntityResolution resolveCustomer(
    String text,
    List<CustomerBalance> balances,
  ) => _resolve(text, [
    for (final item in balances)
      EntityCandidate(id: item.customer.id, name: item.customer.name),
  ]);

  EntityResolution _resolve(String text, List<EntityCandidate> entities) {
    final trimmed = text.trim();
    final queryTokens = _tokenize(text);
    if (queryTokens.isEmpty) {
      return EntityResolution(kind: ResolutionKind.none, mention: trimmed);
    }
    final matches = <_Match>[];
    for (final entity in entities) {
      final match = _bestMatch(text, queryTokens, entity);
      if (match != null) matches.add(match);
    }
    if (matches.isEmpty) {
      return EntityResolution(kind: ResolutionKind.none, mention: trimmed);
    }
    final hasFullName = matches.any((match) => match.isFullName);
    final pool = matches
        .where((match) => match.isFullName == hasFullName)
        .toList();
    final topScore = pool
        .map((match) => match.score)
        .reduce((left, right) => left > right ? left : right);
    final best = pool.where((match) => match.score == topScore).toList()
      ..sort(_compareMatches);
    final candidates = [
      for (final match in best.take(maximumCandidates)) match.entity,
    ];
    return EntityResolution(
      kind: best.length == 1 ? ResolutionKind.single : ResolutionKind.ambiguous,
      mention: best.first.mention,
      candidates: candidates,
    );
  }

  _Match? _bestMatch(
    String text,
    List<_Token> queryTokens,
    EntityCandidate entity,
  ) {
    final nameTokens = _tokenize(entity.name);
    if (nameTokens.isEmpty) return null;
    var bestRun = 0;
    var bestQueryStart = 0;
    for (var queryStart = 0; queryStart < queryTokens.length; queryStart++) {
      for (var nameStart = 0; nameStart < nameTokens.length; nameStart++) {
        var run = 0;
        while (queryStart + run < queryTokens.length &&
            nameStart + run < nameTokens.length &&
            queryTokens[queryStart + run].word ==
                nameTokens[nameStart + run].word) {
          run++;
        }
        if (run > bestRun) {
          bestRun = run;
          bestQueryStart = queryStart;
        }
      }
    }
    if (bestRun == 0) return null;
    final words = [
      for (var index = 0; index < bestRun; index++)
        queryTokens[bestQueryStart + index].word,
    ];
    final joined = words.join(_wordSeparator);
    final isFullName = bestRun == nameTokens.length;
    if (!isFullName && _countLetters(joined) < _minimumPartialLetters) {
      return null;
    }
    final mention = text.substring(
      queryTokens[bestQueryStart].start,
      queryTokens[bestQueryStart + bestRun - 1].end,
    );
    return _Match(
      entity: entity,
      mention: mention,
      score: joined.length,
      isFullName: isFullName,
    );
  }

  int _compareMatches(_Match left, _Match right) {
    final byName = left.entity.name.compareTo(right.entity.name);
    return byName != 0 ? byName : left.entity.id.compareTo(right.entity.id);
  }

  int _countLetters(String text) => _letterPattern.allMatches(text).length;

  List<_Token> _tokenize(String text) => [
    for (final match in _wordPattern.allMatches(text))
      _Token(
        word: foldAccents(match.group(0)!),
        start: match.start,
        end: match.end,
      ),
  ];

  static String foldAccents(String word) {
    final buffer = StringBuffer();
    for (final character in word.toLowerCase().split('')) {
      buffer.write(_foldedCharacters[character] ?? character);
    }
    return buffer.toString();
  }
}

final RegExp _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final RegExp _letterPattern = RegExp(r'\p{L}', unicode: true);

@immutable
final class _Token {
  const new({required this.word, required this.start, required this.end});

  final String word;
  final int start;
  final int end;
}

@immutable
final class _Match {
  const new({
    required this.entity,
    required this.mention,
    required this.score,
    required this.isFullName,
  });

  final EntityCandidate entity;
  final String mention;
  final int score;
  final bool isFullName;
}
