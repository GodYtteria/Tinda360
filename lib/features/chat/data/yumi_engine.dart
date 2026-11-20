import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tinda360/features/chat/data/yumi_tokenizer.dart';

typedef _LoadNative = Int32 Function(Pointer<Char> path);
typedef _LoadDart = int Function(Pointer<Char> path);

typedef _UnloadNative = Void Function();
typedef _UnloadDart = void Function();

typedef _GenerateNative = Int32 Function(
  Pointer<Int32> inputIds,
  Int32 nInput,
  Pointer<Int32> outputIds,
  Int32 maxNew,
  Int32 eosId,
  Int32 stopId2,
  Int32 prefixLength,
);
typedef _GenerateDart = int Function(
  Pointer<Int32> inputIds,
  int nInput,
  Pointer<Int32> outputIds,
  int maxNew,
  int eosId,
  int stopId2,
  int prefixLength,
);

final class YumiInferResult {
  const new({
    required this.rawText,
    this.toolName,
    this.toolArgs,
    this.generatedTokens = 0,
    this.elapsed = Duration.zero,
  });

  final String rawText;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final int generatedTokens;
  final Duration elapsed;

  bool get hasToolCall => toolName != null;

  double get tokensPerSecond {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    return seconds <= 0 ? 0 : generatedTokens / seconds;
  }

  YumiInferResult withTiming({
    required int generatedTokens,
    required Duration elapsed,
  }) => YumiInferResult(
    rawText: rawText,
    toolName: toolName,
    toolArgs: toolArgs,
    generatedTokens: generatedTokens,
    elapsed: elapsed,
  );
}

final class YumiTurn {
  const new user(this.text) : isUser = true;
  const new assistant(this.text) : isUser = false;

  final String text;
  final bool isUser;
}

final class YumiEngine {
  new _();

  static final YumiEngine instance = YumiEngine._();

  static const String _ggufAsset = 'assets/ai/model.gguf';
  static const String _tokenizerAsset = 'assets/ai/tokenizer.json';
  static const String _toolsAsset = 'assets/ai/tools.json';
  static const int _maxNewTokens = 256;
  static const int _maxPromptTokens = 760;

  static const String _systemPrompt =
      'Ikaw si Yumi, AI assistant ng sari-sari store. '
      'Sumagot sa Taglish. Gumamit ng tools para kunin ang data mula sa database. '
      'Huwag mag-imbento ng datos — always call a tool first. '
      'Maging friendly, concise, at helpful.';

  YumiTokenizer? _tokenizer;
  String? _toolDefsText;

  _UnloadDart? _ffiUnload;
  _GenerateDart? _ffiGenerate;

  bool _ready = false;
  Future<void>? _initFuture;

  bool get isReady => _ready;

