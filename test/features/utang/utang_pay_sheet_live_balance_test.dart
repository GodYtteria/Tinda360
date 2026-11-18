import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/utang/presentation/utang_balances_provider.dart';
import 'package:tinda360/features/utang/presentation/utang_pay_sheet.dart';
import 'package:tinda360/l10n/app_delegates.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/theme/app_theme.dart';

CustomerBalance _balanceOf(int minorUnits) => CustomerBalance(
  customer: const Customer(id: 'suki-1', name: 'Mang Ben'),
  balance: Money(minorUnits, Currency.php),
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required CustomerBalance openedWith,
  required Stream<List<CustomerBalance>> liveBalances,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        utangBalancesProvider.overrideWith((ref) => liveBalances),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: UtangPaySheet.pay(balance: openedWith)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('pay sheet shows the live balance, not the one it opened with', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      openedWith: _balanceOf(10200),
      liveBalances: Stream.value([_balanceOf(11220)]),
    );

    expect(find.textContaining('112.20'), findsWidgets);
    expect(find.textContaining('102.00'), findsNothing);
  });

  testWidgets('pay sheet follows later changes of the balance', (tester) async {
    final controller = StreamController<List<CustomerBalance>>();
    addTearDown(controller.close);
    controller.add([_balanceOf(10200)]);
    await _pumpSheet(
      tester,
      openedWith: _balanceOf(10200),
      liveBalances: controller.stream,
    );
    expect(find.textContaining('102.00'), findsWidgets);

    controller.add([_balanceOf(11220)]);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('112.20'), findsWidgets);
  });

  testWidgets('pay sheet falls back to the opened balance while loading', (
    tester,
  ) async {
    final controller = StreamController<List<CustomerBalance>>();
    addTearDown(controller.close);
    await _pumpSheet(
      tester,
      openedWith: _balanceOf(10200),
      liveBalances: controller.stream,
    );

    expect(find.textContaining('102.00'), findsWidgets);
  });
}
