import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/app.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/features/onboarding/presentation/splash_screen.dart';
import 'package:tinda360/features/pos/data/cart_storage.dart';
import 'package:tinda360/features/settings/presentation/settings_screen.dart';
import 'package:tinda360/features/shell/main_shell.dart';
import 'package:tinda360/routing/app_router.dart';
import 'package:tinda360/services/service_providers.dart';

import '../support/recording_app_log.dart';

Future<void> _advance(WidgetTester tester) async {
  for (var step = 0; step < 25; step++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

const int _maxPollSteps = 200;

Future<void> _advanceUntil(WidgetTester tester, bool Function() done) async {
  for (var step = 0; step < _maxPollSteps && !done(); step++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Settings closes when the database is replaced', (tester) async {
    final appLog = RecordingAppLog();
    final container = ProviderContainer(
      overrides: [
        appLogProvider.overrideWithValue(appLog),
        cartDirectoryProvider.overrideWithValue(
          () async => throw const FileSystemException('no cart files here'),
        ),
        appDatabaseFactoryProvider.overrideWithValue(
          () => AppDatabase(NativeDatabase.memory()),
        ),
        databaseFileProvider.overrideWithValue(
          () async => File('/tmp/tinda360_router_test.sqlite'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    container.read(appRouterProvider).go(AppRoutes.main);
    await _advanceUntil(
      tester,
      () => find.byType(SplashScreen).evaluate().isEmpty,
    );
    expect(find.byType(MainShell), findsOneWidget);

    unawaited(container.read(appRouterProvider).push(AppRoutes.settings));
    await _advance(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    container.invalidate(appDatabaseProvider);
    await _advance(tester);

    expect(find.byType(SettingsScreen), findsNothing);
  });
}
