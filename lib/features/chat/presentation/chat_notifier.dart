import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/chat/data/chat_history_storage.dart';
import 'package:tinda360/features/chat/data/feedback_consent.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';
import 'package:tinda360/features/chat/data/feedback_recorder.dart';
import 'package:tinda360/features/chat/data/intent_classifier.dart';
import 'package:tinda360/features/chat/data/tool_argument_parser.dart';
import 'package:tinda360/features/chat/data/yumi_engine.dart';
import 'package:tinda360/features/chat/data/yumi_intent_mapper.dart';
import 'package:tinda360/features/chat/presentation/chat_reply_builders.dart';
import 'package:tinda360/features/chat/presentation/chat_store_replies.dart';
import 'package:tinda360/features/chat/presentation/chat_tool_result_replies.dart';
import 'package:tinda360/features/chat/presentation/clarification_reply.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';
import 'package:tinda360/features/chat/presentation/intent_router.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';

enum ChatRole {
  user,

  assistant,
}

final class ChatMessage {
  const new({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.source,
    this.options = const <ClarificationOption>[],
    this.clarifiedQuery,
    this.feedbackEventId,
    this.rating,
  });

  final List<ClarificationOption> options;

  final String? clarifiedQuery;

  final String? feedbackEventId;

  final FeedbackRating? rating;

  ChatMessage withFeedback({String? feedbackEventId, FeedbackRating? rating}) =>
      ChatMessage(
        id: id,
        role: role,
        text: text,
        createdAt: createdAt,
        source: source,
        options: options,
        clarifiedQuery: clarifiedQuery,
        feedbackEventId: feedbackEventId ?? this.feedbackEventId,
        rating: rating ?? this.rating,
      );

  final String id;

  final ChatRole role;

  final String text;

  final String? source;

  final DateTime createdAt;
}

final class ChatState {
  const new({
    required this.messages,
    required this.mood,
    required this.isThinking,
  });

  final List<ChatMessage> messages;

  final TindaAvatarMood mood;

  final bool isThinking;

  ChatState copyWith({
    List<ChatMessage>? messages,
    TindaAvatarMood? mood,
    bool? isThinking,
  }) => ChatState(
    messages: messages ?? this.messages,
    mood: mood ?? this.mood,
    isThinking: isThinking ?? this.isThinking,
  );
}

final NotifierProvider<ChatNotifier, ChatState> chatNotifierProvider =
    NotifierProvider.autoDispose<ChatNotifier, ChatState>(
      ChatNotifier.new,
    );

class ChatNotifier extends Notifier<ChatState> {
  Timer? _moodResetTimer;
  Timer? _compactTimer;
  IntentMatcher? _matcher;
  IntentClassifier? _intentClassifier;
  int _sequence = 0;
  String _modelContextSummary = '';
  int _compactedMessageCount = 0;
  String? _lastTokensPerSecondLabel;
  RouteDecision? _lastRouteDecision;
  final Map<String, Future<void>> _feedbackRecordings =
      <String, Future<void>>{};
  Future<void>? _historyRestore;
  String? _historyStoreId;

  @override
  ChatState build() {
    ref.onDispose(() {
      _moodResetTimer?.cancel();
      _moodResetTimer = null;
      _compactTimer?.cancel();
      _compactTimer = null;
    });
    _historyRestore = _restoreHistory();
    unawaited(ref.read(feedbackRecorderProvider).uploadPending());
    return const ChatState(
      messages: <ChatMessage>[],
      mood: TindaAvatarMood.idle,
      isThinking: false,
    );
  }

  String? get _activeStoreId =>
      ref.read(storeRegistryProvider).value?.activeStoreId;

