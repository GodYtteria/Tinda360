import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/stock_history_entry.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

final StreamProviderFamily<List<StockHistoryEntry>, String>
stockHistoryProvider = StreamProvider.autoDispose
    .family<List<StockHistoryEntry>, String>(
      (ref, productId) =>
          ref.watch(productRepositoryProvider).watchStockHistory(productId),
    );

String localizedStockReason(AppLocalizations localizations, String reason) =>
    switch (reason) {
      'initial' => localizations.stockReasonInitial,
      'restock' => localizations.stockReasonRestock,
      'sale' => localizations.stockReasonSale,
      'return' => localizations.stockReasonReturn,
      _ => localizations.stockReasonAdjust,
    };

String formatSignedQuantity(StockHistoryEntry entry, Product product) {
  final sign = entry.change.isPositive ? '+' : '';
  return '$sign${formatQuantity(entry.change, product.unit)}';
}

class StockHistorySheet extends ConsumerWidget {
  const new({required this.product, super.key});

  final Product product;

  static Future<void> show(BuildContext context, Product product) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: AppPalette.of(context).scrim,
        builder: (_) => StockHistorySheet(product: product),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final historyAsync = ref.watch(stockHistoryProvider(product.id));
    final Widget content;
    if (historyAsync.isLoading && !historyAsync.hasValue) {
      content = Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: AppSpacing.s24,
        ),
        child: Center(child: CircularProgressIndicator(color: palette.primary)),
      );
    } else if (historyAsync.hasError && !historyAsync.hasValue) {
      content = Text(
        localizations.homeLoadFailed,
        style: AppTypography.body(palette.danger),
      );
    } else {
      final entries = historyAsync.value ?? const <StockHistoryEntry>[];
      content = entries.isEmpty
          ? Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.s20,
              ),
              child: Center(
                child: Text(
                  localizations.stockHistoryEmpty,
                  style: AppTypography.meta(palette.textMuted),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
              itemBuilder: (context, index) =>
                  _StockHistoryRow(entry: entries[index], product: product),
            );
    }
    return TindaBottomSheet(
      title: '${localizations.stockHistoryTitle} · ${product.name}',
      closeTooltip: localizations.commonClose,
      child: content,
    );
  }
}

class _StockHistoryRow extends StatelessWidget {
  const new({required this.entry, required this.product});

  final StockHistoryEntry entry;

  final Product product;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      entry.createdAtMs,
    ).toLocal();
    final formattedTimestamp = DateFormat('MMM d, y · h:mm a')
        .format(timestamp);
    final changeColor = entry.change.isPositive
        ? palette.success
        : palette.danger;
    return TindaCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizedStockReason(localizations, entry.reason),
                  style: AppTypography.bodyStrong(palette.text),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  formattedTimestamp,
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${formatSignedQuantity(entry, product)} '
                  '${localizedUnit(localizations, product.unit)}',
                  style: AppTypography.bodyStrong(
                    changeColor,
                    size: 16,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  localizations.stockHistoryAfter(
                    formatQuantity(entry.stockAfter, product.unit),
                  ),
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
