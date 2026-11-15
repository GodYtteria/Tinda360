import 'package:flutter/material.dart';
import 'package:tinda360/features/home/presentation/home_state.dart';
import 'package:tinda360/l10n/app_localizations.dart';

/// Shows the live product and low-stock counts.
class HomeReadyView extends StatelessWidget {
  /// Creates the view for [state].
  const HomeReadyView({required this.state, super.key});

  /// What to show.
  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(l10n.homeDatabaseReady, style: text.titleLarge),
          Text(l10n.homeProductCount(state.productCount), style: text.bodyLarge),
          Text(
            l10n.homeLowStockCount(state.lowStockCount),
            style: text.bodyLarge,
          ),
        ],
      ),
    );
  }
}
