import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/chat/presentation/chat_sheet.dart';
import 'package:tinda360/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tinda360/features/settings/presentation/settings_screen.dart';
import 'package:tinda360/features/shell/main_shell.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/theme/app_theme.dart';

import '../support/test_repositories.dart';

final class _FakeDriveBackupService implements DriveBackupService {
  @override
  Future<BackupAuthResult> signIn() async =>
      const BackupAuthSuccess(email: 'tindahan@gmail.com');

  @override
  Future<String?> restoreSession() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<BackupSyncResult> uploadDatabase(
    File databaseFile, {
    required String storeId,
    bool allowPrompt = false,
  }) async =>
      const BackupSyncSuccess();

  @override
  Future<BackupSyncResult> downloadDatabaseTo(
    File destinationFile, {
    required String storeId,
    bool allowPrompt = false,
  }) async =>
      const BackupSyncSuccess();
}

Widget _wrapApp(
  TestRepositories repos,
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1.0,
}) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(repos.db),
    clockProvider.overrideWithValue(repos.clock),
    appLogProvider.overrideWithValue(repos.log),
    driveBackupServiceProvider.overrideWithValue(_FakeDriveBackupService()),
    databaseFileProvider.overrideWithValue(
      () async => File('/tmp/tinda360_test_backup.sqlite'),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: themeMode,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, innerChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: innerChild!,
    ),
    home: child,
  ),
);

void main() {
  testWidgets('OnboardingScreen renders 2 steps and completes onboarding', (
    tester,
  ) async {
    final repos = TestRepositories();
    var completed = false;
    await tester.pumpWidget(
      _wrapApp(
        repos,
        OnboardingScreen(onCompleted: () => completed = true),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Tindahan ni Nena');
    await tester.tap(find.text('Next'));
    await tester.pump();

    await tester.tap(find.text('I am a new store').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(completed, isTrue);
    final profile = await tester.runAsync(() => repos.store.watch().first);
    expect(profile?.onboardingDone, isTrue);
    expect(profile?.name, 'Tindahan ni Nena');
  });

  testWidgets('MainShell renders all 4 tabs in dark mode and large text', (
    tester,
  ) async {
    final repos = TestRepositories();
    await tester.pumpWidget(
      _wrapApp(
        repos,
        MainShell(onOpenSettings: () {}),
        themeMode: ThemeMode.dark,
        textScale: 1.6,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Utang'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);

    await tester.tap(find.text('Inventory'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Utang'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Reports'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('ChatSheet renders cleanly', (tester) async {
    final repos = TestRepositories();
    await tester.pumpWidget(
      _wrapApp(repos, const Scaffold(body: ChatSheet())),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Smart Store Assistant'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('SettingsScreen renders cleanly', (tester) async {
    final repos = TestRepositories();
    await tester.pumpWidget(
      _wrapApp(repos, const SettingsScreen()),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('SettingsScreen switches locale between PH and English', (
    tester,
  ) async {
    final repos = TestRepositories();
    await tester.pumpWidget(
      _wrapApp(repos, const SettingsScreen()),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Filipino'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('SettingsScreen backup state machine transitions off -> choose -> on -> off', (
    tester,
  ) async {
    final repos = TestRepositories();
    await tester.pumpWidget(
      _wrapApp(repos, const SettingsScreen()),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Continue with Google'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('tindahan@gmail.com'), findsOneWidget);
    expect(find.text('Use data on this phone'), findsOneWidget);
    expect(find.text('Restore backup'), findsOneWidget);

    await tester.tap(find.text('Use data on this phone'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Last backup: Just now'), findsOneWidget);
    expect(find.text('Disconnect Google'), findsOneWidget);

    await tester.tap(find.text('Disconnect Google'));
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('SettingsScreen add store dialog does not throw on submit', (
    tester,
  ) async {
    final repos = TestRepositories();
    await tester.pumpWidget(
      _wrapApp(repos, const SettingsScreen()),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ New store'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Branch 2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('SettingsScreen shows storage card and no-backup warning', (
    tester,
  ) async {
    final repos = TestRepositories();
    await tester.pumpWidget(
      _wrapApp(repos, const SettingsScreen()),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('STORAGE & DATA'), findsOneWidget);
    expect(find.text('No Google Drive backup yet'), findsOneWidget);
    expect(find.text('Compact storage'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));
  });
}
