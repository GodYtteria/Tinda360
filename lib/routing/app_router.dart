import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tinda360/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tinda360/features/onboarding/presentation/splash_screen.dart';
import 'package:tinda360/features/settings/presentation/settings_screen.dart';
import 'package:tinda360/features/shell/main_shell.dart';

/// Route paths for the Tinda 360 app.
abstract final class AppRoutes {
  /// Launch splash route.
  static const String splash = '/';

  /// First-run store onboarding route.
  static const String onboarding = '/onboarding';

  /// Main 4-tab POS shell.
  static const String main = '/app';

  /// Store and AI settings route.
  static const String settings = '/settings';
}

/// The app's single router. Each feature registers its route here.
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
  ref.onDispose(router.dispose);
  return router;
});
