const String _fallbackStoreLabel = 'Tindahan';
const int _maxStoreLabelLength = 40;

const Map<String, String> _plainLetterByAccentedLetter = {
  'ñ': 'n',
  'Ñ': 'N',
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
  'Á': 'A',
  'É': 'E',
  'Í': 'I',
  'Ó': 'O',
  'Ú': 'U',
};

String backupFileNameFor(String storeName, DateTime now) {
  final plainName = storeName
      .split('')
      .map((letter) => _plainLetterByAccentedLetter[letter] ?? letter)
      .join();
  final safeLabel = plainName
      .replaceAll(RegExp('[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  final limitedLabel = safeLabel.length > _maxStoreLabelLength
      ? safeLabel
            .substring(0, _maxStoreLabelLength)
            .replaceAll(RegExp('-+\$'), '')
      : safeLabel;
  final label = limitedLabel.isEmpty ? _fallbackStoreLabel : limitedLabel;
  final localDay = now.toLocal();
  final year = localDay.year.toString().padLeft(4, '0');
  final month = localDay.month.toString().padLeft(2, '0');
  final day = localDay.day.toString().padLeft(2, '0');
  return 'Tinda360-$label-$year-$month-$day.sqlite';
}
