import 'package:tinda360/features/chat/data/intent_classifier.dart';
import 'package:tinda360/features/chat/data/yumi_intent_mapper.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';

enum RouteKind {
  answerIntent,

  outOfScope,

  askModel,

  clarify,
}

final class RouteDecision {
  const new({
    required this.kind,
    required this.matched,
    this.toolName,
    this.candidateToolNames = const <String>[],
  });

  final RouteKind kind;

  final String? toolName;

  final List<String> candidateToolNames;

  final MatchedQuery matched;
}

final class IntentRouter {
  const new({required this.matcher, required this.classifier});

  static const double minimumIntentConfidence = 0.45;
  static const double minimumModelAgreement = 0.1;
  static const String noToolClass = 'no_tool';
  static const double minimumCandidateConfidence = 0.12;
  static const int minimumClarificationChoices = 2;
  static const int maximumClarificationChoices = 3;
  static const Set<ChatIntent> conversationalIntents = <ChatIntent>{
    ChatIntent.greeting,
    ChatIntent.thanks,
    ChatIntent.help,
  };

  final IntentMatcher matcher;

  final IntentClassifier? classifier;

  RouteDecision route(String query) {
    final keywordMatch = matcher.match(query);
    final prediction = classifier?.classify(query);
    final isConfident =
        prediction != null && prediction.confidence >= minimumIntentConfidence;
    final keywordFoundIntent = keywordMatch.intent != ChatIntent.overview;
    if (isConfident && prediction.toolName == noToolClass) {
      return RouteDecision(
        kind: keywordFoundIntent
            ? RouteKind.answerIntent
            : RouteKind.outOfScope,
        matched: keywordMatch,
      );
    }
    if (isConfident) {
      return RouteDecision(
        kind: RouteKind.answerIntent,
        toolName: prediction.toolName,
        matched: MatchedQuery(
          intent: toolNameToIntent(prediction.toolName),
          timeframe: keywordMatch.timeframe,
          normalizedText: keywordMatch.normalizedText,
        ),
      );
    }
    final candidates = _plausibleToolNames(query);
    final keywordAgreesWithTopCandidate =
        candidates.isNotEmpty &&
        toolNameToIntent(candidates.first) == keywordMatch.intent;
    final keywordCanAnswer =
        keywordFoundIntent &&
        (candidates.length < minimumClarificationChoices ||
            keywordAgreesWithTopCandidate ||
            conversationalIntents.contains(keywordMatch.intent));
    if (keywordCanAnswer) {
      return RouteDecision(kind: RouteKind.answerIntent, matched: keywordMatch);
    }
    if (candidates.length >= minimumClarificationChoices) {
      return RouteDecision(
        kind: RouteKind.clarify,
        matched: keywordMatch,
        candidateToolNames: candidates,
      );
    }
    return RouteDecision(
      kind: keywordFoundIntent ? RouteKind.answerIntent : RouteKind.askModel,
      matched: keywordMatch,
    );
  }

  List<String> _plausibleToolNames(String query) {
    final loadedClassifier = classifier;
    if (loadedClassifier == null) return const <String>[];
    return loadedClassifier
        .rankedPredictions(query)
        .where(
          (prediction) =>
              prediction.toolName != noToolClass &&
              prediction.confidence >= minimumCandidateConfidence,
        )
        .take(maximumClarificationChoices)
        .map((prediction) => prediction.toolName)
        .toList(growable: false);
  }

  bool acceptsModelTool(String query, String toolName) {
    final loadedClassifier = classifier;
    if (loadedClassifier == null) return true;
    return loadedClassifier.probabilityFor(query, toolName) >=
        minimumModelAgreement;
  }
}
