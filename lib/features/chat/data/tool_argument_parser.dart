final class ToolArgumentParser {
  const new();

  static const int _largestLimit = 50;
  static const int _smallestBudget = 100;
  static const int _smallestPhoneLikeNumber = 10000000;
  static const int _daysPerWeek = 7;
  static const int _daysPerMonth = 30;

  static const int _thousand = 1000;
  static const int _comparatorReach = 2;

  static final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final RegExp _thousandsSeparator = RegExp(r'(?<=\d),(?=\d{3}(?!\d))');
  static final RegExp _thousandsSuffix = RegExp(r'\b(\d+)(?:\.(\d+))?k\b');
  static final RegExp _decimalFraction = RegExp(r'(\d)\.\d+');

  static const Set<String> _numberConnectors = <String>{'t', 'at', 'and'};

  static const Set<String> _comparatorWords = <String>{
    'lampas',
    'higit',
    'mahigit',
    'over',
    'above',
    'below',
    'under',
    'mababa',
    'less',
    'more',
  };

  static const Set<String> _nonCountUnits = <String>{
    'porsyento',
    'porsiyento',
    'percent',
    'pesos',
    'piso',
    'php',
  };

  static const Map<String, int> _numberWords = <String, int>{
    'isa': 1,
    'isang': 1,
    'one': 1,
    'a': 1,
    'dalawa': 2,
    'dalawang': 2,
    'two': 2,
    'tatlo': 3,
    'tatlong': 3,
    'three': 3,
    'apat': 4,
    'four': 4,
    'lima': 5,
    'limang': 5,
    'five': 5,
    'anim': 6,
    'six': 6,
    'pito': 7,
    'pitong': 7,
    'seven': 7,
    'walo': 8,
    'walong': 8,
    'eight': 8,
    'siyam': 9,
    'nine': 9,
    'sampu': 10,
    'sampung': 10,
    'ten': 10,
    'bente': 20,
    'twenty': 20,
    'trenta': 30,
    'thirty': 30,
    'singkwenta': 50,
    'fifty': 50,
    'limandaan': 500,
    'limandaang': 500,
  };

  static const Map<String, int> _multipliers = <String, int>{
    'daan': 100,
    'hundred': 100,
    'libo': 1000,
    'libong': 1000,
    'thousand': 1000,
    'k': 1000,
  };

  static const Set<String> _standaloneMultipliers = <String>{
    'libo',
    'libong',
    'thousand',
  };

  static const Set<String> _singlePeriodWords = <String>{
    'this',
    'past',
    'last',
    'ngayong',
    'nitong',
    'nakaraang',
    'karong',
  };

  static const Set<String> _linkerWords = <String>{'na', 'ka'};

  static const Map<String, int> _periodAdjectives = <String, int>{
    'weekly': _daysPerWeek,
    'monthly': _daysPerMonth,
  };

  static const Map<String, int> _durationUnits = <String, int>{
    'araw': 1,
    'day': 1,
    'days': 1,
    'adlaw': 1,
    'linggo': _daysPerWeek,
    'week': _daysPerWeek,
    'weeks': _daysPerWeek,
    'semana': _daysPerWeek,
    'buwan': _daysPerMonth,
    'month': _daysPerMonth,
    'months': _daysPerMonth,
    'bulan': _daysPerMonth,
  };

  static const Set<String> _lowestMarginWords = <String>{
    'pinakamaliit',
    'pinakamababa',
    'pinakamababang',
    'walang',
    'pinakakaunting',
    'lowest',
    'worst',
    'thin',
    'bottom',
    'lugi',
    'gamay',
  };

  static const Set<String> _visitWords = <String>{
    'pinakamadalas',
    'madalas',
    'visits',
    'visit',
    'visitors',
    'frequent',
    'bumisita',
    'dumadaan',
    'bumabalik',
    'dalas',
    'comes',
  };

  static const Map<String, String> _durationArgumentNames = <String, String>{
    'get_utang_risk': 'days_overdue',
    'get_expiry_alerts': 'days_ahead',
    'get_slow_moving': 'days',
    'get_sales_trend': 'days',
  };

  Map<String, dynamic>? parse(
    String toolName,
    String query, {
    required String timeframe,
  }) {
    final tokens = _numericTokens(query);
    final arguments = switch (toolName) {
      'get_utang_list' => _single('min_balance', _firstAmount(tokens)),
      'get_low_stock' => _single('threshold', _firstAmount(tokens)),
      'get_restock_suggestions' => _restock(tokens),
      'get_top_products' => _topProducts(tokens, timeframe),
      'get_profit_margins' => _ranked(
        tokens,
        sortKey: 'sort',
        sortValue: _containsAny(tokens, _lowestMarginWords) ? 'lowest' : null,
        defaultSort: 'highest',
      ),
      'get_suki_loyalty' => _ranked(
        tokens,
        sortKey: 'sort_by',
        sortValue: _containsAny(tokens, _visitWords) ? 'visits' : null,
        defaultSort: 'spend',
      ),
      _ => _duration(toolName, tokens),
    };
    return arguments.isEmpty ? null : arguments;
  }

  String _normalizeDigits(String query) => query
      .toLowerCase()
      .replaceAll(_thousandsSeparator, '')
      .replaceAllMapped(_thousandsSuffix, (match) {
        final fraction = match.group(2) ?? '';
        final scaled = num.parse('${match.group(1)}.${fraction}0') * _thousand;
        return '${scaled.round()}';
      })
      .replaceAllMapped(_decimalFraction, (match) => match.group(1)!);

  List<Object> _numericTokens(String query) {
    final words = _normalizeDigits(
      query,
    ).split(_separators).where((word) => word.isNotEmpty);
    final tokens = <Object>[];
    int? lastScale;
    for (final word in words) {
      final multiplier = _multipliers[word];
      if (multiplier != null && tokens.isNotEmpty && tokens.last is int) {
        final last = tokens.last as int;
        final pending = lastScale == null ? last : last % lastScale;
        tokens[tokens.length - 1] =
            last - pending + (pending == 0 ? 1 : pending) * multiplier;
        lastScale = multiplier;
        continue;
      }
      if (multiplier != null && _standaloneMultipliers.contains(word)) {
        tokens.add(multiplier);
        lastScale = multiplier;
        continue;
      }
      if (lastScale != null && _numberConnectors.contains(word)) continue;
      final value = int.tryParse(word) ?? _numberWords[word];
      if (value != null && lastScale != null && value < lastScale) {
        tokens[tokens.length - 1] = (tokens.last as int) + value;
        continue;
      }
      lastScale = null;
      tokens.add(value ?? word);
    }
    return tokens;
  }

  bool _containsAny(List<Object> tokens, Set<String> words) =>
      tokens.any(words.contains);

  int? _durationDays(List<Object> tokens) {
    final words = tokens
        .where((token) => !_linkerWords.contains(token))
        .toList(growable: false);
    for (var index = 0; index < words.length; index++) {
      final adjectiveDays = _periodAdjectives[words[index]];
      if (adjectiveDays != null) return adjectiveDays;
      if (index + 1 >= words.length) continue;
      final unit = _durationUnits[words[index + 1]];
      if (unit == null) continue;
      final amount = words[index];
      if (amount is int) return amount * unit;
      if (unit > 1 && _singlePeriodWords.contains(amount)) return unit;
    }
    return null;
  }

  bool _isFollowedBy(List<Object> tokens, int index, Iterable<Object> words) =>
      index + 1 < tokens.length && words.contains(tokens[index + 1]);

  bool _followsComparator(List<Object> tokens, int index) {
    final start = index - _comparatorReach < 0 ? 0 : index - _comparatorReach;
    return tokens.sublist(start, index).any(_comparatorWords.contains);
  }

  int? _firstAmount(List<Object> tokens) {
    int? firstPlain;
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      if (token is! int || token >= _smallestPhoneLikeNumber) continue;
      if (_isFollowedBy(tokens, index, _durationUnits.keys)) continue;
      if (_followsComparator(tokens, index)) return token;
      final isArticle = index + 1 < tokens.length && tokens[index + 1] is! int;
      if (token == 1 && isArticle) continue;
      firstPlain ??= token;
    }
    return firstPlain;
  }

  int? _limit(List<Object> tokens) {
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      if (token is! int || token > _largestLimit) continue;
      if (_isFollowedBy(tokens, index, _nonCountUnits)) continue;
      final followsTop = index > 0 && tokens[index - 1] == 'top';
      final isDuration = _isFollowedBy(tokens, index, _durationUnits.keys);
      if (followsTop || (token > 1 && !isDuration)) return token;
    }
    return null;
  }

  Map<String, dynamic> _single(String name, int? value) =>
      value == null ? <String, dynamic>{} : <String, dynamic>{name: value};

  Map<String, dynamic> _duration(String toolName, List<Object> tokens) {
    final argumentName = _durationArgumentNames[toolName];
    if (argumentName == null) return <String, dynamic>{};
    return _single(argumentName, _durationDays(tokens));
  }

  Map<String, dynamic> _restock(List<Object> tokens) {
    final budget = tokens.whereType<int>().where(
      (amount) =>
          amount >= _smallestBudget && amount < _smallestPhoneLikeNumber,
    );
    final limit = _limit(tokens);
    return <String, dynamic>{
      if (budget.isNotEmpty) 'budget': budget.first,
      'limit': ?limit,
    };
  }

  Map<String, dynamic> _topProducts(List<Object> tokens, String timeframe) {
    final limit = _limit(tokens);
    if (limit == null) return <String, dynamic>{};
    return <String, dynamic>{'timeframe': timeframe, 'limit': limit};
  }

  Map<String, dynamic> _ranked(
    List<Object> tokens, {
    required String sortKey,
    required String? sortValue,
    required String defaultSort,
  }) {
    final limit = _limit(tokens);
    if (limit == null && sortValue == null) return <String, dynamic>{};
    return <String, dynamic>{
      sortKey: sortValue ?? defaultSort,
      'limit': ?limit,
    };
  }
}
