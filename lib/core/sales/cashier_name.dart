const int cashierNameMaxLength = 40;

String? normalizeCashierName(String? rawName) {
  if (rawName == null) return null;
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) return null;
  final runes = trimmed.runes.toList();
  if (runes.length <= cashierNameMaxLength) return trimmed;
  return String.fromCharCodes(runes.take(cashierNameMaxLength)).trim();
}
