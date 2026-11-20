import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/presentation/clarification_reply.dart';

const int _maximumLabelLength = 32;
const String _toolsAssetPath = 'assets/ai/tools.json';
const int _expectedToolCount = 20;

List<String> _loadToolNames() {
  final decoded = jsonDecode(File(_toolsAssetPath).readAsStringSync());
  return (decoded as List<dynamic>)
      .map(
        (entry) =>
            ((entry as Map<String, dynamic>)['function']
                    as Map<String, dynamic>)['name']
                as String,
      )
      .toList(growable: false);
}

void main() {
  final toolNames = _loadToolNames();

  test('tools asset lists the expected number of tools', () {
    expect(toolNames, hasLength(_expectedToolCount));
  });

  for (final isFilipino in <bool>[false, true]) {
    final language = isFilipino ? 'filipino' : 'english';

    group(language, () {
      test('every tool has a non-empty label', () {
        for (final toolName in toolNames) {
          final label = clarificationLabel(toolName, isFilipino: isFilipino);
          expect(label, isNotNull, reason: toolName);
          expect(label!.trim(), isNotEmpty, reason: toolName);
        }
      });

      test('labels are unique', () {
        final labels = toolNames
            .map((name) => clarificationLabel(name, isFilipino: isFilipino))
            .toList(growable: false);
        expect(labels.toSet(), hasLength(labels.length));
      });

      test('labels fit the maximum length', () {
        for (final toolName in toolNames) {
          final label = clarificationLabel(toolName, isFilipino: isFilipino)!;
          expect(
            label.length,
            lessThanOrEqualTo(_maximumLabelLength),
            reason: '$toolName: $label',
          );
        }
      });

      test('unknown names have no label', () {
        for (final unknownName in <String>['get_weather', 'no_tool', '']) {
          expect(
            clarificationLabel(unknownName, isFilipino: isFilipino),
            isNull,
            reason: unknownName,
          );
        }
      });

      test('options keep input order', () {
        final options = buildClarificationOptions(<String>[
          'get_utang_risk',
          'get_low_stock',
          'get_utang_list',
        ], isFilipino: isFilipino);
        expect(options.map((option) => option.toolName), <String>[
          'get_utang_risk',
          'get_low_stock',
          'get_utang_list',
        ]);
        expect(
          options.map((option) => option.label),
          options.map(
            (option) =>
                clarificationLabel(option.toolName, isFilipino: isFilipino),
          ),
        );
      });

      test('options drop unknown names and duplicates', () {
        final options = buildClarificationOptions(<String>[
          'get_low_stock',
          'no_tool',
          'get_low_stock',
          '',
          'get_expenses',
        ], isFilipino: isFilipino);
        expect(options.map((option) => option.toolName), <String>[
          'get_low_stock',
          'get_expenses',
        ]);
      });

      test('empty input gives empty options', () {
        expect(
          buildClarificationOptions(<String>[], isFilipino: isFilipino),
          isEmpty,
        );
      });

      test('prompt is not empty', () {
        expect(clarificationPrompt(isFilipino: isFilipino).trim(), isNotEmpty);
      });
    });
  }

  test('prompts differ between languages', () {
    expect(
      clarificationPrompt(isFilipino: true),
      isNot(clarificationPrompt(isFilipino: false)),
    );
  });

  test('labels differ between languages', () {
    for (final toolName in toolNames) {
      expect(
        clarificationLabel(toolName, isFilipino: true),
        isNot(clarificationLabel(toolName, isFilipino: false)),
        reason: toolName,
      );
    }
  });
}
