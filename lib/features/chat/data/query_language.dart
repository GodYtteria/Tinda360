final class QueryLanguage {
  const new();

  static final RegExp _wordSeparators = RegExp(r'[^\p{L}]+', unicode: true);

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
    'today',
    'yesterday',
    'sales',
    'sell',
    'sold',
    'left',
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
    'best',
    'low',
    'price',
    'customers',
    'products',
    'items',
    'owe',
    'run',
    'out',
    'last',
    'please',
    'thanks',
  };

  bool isFilipino(String query, {required bool appIsFilipino}) {
    final words = query
        .split(_wordSeparators)
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    var filipinoCount = 0;
    var englishCount = 0;
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      final lower = word.toLowerCase();
      if (_filipinoWords.contains(lower)) filipinoCount++;
      final looksLikeName = index > 0 && word != lower;
      if (!looksLikeName && _englishWords.contains(lower)) englishCount++;
    }
    if (filipinoCount == englishCount) return appIsFilipino;
    return filipinoCount > englishCount;
  }
}
