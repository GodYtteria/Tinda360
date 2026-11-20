import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/chat/data/chat_history_storage.dart';
import 'package:tinda360/features/chat/data/feedback_consent.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';
import 'package:tinda360/features/chat/data/product_argument_grounding.dart';
import 'package:tinda360/features/chat/data/tool_call_validator.dart';
import 'package:tinda360/features/chat/data/yumi_engine.dart';
import 'package:tinda360/features/chat/presentation/chat_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';

import '../test/support/test_repositories.dart';

const List<(String, String)> _productNames = [
  ('Bingo biscuit', 'bingo biscuit'),
  ('Kopiko Brown', 'kopiko brown'),
  ('Lucky Me Pancit Canton', 'pancit canton'),
  ('Datu Puti suka', 'datu puti suka'),
];

const List<(String, String)> _questions = [
  ('Bingo biscuit status', 'bingo biscuit'),
  ('ilan pa ang natitirang Bingo biscuit sa estante', 'bingo biscuit'),
  ('magkano ang Kopiko Brown ngayon', 'kopiko brown'),
  ('kailan mauubos ang pancit canton', 'pancit canton'),
  ('how much is the Kopiko Brown', 'kopiko brown'),
  ('ilang araw pa bago maubos ang Bingo biscuit', 'bingo biscuit'),
];

const Duration _slowestAnswer = Duration(seconds: 20);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestRepositories repos;
  late List<StockedProduct> inventory;
  late Directory scratch;

  setUpAll(() async {
    await YumiEngine.instance.init();
  });

  tearDownAll(YumiEngine.instance.dispose);

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('model_device_test');
    repos = TestRepositories();
    for (final (name, _) in _productNames) {
      final created = await repos.products.create(
        ProductDraft(
          name: name,
          unit: ProductUnit.piece,
          price: const Money(1500, Currency.php),
          cost: const Money(1200, Currency.php),
          initialStock: const Quantity.whole(9),
        ),
      );
      expect(created, isA<Ok<String, ProductFailure>>());
    }
    inventory = await repos.products.watchActive().first;
  });

  tearDown(() async {
    await repos.close();
    await scratch.delete(recursive: true);
  });

  testWidgets('the real model on the phone answers inside the time limit', (
    tester,
  ) async {
    expect(YumiEngine.instance.isReady, isTrue);
    final stopwatch = Stopwatch()..start();
    final result = await YumiEngine.instance.infer(_questions.first.$1);
    stopwatch.stop();
    debugPrint(
      'DEVICE speed: ${result.generatedTokens} tokens in '
      '${stopwatch.elapsedMilliseconds} ms',
    );
    expect(result.generatedTokens, greaterThan(0));
    expect(stopwatch.elapsed, lessThan(_slowestAnswer));
  });

  testWidgets(
    'every product call from the real model is grounded in the question',
    (
      tester,
    ) async {
      final validator = ToolCallValidator.fromToolsJson(
        await rootBundle.loadString(YumiEngine.toolsAsset),
      );
      var productCalls = 0;
      for (final (question, askedProduct) in _questions) {
        final result = await YumiEngine.instance.infer(question);
        final toolName = result.toolName;
        debugPrint('DEVICE model: "$question" -> $toolName ${result.toolArgs}');
        if (toolName == null || !productToolNames.contains(toolName)) continue;
        productCalls++;
        final grounded = groundProductArgument(
          toolName,
          result.toolArgs ?? const <String, dynamic>{},
          question,
          inventory,
        );
        expect(grounded, isNotNull, reason: question);
        expect(
          (grounded![productArgumentName] as String).toLowerCase(),
          askedProduct,
          reason: question,
        );
        final validation = validator.validate(
          toolName,
          grounded,
          question: question,
        );
        expect(validation.isValid, isTrue, reason: question);
      }
      debugPrint(
        'DEVICE product tool calls: $productCalls of ${_questions.length}',
      );
      expect(
        productCalls,
        greaterThanOrEqualTo(_questions.length ~/ 2),
      );
    },
  );

  testWidgets(
    'a reply through the real model never names a product not asked',
    (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(repos.db),
          clockProvider.overrideWithValue(repos.clock),
          appLogProvider.overrideWithValue(repos.log),
          chatDirectoryProvider.overrideWithValue(() async => scratch),
          chatFeedbackDirectoryProvider.overrideWithValue(() async => scratch),
          feedbackConsentStoreProvider.overrideWithValue(
            FileFeedbackConsentStore(directoryProvider: () async => scratch),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(chatNotifierProvider, (_, _) {});
      addTearDown(subscription.close);
      final localizations = lookupAppLocalizations(const Locale('en'));
      for (final (question, askedProduct) in _questions) {
        await container
            .read(chatNotifierProvider.notifier)
            .sendMessage(question, localizations);
        final reply = container.read(chatNotifierProvider).messages.last.text;
        debugPrint('DEVICE reply: "$question" -> $reply');
        expect(repos.log.events, isNot(contains('chat.answer')));
        expect(reply, isNot(localizations.chatErrorReply), reason: question);
        expect(
          reply,
          isNot(lookupAppLocalizations(const Locale('fil')).chatErrorReply),
          reason: question,
        );
        for (final (name, mention) in _productNames) {
          if (mention == askedProduct) continue;
          expect(
            reply.toLowerCase(),
            isNot(contains(name.split(' ').first.toLowerCase())),
            reason: question,
          );
        }
      }
    },
  );
}
