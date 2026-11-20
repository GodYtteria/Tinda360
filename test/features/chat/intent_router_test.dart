import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/intent_classifier.dart';
import 'package:tinda360/features/chat/data/yumi_intent_mapper.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';
import 'package:tinda360/features/chat/presentation/intent_router.dart';

const String _queriesDirectory = 'ai-model/queries';
const String _novelCasesFile = 'ai-model/novel_eval.txt';
const String _noToolFile = 'no_tool';
const String _separator = '||';
const double _minimumHeldOutAccuracy = 0.85;
const double _maximumHeldOutWrongRate = 0.10;
const double _minimumTrainingSetAccuracy = 0.93;
const double _maximumChitChatLeakRate = 0.05;
const Set<ChatIntent> _conversationalIntents = <ChatIntent>{
  ChatIntent.greeting,
  ChatIntent.thanks,
  ChatIntent.help,
};

final class _Tally {
  int correct = 0;
  int wrong = 0;
  int deferred = 0;

  int get total => correct + wrong + deferred;

  double get accuracy => correct / total;

  double get wrongRate => wrong / total;

  @override
  String toString() =>
      'correct $correct, wrong $wrong, deferred to model $deferred of $total';
}

Map<String, ChatIntent> _loadTrainingQueries() {
  final expected = <String, ChatIntent>{};
  for (final file in Directory(
    _queriesDirectory,
  ).listSync().whereType<File>()) {
    final tool = file.uri.pathSegments.last.replaceAll('.txt', '');
    if (tool == _noToolFile) continue;
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('@')) continue;
      final query = trimmed.split(_separator).first.trim();
      final intent = toolNameToIntent(tool);
      final previous = expected[query];
      if (previous != null && previous != intent) {
        throw StateError('"$query" is labelled both $previous and $intent');
      }
      expected[query] = intent;
    }
  }
  return expected;
}

Map<String, ChatIntent> _loadHeldOutQueries() {
  final expected = <String, ChatIntent>{};
  for (final line in File(_novelCasesFile).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final fields = line.split('|');
    if (fields.length < 2) {
      throw FormatException('held-out line has no tool name', line);
    }
    expected[fields[0].trim()] = toolNameToIntent(fields[1].trim());
  }
  return expected;
}

List<String> _loadChitChatQueries() =>
    File('$_queriesDirectory/$_noToolFile.txt')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('@'))
        .map((line) => line.split(_separator).first.trim())
        .toList();

_Tally _score(IntentRouter router, Map<String, ChatIntent> expected) {
  final tally = _Tally();
  for (final entry in expected.entries) {
    final decision = router.route(entry.key);
    if (decision.kind == RouteKind.askModel) {
      tally.deferred++;
    } else if (decision.kind == RouteKind.answerIntent &&
        decision.matched.intent == entry.value) {
      tally.correct++;
    } else {
      tally.wrong++;
    }
  }
  if (tally.total == 0) throw StateError('no queries to score');
  return tally;
}

