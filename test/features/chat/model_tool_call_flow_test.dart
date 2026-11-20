import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failures/product_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/chat/data/yumi_engine.dart';
import 'package:tinda360/features/chat/presentation/chat_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';

import '../../support/test_repositories.dart';

const String _modelQuestion = 'Bingo biscuit status';

final class _ScriptedEngine implements YumiInference {
  new(this.reply);

  final YumiInferResult reply;

  int inferCalls = 0;

  @override
  bool get isReady => true;

  @override
  Future<void> init() async {}

  @override
  Future<YumiInferResult> infer(
    String userQuery, {
    String contextSummary = '',
    List<YumiTurn> recentTurns = const <YumiTurn>[],
  }) async {
    inferCalls++;
    return reply;
  }

  @override
  String compactTurns(List<YumiTurn> turns, {int maxCharsPerTurn = 96}) => '';
}

Money _php(int centavos) => Money(centavos, Currency.php);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestRepositories repos;

  setUp(() async {
    repos = TestRepositories();
    for (final (name, price) in [
      ('Bingo biscuit', 1000),
      ('Datu Puti suka', 2500),
    ]) {
      final created = await repos.products.create(
        ProductDraft(
          name: name,
          unit: ProductUnit.piece,
          price: _php(price),
          cost: _php(price - 200),
          initialStock: const Quantity.whole(7),
        ),
      );
      expect(created, isA<Ok<String, ProductFailure>>());
    }
  });

  tearDown(() => repos.close());

  Future<(String, int)> ask(YumiInferResult modelReply) async {
    final engine = _ScriptedEngine(modelReply);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(repos.db),
        clockProvider.overrideWithValue(repos.clock),
        appLogProvider.overrideWithValue(repos.log),
        yumiEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(chatNotifierProvider, (_, _) {});
    addTearDown(subscription.close);
    await container
        .read(chatNotifierProvider.notifier)
        .sendMessage(
          _modelQuestion,
          lookupAppLocalizations(const Locale('en')),
        );
    final messages = container.read(chatNotifierProvider).messages;
    return (messages.last.text, engine.inferCalls);
  }

  test(
    'a wrong product name from the model is answered with the one asked',
    () async {
      final (reply, inferCalls) = await ask(
        const YumiInferResult(
          rawText: '',
          toolName: 'get_product_info',
          toolArgs: {'product_name': 'Datu Puti suka'},
        ),
      );
      expect(inferCalls, 1);
      expect(reply, contains('Bingo biscuit'));
      expect(reply, isNot(contains('Datu Puti')));
    },
  );

  test(
    'a product tool call with no name still answers the asked product',
    () async {
      final (reply, inferCalls) = await ask(
        const YumiInferResult(
          rawText: '',
          toolName: 'get_product_info',
          toolArgs: {},
        ),
      );
      expect(inferCalls, 1);
      expect(reply, contains('Bingo biscuit'));
    },
  );
}