  Future<void> init() {
    if (_ready) return Future<void>.value();
    return _initFuture ??= _doInit().catchError((
      Object error,
      StackTrace stack,
    ) {
      _initFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _doInit() async {
    final tokJson = await rootBundle.loadString(_tokenizerAsset);
    _tokenizer = YumiTokenizer.fromJson(
      json.decode(tokJson) as Map<String, dynamic>,
    );

    final rawToolDefs = await rootBundle.loadString(_toolsAsset);
    _toolDefsText = _formatToolDefs(rawToolDefs);

    final ggufPath = await _extractAsset(_ggufAsset, 'model.gguf');

    final ok = await Isolate.run(() {
      final lib = _loadNativeLib();
      final load = lib.lookupFunction<_LoadNative, _LoadDart>('ytteria_load');
      final pathPtr = ggufPath.toNativeUtf8().cast<Char>();
      final result = load(pathPtr);
      malloc.free(pathPtr);
      return result;
    });

    if (ok != 1) {
      throw StateError('[YumiEngine] Failed to load GGUF: $ggufPath');
    }

    final lib = _loadNativeLib();
    _ffiUnload = lib.lookupFunction<_UnloadNative, _UnloadDart>(
      'ytteria_unload',
    );
    _ffiGenerate = lib.lookupFunction<_GenerateNative, _GenerateDart>(
      'ytteria_generate',
    );

    _ready = true;
  }

  void dispose() {
    _ffiUnload?.call();
    _ready = false;
    _initFuture = null;
  }

  Future<YumiInferResult> infer(
    String userQuery, {
    String contextSummary = '',
    List<YumiTurn> recentTurns = const <YumiTurn>[],
  }) async {
    if (!_ready || _ffiGenerate == null || _tokenizer == null) {
      throw StateError('[YumiEngine] Not initialized. Call init() first.');
    }
    final tok = _tokenizer!;
    final prompt = _buildPrompt(
      userQuery,
      contextSummary: contextSummary,
      recentTurns: recentTurns,
    );
    final inputIds = tok.encode(prompt);
    final fullInput = [tok.bosId, ...inputIds];
    final eosId = tok.eosId;
    final imEndId = tok.imEndId;
    final prefixLength = _cacheablePrefixLength(tok, fullInput);

    final stopwatch = Stopwatch()..start();
    final outputIds = await Isolate.run(() {
      final lib = _loadNativeLib();
      final generate = lib.lookupFunction<_GenerateNative, _GenerateDart>(
        'ytteria_generate',
      );
      final inBuf = calloc<Int32>(fullInput.length);
      final outBuf = calloc<Int32>(_maxNewTokens);
      try {
        for (var i = 0; i < fullInput.length; i++) {
          inBuf[i] = fullInput[i];
        }
        final nGen = generate(
          inBuf,
          fullInput.length,
          outBuf,
          _maxNewTokens,
          eosId,
          imEndId,
          prefixLength,
        );
        return List<int>.generate(nGen > 0 ? nGen : 0, (i) => outBuf[i]);
      } finally {
        calloc.free(inBuf);
        calloc.free(outBuf);
      }
    });

    final rawText = tok.decode(outputIds, skipSpecial: false);
    stopwatch.stop();
    return _parseResult(rawText).withTiming(
      generatedTokens: outputIds.length,
      elapsed: stopwatch.elapsed,
    );
  }

  String compactTurns(List<YumiTurn> turns, {int maxCharsPerTurn = 96}) {
    if (turns.isEmpty) return '';
    final lines = <String>[];
    for (final turn in turns) {
      var text = turn.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.length > maxCharsPerTurn) {
        text = '${text.substring(0, maxCharsPerTurn - 1)}…';
      }
      lines.add('${turn.isUser ? 'U' : 'A'}: $text');
    }
    return 'Dating usapan:\n${lines.join('\n')}';
  }

  String get _staticPromptPrefix {
    final parts = <String>['<|im_start|>system\n$_systemPrompt<|im_end|>'];
    if (_toolDefsText != null && _toolDefsText!.isNotEmpty) {
      parts.add('<|im_start|>system\nTools:\n$_toolDefsText<|im_end|>');
    }
    return '${parts.join('\n')}\n';
  }

  int _cacheablePrefixLength(YumiTokenizer tokenizer, List<int> fullInput) {
    final prefixIds = <int>[
      tokenizer.bosId,
      ...tokenizer.encode(_staticPromptPrefix, addSpecialTokens: false),
    ];
    if (prefixIds.length >= fullInput.length) return 0;
    for (var index = 0; index < prefixIds.length; index++) {
      if (prefixIds[index] != fullInput[index]) return 0;
    }
    return prefixIds.length;
  }

  String _buildPrompt(
    String userQuery, {
    String contextSummary = '',
    List<YumiTurn> recentTurns = const <YumiTurn>[],
  }) {
    final tokenizer = _tokenizer!;
    String stripSpecialTokens(String text) => tokenizer.specialTokens.keys.fold(
      text,
      (cleaned, special) => cleaned.replaceAll(special, ''),
    );
    final safeQuery = stripSpecialTokens(userQuery);
    final baseParts = <String>[
      '<|im_start|>system\n$_systemPrompt<|im_end|>',
    ];
    if (_toolDefsText != null && _toolDefsText!.isNotEmpty) {
      baseParts.add('<|im_start|>system\nTools:\n$_toolDefsText<|im_end|>');
    }
    const tail = '<|im_start|>assistant\n';
    final queryPart = '<|im_start|>user\n$safeQuery<|im_end|>';

    String assemble(String summary, List<YumiTurn> turns) {
      final parts = <String>[...baseParts];
      if (summary.trim().isNotEmpty) {
        parts.add('<|im_start|>system\nContext: ${summary.trim()}<|im_end|>');
      }
      for (final turn in turns) {
        final role = turn.isUser ? 'user' : 'assistant';
        parts.add(
          '<|im_start|>$role\n${stripSpecialTokens(turn.text)}<|im_end|>',
        );
      }
      parts.add(queryPart);
      parts.add(tail);
      return parts.join('\n');
    }

    var summary = stripSpecialTokens(contextSummary).trim();
    final turns = List<YumiTurn>.from(recentTurns);
    var prompt = assemble(summary, turns);
    var tokenCount = tokenizer.encode(prompt).length + 1;
    while (tokenCount > _maxPromptTokens &&
        (summary.isNotEmpty || turns.isNotEmpty)) {
      if (summary.isNotEmpty) {
        summary = '';
      } else {
        turns.removeAt(0);
      }
      prompt = assemble(summary, turns);
      tokenCount = tokenizer.encode(prompt).length + 1;
    }

    if (tokenCount > _maxPromptTokens) {
      var trimmedQuery = safeQuery.trim();
      while (tokenCount > _maxPromptTokens && trimmedQuery.length > 32) {
        trimmedQuery = trimmedQuery.substring(
          trimmedQuery.length - (trimmedQuery.length ~/ 2),
        );
        prompt = <String>[
          ...baseParts,
          '<|im_start|>user\n$trimmedQuery<|im_end|>',
          tail,
        ].join('\n');
        tokenCount = tokenizer.encode(prompt).length + 1;
      }
    }
    return prompt;
  }

  static String _formatToolDefs(String rawJson) {
    final tools = json.decode(rawJson) as List<dynamic>;
    final lines = <String>[];
    for (final toolEntry in tools) {
      final functionDef =
          (toolEntry as Map<String, dynamic>)['function']
              as Map<String, dynamic>;
      final params =
          (functionDef['parameters'] as Map<String, dynamic>?)?['properties']
              as Map<String, dynamic>? ??
          {};
      final paramStr = params.entries
          .map(
            (entry) =>
                '${entry.key}: ${(entry.value as Map<String, dynamic>)['type'] ?? '?'}',
          )
          .join(', ');
      lines.add('${functionDef['name']}($paramStr)');
    }
    return lines.join('\n');
  }

  static YumiInferResult _parseResult(String rawText) {
    final text = rawText
        .replaceAll(RegExp(r'<\|im_start\|>\w*\n?'), '')
        .replaceAll('<|im_end|>', '')
        .trim();

    final toolCallMatch = RegExp(
      r'<tool_call>\s*(.*?)\s*</tool_call>',
      dotAll: true,
    ).firstMatch(text);

    if (toolCallMatch == null) return YumiInferResult(rawText: text);

    final Object? decoded;
    try {
      decoded = json.decode(toolCallMatch.group(1)!);
    } on FormatException {
      return YumiInferResult(rawText: text);
    }
    if (decoded is! Map<String, dynamic>) return YumiInferResult(rawText: text);
    final name = decoded['name'];
    final args = decoded['arguments'];
    return YumiInferResult(
      rawText: text,
      toolName: name is String ? name : null,
      toolArgs: args is Map<String, dynamic> ? args : null,
    );
  }

  static Future<String> _extractAsset(String assetPath, String filename) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$filename');

    final assetData = await rootBundle.load(assetPath);
    final bytes = assetData.buffer.asUint8List(
      assetData.offsetInBytes,
      assetData.lengthInBytes,
    );

    final targetPath = file.path;
    final upToDate = await Isolate.run(() {
      final existing = File(targetPath);
      return existing.existsSync() &&
          _sameBytes(existing.readAsBytesSync(), bytes);
    });
    if (!upToDate) {
      final staging = File('${file.path}.tmp');
      await staging.writeAsBytes(bytes, flush: true);
      await staging.rename(file.path);
    }

    return file.path;
  }

  static bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static DynamicLibrary _loadNativeLib() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libytteria.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    throw UnsupportedError(
      'YumiEngine: unsupported platform ${Platform.operatingSystem}',
    );
  }
}
