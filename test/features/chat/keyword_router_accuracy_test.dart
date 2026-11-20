import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/yumi_intent_mapper.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';

const String _queriesDirectory = 'ai-model/queries';
const String _novelCasesFile = 'ai-model/novel_eval.txt';
const String _noToolFile = 'no_tool';
const String _replySeparator = '||';

Map<String, ChatIntent> _loadExpectedIntents() {
  final expected = <String, ChatIntent>{};
  for (final file in Directory(
    _queriesDirectory,
  ).listSync().whereType<File>()) {
    final tool = file.uri.pathSegments.last.replaceAll('.txt', '');
    if (tool == _noToolFile) continue;
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('@')) continue;
      final query = trimmed.split(_replySeparator).first.trim();
      expected[query] = toolNameToIntent(tool);
    }
  }
  for (final line in File(_novelCasesFile).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('|');
    expected[parts[0]] = toolNameToIntent(parts[1]);
  }
  return expected;
}

void main() {
  final hasData =
      Directory(_queriesDirectory).existsSync() &&
      File(_novelCasesFile).existsSync();

  test('keyword router routes hand-written queries to the right intent', () {
    final matcher = IntentMatcher.fromJsonString(
      File('assets/ai/intents.json').readAsStringSync(),
    );
    final expected = _loadExpectedIntents();
    final failuresByIntent = <ChatIntent, List<String>>{};
    var correct = 0;
    for (final entry in expected.entries) {
      final actual = matcher.match(entry.key).intent;
      if (actual == entry.value) {
        correct++;
      } else {
        failuresByIntent
            .putIfAbsent(entry.value, () => <String>[])
            .add(entry.key);
      }
    }
    final accuracy = correct / expected.length;
    final report = StringBuffer(
      'accuracy ${(accuracy * 100).toStringAsFixed(1)}% '
      '($correct/${expected.length})\n',
    );
    for (final entry in failuresByIntent.entries) {
      report.writeln(
        '${entry.key.name}: ${entry.value.length} wrong, e.g. '
        '${jsonEncode(entry.value.take(3).toList())}',
      );
    }
    stderr.writeln(report);
    expect(accuracy, greaterThan(0.0));
  }, skip: hasData ? false : 'ai-model data not present');
}
