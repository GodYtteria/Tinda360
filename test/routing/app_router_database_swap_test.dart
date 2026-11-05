import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/routing/app_router.dart';

void main() {
  test(
    'replacing the database sends the app back to the splash route',
    () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseFactoryProvider.overrideWithValue(
            () => AppDatabase(NativeDatabase.memory()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider)..go(AppRoutes.settings);
      await Future<void>.delayed(Duration.zero);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.settings,
      );

      container.invalidate(appDatabaseProvider);
      container.read(appDatabaseProvider);
      await Future<void>.delayed(Duration.zero);

      expect(router.routeInformationProvider.value.uri.path, AppRoutes.splash);
    },
  );

  test('the first database open does not navigate', () async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(
          () => AppDatabase(NativeDatabase.memory()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider)..go(AppRoutes.settings);
    container.read(appDatabaseProvider);
    await Future<void>.delayed(Duration.zero);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.settings);
  });
}
