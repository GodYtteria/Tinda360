import 'package:flutter/material.dart';
import 'package:tinda360/l10n/app_localizations.dart';

/// Shown when the store data cannot be loaded.
class HomeErrorView extends StatelessWidget {
  /// Creates the view; [onRetry] reloads.
  const HomeErrorView({required this.onRetry, super.key});

  /// Called when the owner taps retry.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(l10n.homeLoadFailed, textAlign: TextAlign.center),
            FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
