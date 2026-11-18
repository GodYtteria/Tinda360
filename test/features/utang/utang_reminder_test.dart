import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/utang/presentation/suki_ledger_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/l10n/app_localizations_en.dart';
import 'package:tinda360/l10n/app_localizations_fil.dart';

void main() {
  test('reminder includes customer, store name and balance', () {
    final AppLocalizations localizations = AppLocalizationsEn();
    final message = buildUtangReminderMessage(
      localizations: localizations,
      customerName: 'Aling Rosa',
      storeName: ' Tindahan ni Mang Juan ',
      formattedBalance: '₱125.50',
    );
    expect(message, contains('Aling Rosa'));
    expect(message, contains('Tindahan ni Mang Juan'));
    expect(message, contains('₱125.50'));
  });

  test('reminder falls back to default store name when blank', () {
    final localizations = AppLocalizationsEn();
    final message = buildUtangReminderMessage(
      localizations: localizations,
      customerName: 'Rosa',
      storeName: '   ',
      formattedBalance: '₱10.00',
    );
    expect(message, contains(localizations.ledgerReminderDefaultStore));
    expect(message, contains('₱10.00'));
  });

  test('Filipino reminder is localized and includes balance', () {
    final localizations = AppLocalizationsFil();
    final message = buildUtangReminderMessage(
      localizations: localizations,
      customerName: 'Rosa',
      storeName: 'Tindahan',
      formattedBalance: '₱10.00',
    );
    expect(message, startsWith('Magandang araw, Rosa'));
    expect(message, contains('Tindahan'));
    expect(message, contains('₱10.00'));
    expect(message, isNot(contains('Friendly reminder')));
  });

  test('reminder shows utang plus interest breakdown when interest exists', () {
    final message = buildUtangReminderMessage(
      localizations: AppLocalizationsEn(),
      customerName: 'Rosa',
      storeName: 'Tindahan',
      formattedBalance: '₱105.00',
      formattedUtang: '₱100.00',
      formattedInterest: '₱5.00',
    );
    expect(message, contains('Utang ₱100.00 + interest ₱5.00 = ₱105.00'));
  });

  test('Filipino reminder shows interes breakdown', () {
    final message = buildUtangReminderMessage(
      localizations: AppLocalizationsFil(),
      customerName: 'Rosa',
      storeName: 'Tindahan',
      formattedBalance: '₱105.00',
      formattedUtang: '₱100.00',
      formattedInterest: '₱5.00',
    );
    expect(message, contains('Utang ₱100.00 + interes ₱5.00 = ₱105.00'));
    expect(message, startsWith('Magandang araw, Rosa'));
  });

  test('reminder without interest keeps the plain balance text', () {
    final message = buildUtangReminderMessage(
      localizations: AppLocalizationsEn(),
      customerName: 'Rosa',
      storeName: 'Tindahan',
      formattedBalance: '₱100.00',
    );
    expect(message, isNot(contains('interest')));
  });

  test('locale classes exist for supported locales', () {
    expect(
      AppLocalizations.supportedLocales,
      contains(const Locale('fil')),
    );
  });
}
