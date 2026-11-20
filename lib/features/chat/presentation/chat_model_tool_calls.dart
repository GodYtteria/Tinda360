part of 'chat_notifier.dart';

mixin _ModelToolCalls on Notifier<ChatState> {
  String get _modelContextSummary;

  set _lastTokensPerSecondLabel(String? label);

  ChatClassification _outOfScopeClassification(ChatClassification keyword);

  Future<ToolCallValidator?> _loadToolCallValidator();

  Future<Map<String, dynamic>?> _groundProductArgument(
    String toolName,
    Map<String, dynamic> modelArguments,
    String query,
  ) async {
    if (!needsProductGrounding(toolName, modelArguments)) {
      return modelArguments;
    }
    final products = await ref
        .read(productRepositoryProvider)
        .watchActive()
        .first;
    return groundProductArgument(toolName, modelArguments, query, products);
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
      final groundedArguments = await _groundProductArgument(
        toolName,
        result.toolArgs ?? const <String, dynamic>{},
        query,
      );
      if (groundedArguments == null) {
        return ChatClassification(
          matched: MatchedQuery(
            intent: toolNameToIntent(toolName),
            timeframe: keywordClassification.matched.timeframe,
            normalizedText: keywordClassification.matched.normalizedText,
          ),
        );
      }
      final validator = await _loadToolCallValidator();
      final validation = validator?.validate(
        toolName,
        groundedArguments,
        question: query,
      );
      if (validation == null || !validation.isValid) {
        ref
            .read(appLogProvider)
            .error(
              'chat.model_tool_rejected',
              StateError(
                '${validation?.rejection} ${validation?.rejectedArgument}',
              ),
              StackTrace.current,
            );
        return outOfScope;
      }
      final classification = yumiResultToClassification(
        YumiInferResult(
          rawText: result.rawText,
          toolName: validation.toolName,
          toolArgs: validation.arguments,
        ),
        query,
      );
      final withTool = ChatClassification(
        matched: classification.matched,
        toolName: validation.toolName,
        toolArgs: validation.arguments,
      );
      final toolResult = await _executeModelTool(withTool);
      if (toolResult?['error'] == 'unknown_tool') return outOfScope;
      return ChatClassification(
        matched: classification.matched,
        toolName: validation.toolName,
        toolArgs: validation.arguments,
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
}
