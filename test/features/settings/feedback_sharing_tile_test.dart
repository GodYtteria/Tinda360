import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/chat/data/feedback_consent.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';
import 'package:tinda360/features/settings/presentation/feedback_sharing_tile.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/theme/app_theme.dart';

final class _MemoryConsentStore implements FeedbackConsentStore {
  new({required this.granted});

  bool granted;

  @override
  Future<bool> read() async => granted;

  @override
  Future<void> write({required bool granted}) async => this.granted = granted;
}

const int fileSettleRounds = 10;
const Duration fileSettleDelay = Duration(milliseconds: 20);

void main() {
  late Directory directory;
  late FeedbackLog log;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('feedback_tile_test');
    log = FeedbackLog(directoryProvider: () async => directory);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> pumpTile(WidgetTester tester, _MemoryConsentStore store) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedbackConsentStoreProvider.overrideWithValue(store),
          feedbackLogProvider.overrideWithValue(log),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: FeedbackSharingTile()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TindaToggleSwitch toggle(WidgetTester tester) =>
      tester.widget<TindaToggleSwitch>(find.byType(TindaToggleSwitch));

  testWidgets('sharing is off until the owner turns it on', (tester) async {
    final store = _MemoryConsentStore(granted: false);
    await pumpTile(tester, store);
    expect(toggle(tester).value, isFalse);
    expect(find.text('Help improve Yumi'), findsOneWidget);
    expect(find.textContaining('never sent'), findsOneWidget);
  });

  testWidgets('turning it on stores consent', (tester) async {
    final store = _MemoryConsentStore(granted: false);
    await pumpTile(tester, store);
    await tester.tap(find.byType(TindaToggleSwitch));
    await tester.pumpAndSettle();
    expect(store.granted, isTrue);
    expect(toggle(tester).value, isTrue);
  });

  testWidgets('turning it off stores the refusal and deletes queued events', (
    tester,
  ) async {
    final store = _MemoryConsentStore(granted: true);
    await tester.runAsync(
      () => log.append(
        const FeedbackEvent(
          id: '0123456789abcdef',
          createdDay: '2026-03-07',
          appVersion: '1.0.0',
          locale: 'en',
          query: 'sales today',
          routeKind: 'answerIntent',
        ),
      ),
    );
    await pumpTile(tester, store);
    expect(toggle(tester).value, isTrue);
    await tester.tap(find.byType(TindaToggleSwitch));
    for (var round = 0; round < fileSettleRounds; round++) {
      await tester.runAsync(() => Future<void>.delayed(fileSettleDelay));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(store.granted, isFalse);
    expect(toggle(tester).value, isFalse);
    expect(await tester.runAsync(log.readAll), isEmpty);
  });

  testWidgets('the tile fits a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTile(tester, _MemoryConsentStore(granted: false));
    expect(tester.takeException(), isNull);
  });
}
