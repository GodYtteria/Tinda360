import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/chat/presentation/intent_matcher.dart';
import 'package:tinda360/features/chat/presentation/yumi_screen.dart';
import 'package:tinda360/features/shell/main_shell.dart';
import 'package:tinda360/l10n/app_delegates.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/l10n/app_localizations_en.dart';
import 'package:tinda360/l10n/app_localizations_fil.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/theme/app_theme.dart';

import '../../support/test_repositories.dart';

const Map<YumiScreen, List<String>> _expectedEnglishChips = {
  YumiScreen.pos: ['What is low on stock?', 'How are sales today?'],
  YumiScreen.inventory: [
    'How many products do I have?',
    'What is low on stock?',
    'Slow-moving products?',
  ],
  YumiScreen.utang: ['Who has utang?', 'Utang risk?'],
  YumiScreen.reports: [
    'How are sales today?',
    'Expenses this week?',
    'Compare with yesterday',
  ],
  YumiScreen.settings: ['What can you do?'],
};

const Map<YumiScreen, List<String>> _expectedFilipinoChips = {
  YumiScreen.pos: ['Ano ang mababa sa stock?', 'Magkano ang benta ngayon?'],
  YumiScreen.inventory: [
    'Ilan ang produkto ko?',
    'Ano ang mababa sa stock?',
    'Ano ang matumal?',
  ],
  YumiScreen.utang: ['Sino ang may utang?', 'Delikado ba ang utang?'],
  YumiScreen.reports: [
    'Magkano ang benta ngayon?',
    'Magkano ang gastos ngayong linggo?',
    'Kumpara sa kahapon',
  ],
  YumiScreen.settings: ['What can you do?'],
};

const Map<String, ChatIntent> _expectedIntentByEnglishChip = {
  'What is low on stock?': ChatIntent.lowStock,
  'How are sales today?': ChatIntent.sales,
  'How many products do I have?': ChatIntent.productCount,
  'Slow-moving products?': ChatIntent.slowMoving,
  'Who has utang?': ChatIntent.utang,
  'Utang risk?': ChatIntent.utangRisk,
  'Expenses this week?': ChatIntent.expenses,
  'Compare with yesterday': ChatIntent.salesCompare,
  'What can you do?': ChatIntent.help,
};

const Map<String, ChatIntent> _expectedIntentByFilipinoChip = {
  'Ano ang mababa sa stock?': ChatIntent.lowStock,
  'Magkano ang benta ngayon?': ChatIntent.sales,
  'Ilan ang produkto ko?': ChatIntent.productCount,
  'Ano ang matumal?': ChatIntent.slowMoving,
  'Sino ang may utang?': ChatIntent.utang,
  'Delikado ba ang utang?': ChatIntent.utangRisk,
  'Magkano ang gastos ngayong linggo?': ChatIntent.expenses,
  'Kumpara sa kahapon': ChatIntent.salesCompare,
  'What can you do?': ChatIntent.help,
};

void main() {
  final matcher = IntentMatcher.fromJsonString(
    File('assets/ai/intents.json').readAsStringSync(),
  );
  final englishLocalizations = AppLocalizationsEn();
  final filipinoLocalizations = AppLocalizationsFil();

  test('english chips per screen are the expected ones', () {
    for (final screen in YumiScreen.values) {
      expect(
        yumiSuggestionsFor(screen, englishLocalizations),
        _expectedEnglishChips[screen],
        reason: screen.name,
      );
    }
  });

  test('filipino chips per screen are the expected ones', () {
    for (final screen in YumiScreen.values) {
      expect(
        yumiSuggestionsFor(screen, filipinoLocalizations),
        _expectedFilipinoChips[screen],
        reason: screen.name,
      );
    }
  });

  test('every chip maps to its intended intent, never overview', () {
    for (final entry in _expectedIntentByEnglishChip.entries) {
      final intent = matcher.match(entry.key).intent;
      expect(intent, isNot(ChatIntent.overview), reason: entry.key);
      expect(intent, entry.value, reason: entry.key);
    }
    for (final entry in _expectedIntentByFilipinoChip.entries) {
      final intent = matcher.match(entry.key).intent;
      expect(intent, isNot(ChatIntent.overview), reason: entry.key);
      expect(intent, entry.value, reason: entry.key);
    }
  });

  test('every screen has a hint that names the screen in both languages', () {
    for (final screen in YumiScreen.values) {
      expect(yumiHintFor(screen, englishLocalizations), isNotEmpty);
      expect(yumiHintFor(screen, filipinoLocalizations), isNotEmpty);
    }
    expect(
      yumiHintFor(YumiScreen.utang, englishLocalizations),
      "You're on Utang. Ask me who owes and how much.",
    );
  });

  test('tab index maps to the matching screen', () {
    expect(yumiScreenForTab(0), YumiScreen.pos);
    expect(yumiScreenForTab(1), YumiScreen.inventory);
    expect(yumiScreenForTab(2), YumiScreen.utang);
    expect(yumiScreenForTab(3), YumiScreen.reports);
  });

  test('provider defaults to pos and accepts a new screen', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(yumiScreenProvider), YumiScreen.pos);
    container.read(yumiScreenProvider.notifier).setScreen(YumiScreen.utang);
    expect(container.read(yumiScreenProvider), YumiScreen.utang);
  });

  testWidgets('MainShell publishes the screen when the tab changes', (
    tester,
  ) async {
    final repos = TestRepositories();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(repos.db),
          clockProvider.overrideWithValue(repos.clock),
          appLogProvider.overrideWithValue(repos.log),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MainShell(onOpenSettings: () {}, initialIndex: 2),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShell)),
    );
    expect(container.read(yumiScreenProvider), YumiScreen.utang);

    await tester.tap(find.text('Reports'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(yumiScreenProvider), YumiScreen.reports);

    await tester.tap(find.text('Inventory'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(yumiScreenProvider), YumiScreen.inventory);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