void main() {
  final matcher = IntentMatcher.fromJsonString(
    File('assets/ai/intents.json').readAsStringSync(),
  );
  final classifier = IntentClassifier.fromJsonString(
    File('assets/ai/intent_model.json').readAsStringSync(),
  );
  final router = IntentRouter(matcher: matcher, classifier: classifier);
  final keywordOnlyRouter = IntentRouter(matcher: matcher, classifier: null);

  group('routing decisions', () {
    test('a confident store question is answered with its intent', () {
      final decision = router.route('sino ang may utang sa akin');
      expect(decision.kind, RouteKind.answerIntent);
      expect(decision.matched.intent, ChatIntent.utang);
    });

    test('the classifier overrides a misleading keyword', () {
      final decision = router.route('kailan mauubos ang bigas');
      expect(decision.kind, RouteKind.answerIntent);
      expect(decision.matched.intent, ChatIntent.stockForecast);
    });

    test('the tool name is exposed only when the classifier decided', () {
      expect(
        router.route('sino ang may utang sa akin').toolName,
        'get_utang_list',
      );
      expect(keywordOnlyRouter.route('benta ngayon').toolName, isNull);
      expect(router.route('hello').toolName, isNull);
    });

    test('the timeframe from the keyword matcher is kept', () {
      final decision = router.route('magkano benta ko ngayong linggo');
      expect(decision.matched.intent, ChatIntent.sales);
      expect(decision.matched.timeframe, QueryTimeframe.week);
    });

    test('an off-topic question is refused, not answered with data', () {
      for (final query in [
        'ano ang lulutuin ko mamaya',
        'who is the president',
      ]) {
        expect(router.route(query).kind, RouteKind.outOfScope, reason: query);
      }
    });

    test('greetings and thanks stay conversational', () {
      final greeting = router.route('hello');
      expect(greeting.kind, RouteKind.answerIntent);
      expect(greeting.matched.intent, ChatIntent.greeting);
      final thanks = router.route('salamat po');
      expect(thanks.kind, RouteKind.answerIntent);
      expect(thanks.matched.intent, ChatIntent.thanks);
    });

    test('gibberish and empty text are refused without calling the model', () {
      expect(router.route('zzzz qqqq xxxx').kind, RouteKind.outOfScope);
      expect(router.route('').kind, RouteKind.outOfScope);
    });

    test('without a classifier the keyword matcher decides', () {
      final sales = keywordOnlyRouter.route('benta ngayon');
      expect(sales.kind, RouteKind.answerIntent);
      expect(sales.matched.intent, ChatIntent.sales);
      expect(
        keywordOnlyRouter.route('zzzz qqqq xxxx').kind,
        RouteKind.askModel,
      );
    });
  });

  group('model tool veto', () {
    test('a tool the classifier finds implausible is rejected', () {
      expect(
        router.acceptsModelTool('zzzz qqqq xxxx', 'get_sales_trend'),
        isFalse,
      );
      expect(
        router.acceptsModelTool('ano ang ulam mamaya', 'get_sales_trend'),
        isFalse,
      );
    });

    test('a tool the classifier finds plausible is accepted', () {
      expect(
        router.acceptsModelTool(
          'kailan mauubos ang bigas',
          'get_stock_forecast',
        ),
        isTrue,
      );
    });

    test('an unknown tool name is rejected', () {
      expect(
        router.acceptsModelTool('benta ngayon', 'get_customer_info'),
        isFalse,
      );
    });

    test('without a classifier the model is trusted', () {
      expect(
        keywordOnlyRouter.acceptsModelTool('zzzz qqqq', 'get_sales_trend'),
        isTrue,
      );
    });
  });

  group('routing accuracy', () {
    final hasData =
        Directory(_queriesDirectory).existsSync() &&
        File(_novelCasesFile).existsSync();
    final skipReason = hasData ? false : 'ai-model data not present';

    test('held-out questions are mostly routed right and rarely wrong', () {
      final tally = _score(router, _loadHeldOutQueries());
      printOnFailure('held-out: $tally');
      expect(tally.accuracy, greaterThanOrEqualTo(_minimumHeldOutAccuracy));
      expect(tally.wrongRate, lessThanOrEqualTo(_maximumHeldOutWrongRate));
    }, skip: skipReason);

    test('the classifier beats the keyword matcher alone on held-out', () {
      final withClassifier = _score(router, _loadHeldOutQueries());
      final keywordOnly = _score(keywordOnlyRouter, _loadHeldOutQueries());
      expect(withClassifier.correct, greaterThan(keywordOnly.correct));
    }, skip: skipReason);

    test('training questions keep routing right', () {
      final tally = _score(router, _loadTrainingQueries());
      printOnFailure('training: $tally');
      expect(tally.accuracy, greaterThanOrEqualTo(_minimumTrainingSetAccuracy));
    }, skip: skipReason);

    test('chit-chat almost never leaks into a data answer', () {
      final queries = _loadChitChatQueries();
      final leaked = queries.where((query) {
        final decision = router.route(query);
        return decision.kind == RouteKind.answerIntent &&
            !_conversationalIntents.contains(decision.matched.intent);
      }).toList();
      printOnFailure('leaked: $leaked');
      expect(
        leaked.length / queries.length,
        lessThanOrEqualTo(_maximumChitChatLeakRate),
      );
    }, skip: skipReason);
  });
}
