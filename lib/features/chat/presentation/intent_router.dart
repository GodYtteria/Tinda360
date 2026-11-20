import 'package:tinda360/features/chat/data/intent_classifier.dart';
import 'package:tinda360/features/chat/data/yumi_intent_mapper.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';

enum RouteKind {
  answerIntent,

  outOfScope,

  askModel,
}

final class RouteDecision {
  const new({required this.kind, required this.matched, this.toolName});

  final RouteKind kind;

  final String? toolName;

  final MatchedQuery matched;
}

final class IntentRouter {
  const new({required this.matcher, required this.classifier});

  static const double minimumIntentConfidence = 0.45;
  static const double minimumModelAgreement = 0.1;
  static const String noToolClass = 'no_tool';

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
    return RouteDecision(
      kind: keywordFoundIntent ? RouteKind.answerIntent : RouteKind.askModel,
      matched: keywordMatch,
    );
  }

  bool acceptsModelTool(String query, String toolName) {
    final loadedClassifier = classifier;
    if (loadedClassifier == null) return true;
    return loadedClassifier.probabilityFor(query, toolName) >=
        minimumModelAgreement;
  }
}