  Future<void> _restoreHistory() async {
    final storeId = _activeStoreId;
    if (storeId == null) return;
    try {
      final stored = await ref.read(chatHistoryStorageProvider).read(storeId);
      if (!ref.mounted) return;
      _historyStoreId = storeId;
      if (state.messages.isNotEmpty || stored.isEmpty) return;
      final restored = <ChatMessage>[
        for (final entry in stored)
          if (_messageFromJson(entry) case final message?) message,
      ];
      _sequence = _highestSequence(restored);
      state = state.copyWith(messages: restored);
      _scheduleIdleCompact();
    } on FormatException catch (error, stack) {
      _historyStoreId = storeId;
      ref.read(appLogProvider).error('chat.history_restore', error, stack);
    } on Object catch (error, stack) {
      ref.read(appLogProvider).error('chat.history_restore', error, stack);
    }
  }

  static int _highestSequence(List<ChatMessage> messages) {
    var highest = messages.length;
    for (final message in messages) {
      final separator = message.id.lastIndexOf('_');
      final parsed = int.tryParse(message.id.substring(separator + 1));
      if (parsed != null && parsed > highest) highest = parsed;
    }
    return highest;
  }

  Future<void> _persistHistory() async {
    final storeId = _historyStoreId;
    if (storeId == null) return;
    try {
      await ref
          .read(chatHistoryStorageProvider)
          .write(storeId, state.messages.map(_messageToJson).toList());
    } on Object catch (error, stack) {
      ref.read(appLogProvider).error('chat.history_persist', error, stack);
    }
  }

  static Map<String, Object?> _messageToJson(ChatMessage message) =>
      <String, Object?>{
        'id': message.id,
        'role': message.role.name,
        'text': message.text,
        'source': message.source,
        'created_at_ms': message.createdAt.millisecondsSinceEpoch,
        'clarified_query': ?message.clarifiedQuery,
        if (message.options.isNotEmpty)
          'options': <Map<String, String>>[
            for (final option in message.options)
              <String, String>{'tool': option.toolName, 'label': option.label},
          ],
      };

  static List<ClarificationOption> _optionsFromJson(Object? rawOptions) {
    if (rawOptions is! List) return const <ClarificationOption>[];
    return <ClarificationOption>[
      for (final rawOption in rawOptions)
        if (rawOption case {
          'tool': final String toolName,
          'label': final String label,
        })
          ClarificationOption(toolName: toolName, label: label),
    ];
  }

  static ChatMessage? _messageFromJson(Map<String, Object?> json) {
    final id = json['id'];
    final role = json['role'];
    final text = json['text'];
    final createdAtMs = json['created_at_ms'];
    if (id is! String || text is! String || createdAtMs is! int) return null;
    final parsedRole = ChatRole.values.where((value) => value.name == role);
    if (parsedRole.isEmpty) return null;
    final source = json['source'];
    final clarifiedQuery = json['clarified_query'];
    return ChatMessage(
      id: id,
      role: parsedRole.first,
      text: text,
      source: source is String ? source : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      options: _optionsFromJson(json['options']),
      clarifiedQuery: clarifiedQuery is String ? clarifiedQuery : null,
    );
  }

  Future<void> sendMessage(String rawText, AppLocalizations localizations) =>
      _send(rawText, localizations, queryText: rawText);

  Future<void> answerClarification(
    ChatMessage clarification,
    ClarificationOption option,
    AppLocalizations localizations,
  ) async {
    final originalQuery = clarification.clarifiedQuery;
    final isOfferedOption = clarification.options.any(
      (offered) => offered.toolName == option.toolName,
    );
    if (originalQuery == null || !isOfferedOption) return;
    unawaited(_recordChosenTool(clarification, option.toolName));
    return _send(
      option.label,
      localizations,
      queryText: originalQuery,
      forcedToolName: option.toolName,
    );
  }

