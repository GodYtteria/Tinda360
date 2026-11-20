library yumi_tokenizer;

import 'dart:convert';

final class YumiTokenizer {
  const YumiTokenizer._({
    required this.vocab,
    required this.merges,
    required this.specialTokens,
    required this.bosId,
    required this.eosId,
    required this.imStartId,
    required this.imEndId,
    required this.toolCallId,
    required this.toolCallEndId,
  });

  final Map<String, int> vocab;
  final Map<String, int> merges;
  final Map<String, int> specialTokens;
  final int bosId;
  final int eosId;
  final int imStartId;
  final int imEndId;
  final int toolCallId;
  final int toolCallEndId;

  factory YumiTokenizer.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>;
    final rawVocab = model['vocab'] as Map<String, dynamic>;
    final vocab = {
      for (final entry in rawVocab.entries) entry.key: entry.value as int,
    };

    final rawMerges = model['merges'] as List<dynamic>;
    final merges = <String, int>{};
    for (int i = 0; i < rawMerges.length; i++) {
      final raw = rawMerges[i];
      final mergeKey = raw is List ? '${raw[0]} ${raw[1]}' : raw as String;
      merges[mergeKey] = i;
    }

    final specialTokens = <String, int>{};
    for (final addedToken in (json['added_tokens'] as List<dynamic>? ?? [])) {
      final tokenMap = addedToken as Map<String, dynamic>;
      specialTokens[tokenMap['content'] as String] = tokenMap['id'] as int;
    }

    int get(String tokenName) =>
        specialTokens[tokenName] ?? vocab[tokenName] ?? 0;

    return YumiTokenizer._(
      vocab: vocab,
      merges: merges,
      specialTokens: specialTokens,
      bosId: get('[BOS]'),
      eosId: get('[EOS]'),
      imStartId: get('<|im_start|>'),
      imEndId: get('<|im_end|>'),
      toolCallId: get('<tool_call>'),
      toolCallEndId: get('</tool_call>'),
    );
  }

  List<int> encode(String text, {bool addSpecialTokens = false}) {
    if (text.isEmpty) return [];
    final ids = <int>[];
    if (addSpecialTokens) ids.add(bosId);

    final parts = _splitOnSpecials(text);
    for (final part in parts) {
      if (specialTokens.containsKey(part)) {
        ids.add(specialTokens[part]!);
      } else {
        ids.addAll(_encodePlain(part));
      }
    }

    if (addSpecialTokens) ids.add(eosId);
    return ids;
  }

  List<String> _splitOnSpecials(String text) {
    if (specialTokens.isEmpty) return [text];
    final sorted = specialTokens.keys.toList()
      ..sort((first, second) => second.length.compareTo(first.length));
    final pattern = sorted.map((special) => RegExp.escape(special)).join('|');
    final specialPattern = RegExp(pattern);

    final parts = <String>[];
    int last = 0;
    for (final match in specialPattern.allMatches(text)) {
      if (match.start > last) parts.add(text.substring(last, match.start));
      parts.add(match.group(0)!);
      last = match.end;
    }
    if (last < text.length) parts.add(text.substring(last));
    return parts;
  }

  List<int> _encodePlain(String text) {
    if (text.isEmpty) return [];

    final ids = <int>[];
    for (final preToken in _byteLevelSplit.allMatches(text)) {
      ids.addAll(_bpeMerge(_byteLevelChars(preToken.group(0)!)));
    }
    return ids;
  }

  static final RegExp _byteLevelSplit = RegExp(
    r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+",
    unicode: true,
  );

  List<String> _byteLevelChars(String preToken) {
    final bytes = utf8.encode(preToken);
    final chars = <String>[];
    for (final byteValue in bytes) {
      chars.add(_byteToChar(byteValue));
    }
    return chars;
  }

  static String _byteToChar(int byteValue) {
    if (byteValue >= 33 && byteValue <= 126)
      return String.fromCharCode(byteValue);
    if (byteValue >= 161 && byteValue <= 172)
      return String.fromCharCode(byteValue);
    if (byteValue >= 174 && byteValue <= 255)
      return String.fromCharCode(byteValue);
    return _byteCharMap[byteValue] ?? String.fromCharCode(byteValue + 256);
  }

  static final Map<int, String> _byteCharMap = _buildByteCharMap();

  static Map<int, String> _buildByteCharMap() {
    final printable = <int>[];
    for (int i = 33; i <= 126; i++) printable.add(i);
    for (int i = 161; i <= 172; i++) printable.add(i);
    for (int i = 174; i <= 255; i++) printable.add(i);

    final map = <int, String>{};
    for (final byteValue in printable)
      map[byteValue] = String.fromCharCode(byteValue);

    int offset = 256;
    for (int byteValue = 0; byteValue < 256; byteValue++) {
      if (!map.containsKey(byteValue)) {
        map[byteValue] = String.fromCharCode(offset++);
      }
    }
    return map;
  }

  List<int> _bpeMerge(List<String> chars) {
    if (chars.isEmpty) return [];

    var tokens = List<String>.from(chars);

    while (tokens.length > 1) {
      int bestRank = -1;
      int bestIdx = -1;

      for (int i = 0; i < tokens.length - 1; i++) {
        final pair = '${tokens[i]} ${tokens[i + 1]}';
        final rank = merges[pair];
        if (rank != null && (bestRank < 0 || rank < bestRank)) {
          bestRank = rank;
          bestIdx = i;
        }
      }

      if (bestIdx < 0) break;

      final merged = tokens[bestIdx] + tokens[bestIdx + 1];
      tokens = [
        ...tokens.sublist(0, bestIdx),
        merged,
        ...tokens.sublist(bestIdx + 2),
      ];
    }

    return tokens.map((token) => vocab[token] ?? vocab['[UNK]'] ?? 3).toList();
  }

  String decode(List<int> ids, {bool skipSpecial = true}) {
    final reverseVocab = <int, String>{};
    for (final entry in vocab.entries) reverseVocab[entry.value] = entry.key;
    for (final entry in specialTokens.entries)
      reverseVocab[entry.value] = entry.key;

    final bytes = <int>[];
    for (final id in ids) {
      final token = reverseVocab[id] ?? '';
      if (skipSpecial && specialTokens.values.contains(id)) {
        if (id == toolCallId || id == toolCallEndId) {
          bytes.addAll(utf8.encode(token));
        }
        continue;
      }
      bytes.addAll(_tokenToBytes(token));
    }

    return utf8.decode(bytes, allowMalformed: true);
  }

  List<int> _tokenToBytes(String token) {
    final bytes = <int>[];
    for (final codePoint in token.runes) {
      final byteValue = _charToByte(codePoint);
      if (byteValue != null) {
        bytes.add(byteValue);
      }
    }
    return bytes;
  }

  static int? _charToByte(int codePoint) {
    return _charByteMap[codePoint];
  }

  static final Map<int, int> _charByteMap = _buildCharByteMap();

  static Map<int, int> _buildCharByteMap() {
    final charToByteSource = _buildByteCharMap();
    return {
      for (final entry in charToByteSource.entries)
        entry.value.codeUnitAt(0): entry.key,
    };
  }
}
