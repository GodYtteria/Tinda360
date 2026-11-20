final class FeedbackRedactor {
  const new();

  static const String customerPlaceholder = '<CUSTOMER>';
  static const String productPlaceholder = '<PRODUCT>';
  static const String numberPlaceholder = '<NUMBER>';

  static const int _minimumNameLength = 2;
  static const int _minimumNameWordLength = 3;
  static const int _minimumNumberDigits = 7;

  static const String _wordCharacter = r'\p{L}\p{N}\p{M}';

  static const Set<String> _honorifics = <String>{
    'aling',
    'mang',
    'ate',
    'kuya',
    'nanay',
    'tatay',
    'lola',
    'lolo',
    'tita',
    'tito',
    'sir',
    'maam',
    'mam',
    'mrs',
    'mr',
    'ms',
    'boss',
    'kap',
    'kapitan',
    'mare',
    'pare',
  };

  static final RegExp _nameSeparators = RegExp(
    '[^$_wordCharacter]+',
    unicode: true,
  );
  static final RegExp _digitGroupSeparators = RegExp(r'[ \-]');
  static final RegExp _numberRun = RegExp(
    r'\p{Nd}+(?:[ \-]\p{Nd}+)*',
    unicode: true,
  );
  static final String _existingPlaceholders =
      '${RegExp.escape(customerPlaceholder)}'
      '|${RegExp.escape(productPlaceholder)}'
      '|${RegExp.escape(numberPlaceholder)}';

  String redact(
    String text, {
    required Iterable<String> customerNames,
    required Iterable<String> productNames,
  }) {
    if (text.isEmpty) {
      return text;
    }
    final withoutCustomers = _replaceNames(
      text,
      _customerPhrases(customerNames),
      customerPlaceholder,
    );
    final withoutProducts = _replaceNames(
      withoutCustomers,
      _fullPhrases(productNames),
      productPlaceholder,
    );
    return _replaceNumbers(withoutProducts);
  }

  List<String> _nameWords(String name) {
    return name
        .split(_nameSeparators)
        .where((word) => word.isNotEmpty)
        .toList();
  }

  bool _isUsableName(List<String> words) {
    final totalLength = words.fold<int>(0, (sum, word) => sum + word.length);
    return totalLength >= _minimumNameLength;
  }

  List<List<String>> _fullPhrases(Iterable<String> names) {
    return <List<String>>[
      for (final name in names)
        if (_isUsableName(_nameWords(name))) _nameWords(name),
    ];
  }

  List<List<String>> _customerPhrases(Iterable<String> names) {
    final phrases = _fullPhrases(names);
    return <List<String>>[
      ...phrases,
      for (final phrase in phrases)
        if (phrase.length > 1)
          for (final word in phrase)
            if (word.length >= _minimumNameWordLength &&
                !_honorifics.contains(word.toLowerCase()))
              <String>[word],
    ];
  }

  String _replaceNames(
    String text,
    List<List<String>> phrases,
    String placeholder,
  ) {
    final patternByKey = <String, String>{};
    for (final phrase in phrases) {
      final key = phrase.join(' ').toLowerCase();
      patternByKey[key] = phrase.map(RegExp.escape).join('[^$_wordCharacter]+');
    }
    if (patternByKey.isEmpty) {
      return text;
    }
    final orderedKeys = patternByKey.keys.toList()
      ..sort((first, second) => second.length.compareTo(first.length));
    final alternatives = orderedKeys.map((key) => patternByKey[key]).join('|');
    final namePattern = RegExp(
      '($_existingPlaceholders)'
      '|(?<![$_wordCharacter])(?:$alternatives)(?![$_wordCharacter])',
      caseSensitive: false,
      unicode: true,
    );
    final replaced = text.replaceAllMapped(
      namePattern,
      (match) => match.group(1) ?? placeholder,
    );
    return _collapseRepeats(replaced, placeholder);
  }

  String _collapseRepeats(String text, String placeholder) {
    final escaped = RegExp.escape(placeholder);
    return text.replaceAll(RegExp('$escaped(?:\\s+$escaped)+'), placeholder);
  }

  String _replaceNumbers(String text) {
    return text.replaceAllMapped(_numberRun, (match) {
      final digits = match[0]!.replaceAll(_digitGroupSeparators, '');
      if (digits.length < _minimumNumberDigits) {
        return match[0]!;
      }
      return numberPlaceholder;
    });
  }
}
