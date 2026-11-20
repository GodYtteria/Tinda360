final class QueryLanguage {
  const new();

  static final RegExp _wordSeparators = RegExp(r'[^\p{L}]+', unicode: true);
  static final RegExp _combiningMarks = RegExp(r'\p{M}+', unicode: true);

  static const Map<String, String> _accentFolds = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
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
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  static const Set<String> _filipinoWords = <String>{
    'ang',
    'ng',
    'mga',
    'ko',
    'ba',
    'po',
    'opo',
    'ilan',
    'ilang',
    'magkano',
    'sino',
    'ano',
    'anong',
    'alin',
    'kailan',
    'kelan',
    'pa',
    'na',
    'yung',
    'natin',
    'tayo',
    'lang',
    'sa',
    'mo',
    'ako',
    'akin',
    'may',
    'wala',
    'meron',
    'benta',
    'paninda',
    'tindahan',
    'kita',
    'ngayon',
    'kahapon',
    'linggo',
    'buwan',
    'naman',
    'nga',
    'naku',
    'grabe',
    'nako',
    'pila',
    'unsa',
    'kinsa',
    'karon',
    'naa',
    'mano',
    'adda',
    'ti',
    'ita',
    'kadi',
    'aldaw',
    'presyo',
    'mauubos',
    'ubos',
    'natitira',
    'gaano',
    'kumusta',
    'salamat',
  };

  static const Set<String> _englishWords = <String>{
    'the',
    'is',
    'are',
    'how',
    'what',
    'who',
    'which',
    'much',
    'many',
    'my',
    'i',
    'do',
    'does',
    'have',
    'has',
    'yesterday',
    'week',
    'month',
    'did',
    'of',
    'me',
    'show',
    'list',
    'any',
    'can',
    'you',
    'there',
    'will',
    'when',
    'owe',
    'run',
    'out',
    'last',
    'please',
    'thanks',
  };

  static const Set<String> _taglishLoanwords = <String>{
    'today',
    'sales',
    'sell',
    'sold',
    'left',
    'best',
    'low',
    'price',
    'customers',
    'products',
    'items',
  };

  bool isFilipino(String query, {required bool appIsFilipino}) {
    final words = query
        .replaceAll(_combiningMarks, '')
        .split(_wordSeparators)
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    var filipinoCount = 0;
    var englishCount = 0;
    var loanwordCount = 0;
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      final lower = _foldAccents(word.toLowerCase());
      if (_filipinoWords.contains(lower)) filipinoCount++;
      final looksLikeName = index > 0 && word != word.toLowerCase();
      if (looksLikeName) continue;
      if (_englishWords.contains(lower)) englishCount++;
      if (_taglishLoanwords.contains(lower)) loanwordCount++;
    }
    if (filipinoCount == 0) englishCount += loanwordCount;
    if (filipinoCount == englishCount) return appIsFilipino;
    return filipinoCount > englishCount;
  }

  String _foldAccents(String word) =>
      word.split('').map((letter) => _accentFolds[letter] ?? letter).join();
}
