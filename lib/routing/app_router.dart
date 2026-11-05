import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tinda360/features/onboarding/presentation/splash_screen.dart';
import 'package:tinda360/features/settings/presentation/settings_screen.dart';
import 'package:tinda360/features/shell/main_shell.dart';

abstract final class AppRoutes {
  static const String splash = '/';

  static const String onboarding = '/onboarding';

  static const String main = '/app';

  static const String settings = '/settings';
}

Future<void> leaveScreensReadingDatabase(GoRouter router) async {
  router.go(AppRoutes.splash);
  await WidgetsBinding.instance.endOfFrame;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashScreen(
          onDone: (onboardingDone) {
            context.go(
              onboardingDone ? AppRoutes.main : AppRoutes.onboarding,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onCompleted: () => context.go(AppRoutes.main),
        ),
      ),
      GoRoute(
        path: AppRoutes.main,
        builder: (context, state) => MainShell(
          onOpenSettings: () => context.push(AppRoutes.settings),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref
    ..listen<AppDatabase>(appDatabaseProvider, (previous, next) {
      if (previous != null && !identical(previous, next)) {
        router.go(AppRoutes.splash);
      }
    })
    ..onDispose(router.dispose);
  return router;
});
