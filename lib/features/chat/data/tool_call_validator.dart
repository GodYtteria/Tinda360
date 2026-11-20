import 'dart:convert';

enum ToolCallRejection {
  unknownTool,
  unknownArgument,
  wrongType,
  outOfRange,
  notInQuestion,
  missingRequired,
}

final class ToolCallValidation {
  const new({
    required this.toolName,
    required this.arguments,
    this.rejection,
    this.rejectedArgument,
  });

  final String toolName;

  final Map<String, Object> arguments;

  final ToolCallRejection? rejection;

  final String? rejectedArgument;

  bool get isValid => rejection == null;
}

enum _ArgumentType { string, integer, number }

final class _NumericRange {
  const new(this.minimum, this.maximum);

  final num minimum;

  final num maximum;

  bool contains(num value) => value >= minimum && value <= maximum;
}

final class _ArgumentSpec {
  const new({required this.type, required this.allowedValues});

  final _ArgumentType type;

  final Set<String>? allowedValues;
}

final class _ToolSpec {
  const new({required this.arguments, required this.required});

  final Map<String, _ArgumentSpec> arguments;

  final List<String> required;
}

final class ToolCallValidator {
  const new _(this._tools);

  factory fromToolsJson(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      return const ToolCallValidator._(<String, _ToolSpec>{});
    }
    final tools = <String, _ToolSpec>{};
    if (decoded is List<dynamic>) {
      for (final entry in decoded) {
        _registerTool(entry, tools);
      }
    }
    return ToolCallValidator._(tools);
  }

  static const _NumericRange _nonNegativeRange = _NumericRange(
    0,
    double.maxFinite,
  );

  static const Map<String, _NumericRange> _namedRanges =
      <String, _NumericRange>{
        'limit': _NumericRange(1, 50),
        'days': _NumericRange(1, 365),
        'days_overdue': _NumericRange(1, 365),
        'days_ahead': _NumericRange(1, 365),
        'threshold': _NumericRange(0, 100000),
        'min_balance': _NumericRange(0, 10000000),
        'budget': _NumericRange(0, 10000000),
      };

  static const Set<String> _entityArguments = <String>{
    'product_name',
    'customer_name',
  };

  static const Map<String, _ArgumentType> _typesByName =
      <String, _ArgumentType>{
        'string': _ArgumentType.string,
        'integer': _ArgumentType.integer,
        'number': _ArgumentType.number,
      };

  static const Map<String, String> _accentGroups = <String, String>{
    'a': 'àáâãäåāăą',
    'c': 'çćč',
    'd': 'ď',
    'e': 'èéêëēĕėęě',
    'i': 'ìíîïĩīĭį',
    'n': 'ñńň',
    'o': 'òóôõöøōŏő',
    'r': 'ŕř',
    's': 'śšş',
    't': 'ť',
    'u': 'ùúûüũūŭůűų',
    'y': 'ýÿ',
    'z': 'žźż',
  };

  static final Map<String, String> _foldedByAccent = <String, String>{
    for (final group in _accentGroups.entries)
      for (final accented in group.value.split('')) accented: group.key,
  };

  static final RegExp _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  final Map<String, _ToolSpec> _tools;

  static void _registerTool(Object? entry, Map<String, _ToolSpec> tools) {
    if (entry is! Map<String, dynamic>) {
      return;
    }
    final function = entry['function'];
    if (function is! Map<String, dynamic>) {
      return;
    }
    final name = function['name'];
    if (name is! String || name.isEmpty) {
      return;
    }
    final parameters = function['parameters'];
    final rawProperties = parameters is Map<String, dynamic>
        ? parameters['properties']
        : null;
    final arguments = <String, _ArgumentSpec>{};
    if (rawProperties is Map<String, dynamic>) {
      for (final property in rawProperties.entries) {
        final spec = _parseArgumentSpec(property.value);
        if (spec == null) {
          return;
        }
        arguments[property.key] = spec;
      }
    } else if (rawProperties != null) {
      return;
    }
    final rawRequired = parameters is Map<String, dynamic>
        ? parameters['required']
        : null;
    final required = rawRequired is List<dynamic>
        ? rawRequired.whereType<String>().toList(growable: false)
        : const <String>[];
    tools[name] = _ToolSpec(arguments: arguments, required: required);
  }

  static _ArgumentSpec? _parseArgumentSpec(Object? rawSpec) {
    if (rawSpec is! Map<String, dynamic>) {
      return null;
    }
    final type = _typesByName[rawSpec['type']];
    if (type == null) {
      return null;
    }
    final rawEnum = rawSpec['enum'];
    final allowedValues = rawEnum is List<dynamic>
        ? rawEnum
              .whereType<String>()
              .map((value) => value.trim().toLowerCase())
              .toSet()
        : null;
    return _ArgumentSpec(type: type, allowedValues: allowedValues);
  }

  ToolCallValidation validate(
    String? toolName,
    Map<String, dynamic>? arguments, {
    required String question,
  }) {
    final spec = toolName == null ? null : _tools[toolName];
    if (toolName == null || spec == null) {
      return ToolCallValidation(
        toolName: toolName ?? '',
        arguments: const <String, Object>{},
        rejection: ToolCallRejection.unknownTool,
      );
    }
    final supplied = arguments ?? const <String, dynamic>{};
    for (final key in supplied.keys) {
      if (!spec.arguments.containsKey(key)) {
        return _reject(
          toolName,
          ToolCallRejection.unknownArgument,
          rejectedArgument: key,
        );
      }
    }
    final cleaned = <String, Object>{};
    for (final entry in supplied.entries) {
      final argumentSpec = spec.arguments[entry.key]!;
      final cleanedValue = _cleanValue(
        entry.key,
        argumentSpec,
        entry.value,
        question,
      );
      if (cleanedValue.rejection != null) {
        return _reject(
          toolName,
          cleanedValue.rejection!,
          rejectedArgument: entry.key,
        );
      }
      cleaned[entry.key] = cleanedValue.value!;
    }
    for (final requiredName in spec.required) {
      if (!cleaned.containsKey(requiredName)) {
        return _reject(
          toolName,
          ToolCallRejection.missingRequired,
          rejectedArgument: requiredName,
        );
      }
    }
    return ToolCallValidation(toolName: toolName, arguments: cleaned);
  }

  ToolCallValidation _reject(
    String toolName,
    ToolCallRejection rejection, {
    required String rejectedArgument,
  }) {
    return ToolCallValidation(
      toolName: toolName,
      arguments: const <String, Object>{},
      rejection: rejection,
      rejectedArgument: rejectedArgument,
    );
  }

  _CleanedValue _cleanValue(
    String name,
    _ArgumentSpec spec,
    Object? value,
    String question,
  ) {
    switch (spec.type) {
      case _ArgumentType.string:
        return _cleanString(name, spec, value, question);
      case _ArgumentType.integer:
        return _cleanInteger(name, value);
      case _ArgumentType.number:
        return _cleanNumber(name, value);
    }
  }

  _CleanedValue _cleanString(
    String name,
    _ArgumentSpec spec,
    Object? value,
    String question,
  ) {
    if (value is! String) {
      return const _CleanedValue.rejected(ToolCallRejection.wrongType);
    }
    final allowedValues = spec.allowedValues;
    if (allowedValues != null) {
      final normalized = value.trim().toLowerCase();
      return allowedValues.contains(normalized)
          ? _CleanedValue.accepted(normalized)
          : const _CleanedValue.rejected(ToolCallRejection.outOfRange);
    }
    if (_entityArguments.contains(name)) {
      final found = _findInQuestion(value, question);
      return found == null
          ? const _CleanedValue.rejected(ToolCallRejection.notInQuestion)
          : _CleanedValue.accepted(found);
    }
    return _CleanedValue.accepted(value.trim());
  }

  _CleanedValue _cleanInteger(String name, Object? value) {
    final int integer;
    if (value is int) {
      integer = value;
    } else if (value is double && value.isFinite && value == value.truncate()) {
      integer = value.toInt();
    } else {
      return const _CleanedValue.rejected(ToolCallRejection.wrongType);
    }
    return _checkRange(name, integer);
  }

  _CleanedValue _cleanNumber(String name, Object? value) {
    if (value is! num || (value is double && !value.isFinite)) {
      return const _CleanedValue.rejected(ToolCallRejection.wrongType);
    }
    return _checkRange(name, value);
  }

  _CleanedValue _checkRange(String name, num value) {
    final range = _namedRanges[name] ?? _nonNegativeRange;
    return range.contains(value)
        ? _CleanedValue.accepted(value)
        : const _CleanedValue.rejected(ToolCallRejection.outOfRange);
  }

  String? _findInQuestion(String entity, String question) {
    final entityWords = _wordPattern
        .allMatches(entity)
        .map((match) => _fold(match.group(0)!))
        .toList(growable: false);
    if (entityWords.isEmpty) {
      return null;
    }
    final questionMatches = _wordPattern
        .allMatches(question)
        .toList(growable: false);
    final questionWords = questionMatches
        .map((match) => _fold(match.group(0)!))
        .toList(growable: false);
    for (
      var start = 0;
      start + entityWords.length <= questionWords.length;
      start++
    ) {
      var matches = true;
      for (var offset = 0; offset < entityWords.length; offset++) {
        if (questionWords[start + offset] != entityWords[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        final last = start + entityWords.length - 1;
        return question.substring(
          questionMatches[start].start,
          questionMatches[last].end,
        );
      }
    }
    return null;
  }

  String _fold(String word) {
    final buffer = StringBuffer();
    for (final rune in word.toLowerCase().runes) {
      final character = String.fromCharCode(rune);
      buffer.write(_foldedByAccent[character] ?? character);
    }
    return buffer.toString();
  }
}

final class _CleanedValue {
  const new accepted(Object this.value) : rejection = null;

  const new rejected(ToolCallRejection this.rejection) : value = null;

  final Object? value;

  final ToolCallRejection? rejection;
}