  Future<void> _send(
    String rawText,
    AppLocalizations localizations, {
    required String queryText,
    String? forcedToolName,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty || state.isThinking) return;
    await _historyRestore;
    if (!ref.mounted || state.isThinking) return;

    _moodResetTimer?.cancel();
    final now = ref.read(clockProvider).now();
    final userMessage = ChatMessage(
      id: 'user_${++_sequence}',
      role: ChatRole.user,
      text: trimmed,
      createdAt: now,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      mood: TindaAvatarMood.thinking,
      isThinking: true,
    );

    _lastTokensPerSecondLabel = null;
    final thinkingStarted = DateTime.now();
    AssistantReply reply;
    try {
      reply = await _answerFromStoreData(
        queryText.trim(),
        now,
        localizations,
        forcedToolName: forcedToolName,
      );
    } on Object catch (error, stack) {
      ref.read(appLogProvider).error('chat.answer', error, stack);
      reply = AssistantReply(
        text: localizations.chatErrorReply,
        source: localizations.chatSourceSummary,
        mood: TindaAvatarMood.talking,
      );
    }
    final elapsed = DateTime.now().difference(thinkingStarted);
    const minimumThinking = Duration(milliseconds: 900);
    if (elapsed < minimumThinking) {
      await Future<void>.delayed(minimumThinking - elapsed);
    }
    if (!ref.mounted) return;

    final assistantMessage = ChatMessage(
      id: 'assistant_${++_sequence}',
      role: ChatRole.assistant,
      text: reply.text,
      source: _lastTokensPerSecondLabel == null
          ? reply.source
          : '${reply.source} · $_lastTokensPerSecondLabel',
      createdAt: ref.read(clockProvider).now(),
      options: reply.options,
      clarifiedQuery: reply.options.isEmpty ? null : queryText.trim(),
    );

    state = state.copyWith(
      messages: [...state.messages, assistantMessage],
      mood: reply.mood,
      isThinking: false,
    );

    _moodResetTimer = Timer(const Duration(milliseconds: 1800), () {
      state = state.copyWith(mood: TindaAvatarMood.idle);
    });
    _scheduleIdleCompact();
    unawaited(_persistHistory());
    final decision = _lastRouteDecision;
    if (forcedToolName == null && decision != null) {
      final messageId = assistantMessage.id;
      final recording = _recordFeedback(
        messageId,
        queryText.trim(),
        decision,
        localizations.localeName,
      );
      _feedbackRecordings[messageId] = recording;
      unawaited(
        recording.whenComplete(() => _feedbackRecordings.remove(messageId)),
      );
    }
  }

  Future<void> _recordChosenTool(
    ChatMessage clarification,
    String toolName,
  ) async {
    final recorder = ref.read(feedbackRecorderProvider);
    await _feedbackRecordings[clarification.id];
    if (!ref.mounted) return;
    final current = state.messages.where(
      (message) => message.id == clarification.id,
    );
    final feedbackEventId = current.isEmpty
        ? clarification.feedbackEventId
        : current.first.feedbackEventId;
    if (feedbackEventId == null) return;
    await recorder.recordChosenTool(feedbackEventId, toolName);
  }

  Future<void> rateMessage(ChatMessage message, FeedbackRating rating) async {
    final feedbackEventId = message.feedbackEventId;
    if (feedbackEventId == null) return;
    final saved = await ref
        .read(feedbackRecorderProvider)
        .rate(feedbackEventId, rating);
    if (!saved || !ref.mounted) return;
    _replaceMessage(
      message.id,
      (current) => current.withFeedback(rating: rating),
    );
  }

  Future<void> _recordFeedback(
    String messageId,
    String query,
    RouteDecision decision,
    String locale,
  ) async {
    final recorder = ref.read(feedbackRecorderProvider);
    final appLog = ref.read(appLogProvider);
    final productRepository = ref.read(productRepositoryProvider);
    final customerRepository = ref.read(customerRepositoryProvider);
    final consentStore = ref.read(feedbackConsentStoreProvider);
    try {
      if (!await consentStore.read()) return;
      final products = await productRepository.watchActive().first;
      final balances = await customerRepository.watchBalances().first;
      final candidates = decision.candidateToolNames;
      final feedbackEventId = await recorder.record(
        query: query,
        locale: locale,
        routeKind: decision.kind.name,
        toolName:
            decision.toolName ?? (candidates.isEmpty ? null : candidates.first),
        confidence: decision.confidence,
        customerNames: balances.map((balance) => balance.customer.name),
        productNames: products.map((stocked) => stocked.product.name),
      );
      if (feedbackEventId == null || !ref.mounted) return;
      _replaceMessage(
        messageId,
        (current) => current.withFeedback(feedbackEventId: feedbackEventId),
      );
    } on Object catch (error, stack) {
      appLog.error('chat.feedback_names', error, stack);
    }
  }

