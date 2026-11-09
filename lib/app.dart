import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/l10n/app_delegates.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/routing/app_router.dart';
import 'package:tinda360/theme/adaptive_layout.dart';
import 'package:tinda360/theme/app_theme.dart';

class App extends ConsumerWidget {
  const new({super.key});

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
      builder: (context, routedChild) =>
          AdaptiveTextScale(child: routedChild ?? const SizedBox.shrink()),
      routerConfig: ref.watch(appRouterProvider),
      locale: ref.watch(localeProvider),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
