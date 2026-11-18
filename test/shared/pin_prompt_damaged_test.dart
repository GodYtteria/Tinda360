import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/l10n/app_delegates.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/store_pin_service.dart';
import 'package:tinda360/shared/widgets/pin_prompt_dialog.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder target, {
  Finder? whileAlsoGone,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    final targetVisible = target.evaluate().isNotEmpty;
    final otherGone = whileAlsoGone == null || whileAlsoGone.evaluate().isEmpty;
    if (targetVisible && otherGone) return;
  }
}

void main() {
  late Directory tempDirectory;
  late StorePinService pinService;

  setUp(() async {
    tempDirectory = Directory.systemTemp.createTempSync('tinda360_pin_ui_');
    pinService = StorePinService(directoryProvider: () async => tempDirectory);
    await pinService.setPin('4829');
    File('${tempDirectory.path}/tinda360_pin.json').writeAsStringSync('{bro');
  });

  tearDown(() => tempDirectory.deleteSync(recursive: true));

  Future<bool?> openPrompt(
    WidgetTester tester, {
    Future<void> Function()? onRemoveDamagedPin,
  }) async {
    bool? promptResult;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              promptResult = await showPinPromptDialog(
                context,
                title: 'Enter PIN',
                pinService: pinService,
                onRemoveDamagedPin: onRemoveDamagedPin,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpUntilFound(tester, find.textContaining('PIN data is damaged'));
    return promptResult;
  }

  testWidgets('damaged PIN with no other unlock offers removal that unlocks', (
    tester,
  ) async {
    var removeCalls = 0;
    await openPrompt(
      tester,
      onRemoveDamagedPin: () async {
        removeCalls++;
        await pinService.clearPin();
      },
    );

    expect(find.textContaining('PIN data is damaged'), findsOneWidget);
    await tester.tap(find.text('Remove damaged PIN'));
    await pumpUntilFound(
      tester,
      find.text('open'),
      whileAlsoGone: find.text('Enter PIN'),
    );

    expect(removeCalls, 1);
    expect(find.text('Enter PIN'), findsNothing);
    expect(await tester.runAsync(pinService.hasPin), isFalse);
  });

  testWidgets(
    'damaged PIN without the removal callback shows no remove button',
    (tester) async {
      await openPrompt(tester);

      expect(find.textContaining('PIN data is damaged'), findsOneWidget);
      expect(find.text('Remove damaged PIN'), findsNothing);
    },
  );
}