  void _replaceMessage(
    String messageId,
    ChatMessage Function(ChatMessage current) update,
  ) {
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          message.id == messageId ? update(message) : message,
      ],
    );
  }

  Future<ChatClassification> _classifyQuery(
    String query, {
    String? forcedToolName,
  }) async {
    final matcher = _matcher ??= await IntentMatcher.loadFromAsset();
    _lastRouteDecision = null;
    if (forcedToolName != null) {
      final keywordMatch = matcher.match(query);
      final decision = RouteDecision(
        kind: RouteKind.answerIntent,
        toolName: forcedToolName,
        matched: MatchedQuery(
          intent: toolNameToIntent(forcedToolName),
          timeframe: keywordMatch.timeframe,
          normalizedText: keywordMatch.normalizedText,
        ),
      );
      return _withExplicitArguments(
        query,
        decision,
        ChatClassification(matched: decision.matched),
      );
    }
    final router = IntentRouter(
      matcher: matcher,
      classifier: await _loadIntentClassifier(),
    );
    final decision = router.route(query);
    _lastRouteDecision = decision;
    final routed = ChatClassification(matched: decision.matched);
    return switch (decision.kind) {
      RouteKind.answerIntent => _withExplicitArguments(query, decision, routed),
      RouteKind.outOfScope => _outOfScopeClassification(routed),
      RouteKind.askModel => _classifyWithModel(query, router, routed),
      RouteKind.clarify => ChatClassification(
        matched: decision.matched,
        clarificationToolNames: decision.candidateToolNames,
      ),
    };
  }

  Future<ChatClassification> _withExplicitArguments(
    String query,
    RouteDecision decision,
    ChatClassification routed,
  ) async {
    final toolName = decision.toolName;
    if (toolName == null) return routed;
    final arguments = const ToolArgumentParser().parse(
      toolName,
      query,
      timeframe: decision.matched.timeframe.name,
    );
    if (arguments == null) return routed;
    final withTool = ChatClassification(
      matched: decision.matched,
      toolName: toolName,
      toolArgs: arguments,
    );
    final toolResult = await _executeModelTool(withTool);
    if (toolResult == null || toolResult['error'] != null) return routed;
    return ChatClassification(
      matched: decision.matched,
      toolName: toolName,
      toolArgs: arguments,
      toolResult: toolResult,
    );
  }

  ChatClassification _outOfScopeClassification(ChatClassification keyword) =>
      ChatClassification(matched: keyword.matched, isOutOfScope: true);

  Future<IntentClassifier?> _loadIntentClassifier() async {
    try {
      return _intentClassifier ??= await IntentClassifier.loadFromAsset();
    } on Object catch (error, stack) {
      ref.read(appLogProvider).error('chat.intent_classifier', error, stack);
      return null;
    }
  }

  Future<ChatClassification> _classifyWithModel(
    String query,
    IntentRouter router,
    ChatClassification keywordClassification,
  ) async {
    final engine = ref.read(yumiEngineProvider);
    if (!engine.isReady) {
      try {
        await ref.read(yumiWarmupProvider.future);
      } on Object catch (error, stack) {
        ref.read(appLogProvider).error('chat.engine_init', error, stack);
      }
    }
    if (!engine.isReady) return keywordClassification;
    final outOfScope = _outOfScopeClassification(keywordClassification);
    try {
      final result = await engine.infer(
        query,
        contextSummary: _modelContextSummary,
        recentTurns: _recentTurnsForModel(limit: 4),
      );
      if (result.generatedTokens > 0) {
        _lastTokensPerSecondLabel =
            '${result.tokensPerSecond.toStringAsFixed(1)} tok/s';
      }
      final toolName = result.toolName;
      if (toolName == null) return outOfScope;
      if (!router.acceptsModelTool(query, toolName)) return outOfScope;
      final classification = yumiResultToClassification(result, query);
      final toolResult = await _executeModelTool(classification);
      if (toolResult?['error'] == 'unknown_tool') return outOfScope;
      return ChatClassification(
        matched: classification.matched,
        toolName: classification.toolName,
        toolArgs: classification.toolArgs,
        toolResult: toolResult,
      );
    } on Object catch (error, stack) {
      ref.read(appLogProvider).error('chat.engine_infer', error, stack);
      return keywordClassification;
    }
  }

  Future<Map<String, dynamic>?> _executeModelTool(
    ChatClassification classification,
  ) async {
    final toolName = classification.toolName;
    if (toolName == null) return null;
    try {
      return await ref
          .read(yumiToolExecutorProvider)
          .execute(
            toolName,
            classification.toolArgs ?? const <String, dynamic>{},
          );
    } on Object catch (error, stack) {
      ref.read(appLogProvider).error('chat.tool_execute', error, stack);
      return null;
    }
  }

  List<YumiTurn> _recentTurnsForModel({required int limit}) {
    final messages = state.messages;
    if (messages.length <= 1) return const <YumiTurn>[];
    final history = messages.sublist(0, messages.length - 1);
    final tail = history.length <= limit
        ? history
        : history.sublist(history.length - limit);
    return tail
        .map(
          (message) => message.role == ChatRole.user
              ? YumiTurn.user(message.text)
              : YumiTurn.assistant(message.text),
        )
        .toList(growable: false);
  }

  void _scheduleIdleCompact() {
    _compactTimer?.cancel();
    _compactTimer = Timer(
      const Duration(seconds: 4),
      _compactModelContextIfIdle,
    );
  }

  void _compactModelContextIfIdle() {
    if (!ref.mounted || state.isThinking) return;
    final messages = state.messages;
    const keepTail = 4;
    final compactUntil = messages.length - keepTail;
    if (compactUntil <= _compactedMessageCount) return;
    if (compactUntil - _compactedMessageCount < 2) return;

    final engine = ref.read(yumiEngineProvider);
    if (!engine.isReady) return;

    final toCompact = messages
        .sublist(_compactedMessageCount, compactUntil)
        .map(
          (message) => message.role == ChatRole.user
              ? YumiTurn.user(message.text)
              : YumiTurn.assistant(message.text),
        )
        .toList(growable: false);
    final freshSummary = engine.compactTurns(toCompact, maxCharsPerTurn: 72);
    if (freshSummary.isEmpty) {
      _compactedMessageCount = compactUntil;
      return;
    }

    if (_modelContextSummary.isEmpty) {
      _modelContextSummary = freshSummary;
    } else {
      final previous = _modelContextSummary.startsWith('Dating usapan:\n')
          ? _modelContextSummary.substring('Dating usapan:\n'.length)
          : _modelContextSummary;
      final merged =
          '$previous\n${freshSummary.replaceFirst('Dating usapan:\n', '')}';
      final mergedLines = merged
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      final clipped = mergedLines.length <= 8
          ? mergedLines
          : mergedLines.sublist(mergedLines.length - 8);
      _modelContextSummary = 'Dating usapan:\n${clipped.join('\n')}';
    }
    _compactedMessageCount = compactUntil;
  }

  bool _toolAnswersMentionedEntity(
    String toolName,
    Map<String, dynamic> toolResult, {
    required bool mentionsProduct,
    required bool mentionsCustomer,
  }) {
    if (!mentionsProduct && !mentionsCustomer) return true;
    if (!mentionsProduct) return false;
    final isProductTool =
        toolName == 'get_product_info' || toolName == 'get_stock_forecast';
    return isProductTool && toolResult['found'] != false;
  }

  AssistantReply _fromStoreReply(
    StoreReplyText storeReply,
    AppLocalizations localizations,
  ) => AssistantReply(
    text: storeReply.text,
    source: localizations.chatSourceSummary,
    mood: storeReply.mood,
  );

  Future<AssistantReply> _answerFromStoreData(
    String query,
    DateTime now,
    AppLocalizations localizations, {
    String? forcedToolName,
  }) async {
    final classification = await _classifyQuery(
      query,
      forcedToolName: forcedToolName,
    );
    final matched = classification.matched;
    final isFilipino = localizations.localeName.startsWith('fil');
    final clarificationOptions = buildClarificationOptions(
      classification.clarificationToolNames,
      isFilipino: isFilipino,
    );
    if (clarificationOptions.length >=
        IntentRouter.minimumClarificationChoices) {
      return buildClarificationReply(
        clarificationOptions,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.greeting) {
      return buildGreetingReply(now, isFilipino, localizations);
    }
    if (matched.intent == ChatIntent.thanks) {
      return buildThanksReply(isFilipino, localizations);
    }
    if (matched.intent == ChatIntent.help) {
      return buildHelpReply(isFilipino, localizations);
    }
    if (classification.isOutOfScope) {
      return buildOutOfScopeReply(isFilipino, localizations);
    }

    final currency = ref.read(storeCurrencyProvider);
    final today = LocalDay.fromLocal(now);
    final range = rangeForTimeframe(matched.timeframe, today);

    final results = await Future.wait([
      ref.read(productRepositoryProvider).watchActive().first,
      ref.read(saleRepositoryProvider).watchSummary(range).first,
      ref.read(saleRepositoryProvider).watchTopProducts(range).first,
      ref.read(customerRepositoryProvider).watchBalances().first,
    ]);

    final products = results[0] as List<StockedProduct>;
    final summary = results[1] as SalesSummary;
    final topProducts = results[2] as List<TopProduct>;
    final balances = results[3] as List<CustomerBalance>;

    final matchedProduct = findMentionedProduct(
      matched.normalizedText,
      products,
    );
    final matchedCustomer = findMentionedCustomer(
      matched.normalizedText,
      balances,
    );

    final toolName = classification.toolName;
    final toolResult = classification.toolResult;
    if (toolName != null &&
        toolResult != null &&
        _toolAnswersMentionedEntity(
          toolName,
          toolResult,
          mentionsProduct: matchedProduct != null,
          mentionsCustomer: matchedCustomer != null,
        )) {
      final fromTool = replyFromToolResult(
        toolName: toolName,
        result: toolResult,
        isFilipino: isFilipino,
        localizations: localizations,
        currency: currency,
      );
      if (fromTool != null) return fromTool;
    }

    if (matchedProduct != null && matched.intent != ChatIntent.stockForecast) {
      return buildProductLookupReply(matchedProduct, isFilipino, localizations);
    }

    if (matchedCustomer != null) {
      return buildCustomerLookupReply(
        matchedCustomer,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.salesCompare) {
      final todayRange = DayRange.single(today);
      final yesterdayRange = DayRange.single(today.plusDays(-1));
      final todaySummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(todayRange)
          .first;
      final yesterdaySummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(yesterdayRange)
          .first;
      return buildSalesCompareReply(
        todaySummary,
        yesterdaySummary,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.slowMoving) {
      final twoWeeksRange = DayRange(today.plusDays(-13), today);
      final soldIds = await ref
          .read(saleRepositoryProvider)
          .soldProductIdsInRange(twoWeeksRange);
      return buildSlowMovingReply(products, soldIds, isFilipino, localizations);
    }

    if (matched.intent == ChatIntent.utangRisk) {
      final expenses = await ref
          .read(expenseRepositoryProvider)
          .watchInRange(range)
          .first;
      return buildUtangRiskReply(
        summary,
        balances,
        expenses,
        currency,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.storeInfo) {
      final storeProfile = await ref
          .read(storeProfileRepositoryProvider)
          .watch()
          .first;
      final storeReply = storeInfoReply(
        storeName: storeProfile.name,
        products: products,
        isFilipino: isFilipino,
      );
      return _fromStoreReply(storeReply, localizations);
    }

    if (matched.intent == ChatIntent.productCount) {
      final storeReply = productCountReply(
        products: products,
        isFilipino: isFilipino,
      );
      return _fromStoreReply(storeReply, localizations);
    }

    if (matched.intent == ChatIntent.expenses) {
      final expenses = await ref
          .read(expenseRepositoryProvider)
          .watchInRange(range)
          .first;
      final storeReply = expensesReply(
        expenses: expenses,
        summary: summary,
        periodLabel: timeframeLabel(matched.timeframe, isFilipino),
        isFilipino: isFilipino,
      );
      return _fromStoreReply(storeReply, localizations);
    }

    if (matched.intent == ChatIntent.expiryAlert) {
      return buildExpiryAlertReply(products, today, isFilipino, localizations);
    }

    if (matched.intent == ChatIntent.profitMargin) {
      return buildProfitMarginReply(products, isFilipino, localizations);
    }

    if (matched.intent == ChatIntent.salesTrend) {
      final todaySummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(DayRange.single(today))
          .first;
      final yesterdaySummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(DayRange.single(today.plusDays(-1)))
          .first;
      final twoDaysAgoSummary = await ref
          .read(saleRepositoryProvider)
          .watchSummary(DayRange.single(today.plusDays(-2)))
          .first;
      return buildSalesTrendReply(
        todaySummary,
        yesterdaySummary,
        twoDaysAgoSummary,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.busiestHours) {
      final recentSales = await ref
          .read(saleRepositoryProvider)
          .watchRecentSales(range, limit: null)
          .first;
      return buildBusiestHoursReply(recentSales, isFilipino, localizations);
    }

    if (matched.intent == ChatIntent.sukiLoyalty) {
      final recentSales = await ref
          .read(saleRepositoryProvider)
          .watchRecentSales(range, limit: null)
          .first;
      return buildSukiLoyaltyReply(recentSales, isFilipino, localizations);
    }

    if (matched.intent == ChatIntent.paymentBreakdown) {
      final recentSales = await ref
          .read(saleRepositoryProvider)
          .watchRecentSales(range, limit: null)
          .first;
      return buildPaymentBreakdownReply(
        recentSales,
        currency,
        isFilipino,
        localizations,
      );
    }

    if (matched.intent == ChatIntent.stockForecast) {
      final mentionedProduct = findMentionedProduct(
        matched.normalizedText,
        products,
      );
      final twoWeeksRange = DayRange(today.plusDays(-13), today);
      final soldQuantities = await ref
          .read(saleRepositoryProvider)
          .soldProductQuantitiesInRange(twoWeeksRange);
      return buildStockForecastReply(
        mentionedProduct,
        products,
        soldQuantities,
        isFilipino,
        localizations,
        namesUnknownProduct: namesUnknownProduct(matched.normalizedText),
      );
    }

    return switch (matched.intent) {
      ChatIntent.topProducts => buildTopProductsReply(
        topProducts,
        matched.timeframe,
        isFilipino,
        localizations,
      ),
      ChatIntent.lowStock => buildLowStockReply(products, localizations),
      ChatIntent.restockBudget => buildRestockBudgetReply(
        products,
        currency,
        isFilipino,
        localizations,
      ),
      ChatIntent.utang => buildUtangReply(balances, currency, localizations),
      ChatIntent.sales => buildSalesReply(
        summary,
        matched.timeframe,
        isFilipino,
        localizations,
      ),
      ChatIntent.productLookup => buildProductPromptReply(
        isFilipino,
        localizations,
        namesUnknownProduct: namesUnknownProduct(matched.normalizedText),
      ),
      _ => buildOverviewReply(
        products,
        summary,
        balances,
        currency,
        localizations,
      ),
    };
  }
}
