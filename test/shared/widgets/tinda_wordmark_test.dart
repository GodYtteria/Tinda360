import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/l10n/app_delegates.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_logo.dart';
import 'package:tinda360/theme/app_theme.dart';

Widget _wordmarkApp(String localeCode, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light(),
  locale: Locale(localeCode),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: const Scaffold(body: TindaWordmark()),
    ),
  ),
);

void main() {
  testWidgets('the wordmark reads Shop 360 in English', (tester) async {
    await tester.pumpWidget(_wordmarkApp('en'));
    await tester.pumpAndSettle();
    expect(find.text('Shop 360', findRichText: true), findsOneWidget);
    expect(find.text('Tinda 360', findRichText: true), findsNothing);
  });

  testWidgets('the wordmark reads Tinda 360 in Filipino', (tester) async {
    await tester.pumpWidget(_wordmarkApp('fil'));
    await tester.pumpAndSettle();
    expect(find.text('Tinda 360', findRichText: true), findsOneWidget);
    expect(find.text('Shop 360', findRichText: true), findsNothing);
  });

  testWidgets('the wordmark keeps its size at a large system font', (
    tester,
  ) async {
    await tester.pumpWidget(_wordmarkApp('en', textScale: 2));
    await tester.pumpAndSettle();
    final normalHeight = tester.getSize(find.byType(TindaWordmark)).height;
    await tester.pumpWidget(_wordmarkApp('en'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TindaWordmark)).height, normalHeight);
  });
}
