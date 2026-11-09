import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/home/presentation/home_state.dart';
import 'package:tinda360/l10n/app_localizations.dart';

class HomeReadyView extends StatelessWidget {
  const new({required this.state, super.key});

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
          Text(
            l10n.homeProductCount(state.productCount),
            style: text.bodyLarge,
          ),
          Text(
            l10n.homeLowStockCount(state.lowStockCount),
            style: text.bodyLarge,
          ),
        ],
      ),
    );
  }
}
