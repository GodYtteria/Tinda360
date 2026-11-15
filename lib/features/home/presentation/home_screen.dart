import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/features/home/presentation/home_notifier.dart';
import 'package:tinda360/features/home/presentation/widgets/home_error_view.dart';
import 'package:tinda360/features/home/presentation/widgets/home_ready_view.dart';
import 'package:tinda360/l10n/app_localizations.dart';

/// Temporary first screen that proves the database is live. It is replaced
/// by the Benta screen in step 2.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ref
          .watch(homeNotifierProvider)
          .when(
            data: (state) => HomeReadyView(state: state),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => HomeErrorView(
              onRetry: () => ref.invalidate(homeNotifierProvider),
            ),
          ),
    );
  }
}
