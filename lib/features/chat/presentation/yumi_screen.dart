import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/l10n/app_localizations.dart';

enum YumiScreen { pos, inventory, utang, reports, settings }

class YumiScreenNotifier extends Notifier<YumiScreen> {
  @override
  YumiScreen build() => YumiScreen.pos;

  void setScreen(YumiScreen screen) => state = screen;
}

final yumiScreenProvider = NotifierProvider<YumiScreenNotifier, YumiScreen>(
  YumiScreenNotifier.new,
);

YumiScreen yumiScreenForTab(int tabIndex) => switch (tabIndex) {
  1 => YumiScreen.inventory,
  2 => YumiScreen.utang,
  3 => YumiScreen.reports,
  _ => YumiScreen.pos,
};

List<String> yumiSuggestionsFor(
  YumiScreen screen,
  AppLocalizations localizations,
) => switch (screen) {
  YumiScreen.pos => [
    localizations.yumiChipLowStock,
    localizations.yumiChipSalesToday,
  ],
  YumiScreen.inventory => [
    localizations.yumiChipProductCount,
    localizations.yumiChipLowStock,
    localizations.yumiChipSlowMoving,
  ],
  YumiScreen.utang => [
    localizations.yumiChipWhoHasUtang,
    localizations.yumiChipUtangRisk,
  ],
  YumiScreen.reports => [
    localizations.yumiChipSalesToday,
    localizations.yumiChipExpensesWeek,
    localizations.yumiChipCompareYesterday,
  ],
  YumiScreen.settings => [localizations.yumiChipWhatCanYouDo],
};

String yumiHintFor(YumiScreen screen, AppLocalizations localizations) =>
    switch (screen) {
      YumiScreen.pos => localizations.yumiHintPos,
      YumiScreen.inventory => localizations.yumiHintInventory,
      YumiScreen.utang => localizations.yumiHintUtang,
      YumiScreen.reports => localizations.yumiHintReports,
      YumiScreen.settings => localizations.yumiHintSettings,
    };
