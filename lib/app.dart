import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/routing/app_router.dart';
import 'package:tinda360/theme/app_theme.dart';

/// The root widget. Knows nothing about how its dependencies were built.
class App extends ConsumerWidget {
  /// Creates the app.
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      routerConfig: ref.watch(appRouterProvider),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
