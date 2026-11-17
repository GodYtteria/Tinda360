import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:tinda360/core/achievements/store_milestone.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/failures/expense_failure.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/features/inventory/presentation/inventory_screen.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/inventory/data/product_csv_exporter.dart';
import 'package:tinda360/shared/widgets/csv_preview_sheet.dart';
import 'package:tinda360/features/chat/presentation/chat_sheet.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/features/ulat/presentation/ulat_notifier.dart';
import 'package:tinda360/features/pos/presentation/receipt_preview_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/report_pdf_service.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';


final _ulatStoreProfileProvider = StreamProvider.autoDispose<StoreProfile>(
  (ref) => ref.watch(storeProfileRepositoryProvider).watch(),
);
/// Reports (Ulat) tab showing sales, profit, transactions, utang, and trend.
class UlatScreen extends ConsumerWidget {
  /// Creates the reports screen.
  const UlatScreen({
    required this.onOpenSettings,
    required this.onOpenAiChat,
    super.key,
    this.onOpenTab,
  });

  /// Callback to open settings.
  final VoidCallback onOpenSettings;

  /// Callback to open Tinda AI chat.
  final VoidCallback onOpenAiChat;

  /// Switches the shell tab (0=POS,1=Inventory,2=Utang,3=Reports).
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final palette = AppPalette.of(context);
    final selectedPeriod = ref.watch(ulatPeriodProvider);
    final reportAsync = ref.watch(ulatNotifierProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          TindaHeaderBar(
            title: Text(localizations.reportsTitle),
            actions: [
              TindaIconButton(
                svgAsset: 'assets/icons/settings.svg',
                tooltip: localizations.posOpenSettings,
                onPressed: onOpenSettings,
                onHeader: true,
              ),
            ],
            bottom: TindaSegmentedControl<ReportPeriod>(
              segments: {
                ReportPeriod.today: localizations.reportsToday,
                ReportPeriod.week: localizations.reportsWeek,
                ReportPeriod.month: localizations.reportsMonth,
              },
              selected: selectedPeriod,
              onChanged: (period) =>
                  ref.read(ulatPeriodProvider.notifier).select(period),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
              ),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: reportAsync.when(
                loading: () => Center(
                  key: const ValueKey('ulat-loading'),
                  child: CircularProgressIndicator(color: palette.primary),
                ),
                error: (_, _) => TindaEmptyState(
                  key: const ValueKey('ulat-error'),
                  icon: Icons.error_outline_rounded,
                  title: localizations.homeLoadFailed,
                  body: localizations.reportsEmptyBody,
                  action: TindaSecondaryButton(
                    label: localizations.commonRetry,
                    onPressed: () => ref.invalidate(ulatNotifierProvider),
                  ),
                ),
                data: (state) => Center(
                  key: ValueKey('ulat-${state.period.name}-${state.summary.revenue.minorUnits}-${state.summary.saleCount}'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _ReportContent(
                      state: state,
                      onOpenAiChat: onOpenAiChat,
                      onOpenTab: onOpenTab,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends ConsumerStatefulWidget {
  const _ReportContent({
    required this.state,
    required this.onOpenAiChat,
    this.onOpenTab,
  });

  final UlatState state;
  final VoidCallback onOpenAiChat;
  final ValueChanged<int>? onOpenTab;

  @override
  ConsumerState<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends ConsumerState<_ReportContent> {
  bool _isExporting = false;

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    final localizations = AppLocalizations.of(context);
    setState(() => _isExporting = true);
    try {
      final profile = await ref
          .read(storeProfileRepositoryProvider)
          .watch()
          .first;
      final bytes = await ReportPdfService.buildReportPdf(
        storeName: profile.name,
        periodLabel: _periodLabel(localizations, widget.state.period),
        state: widget.state,
        localizations: localizations,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'tinda360_report_${widget.state.period.name}.pdf',
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.reportsExportPdfError)),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportSalesCsv() async {
    final localizations = AppLocalizations.of(context);
    try {
      final sales = await ref
          .read(saleRepositoryProvider)
          .watchRecentSales(widget.state.range)
          .first;
      final csvContent = exportSalesCsv(sales);
      final parsed = parseCsvForPreview(csvContent);
      if (!mounted) return;
      await CsvPreviewSheet.show(
        context,
        title: localizations.reportsExportCsv,
        headers: parsed.headers,
        rows: parsed.rows,
        fileName: 'tinda360_sales_${widget.state.period.name}.csv',
        csvContent: csvContent,
        successMessage: localizations.reportsExportCsvSuccess,
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.reportsExportPdfError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final summary = widget.state.summary;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screenHorizontal,
        AppSpacing.s16,
        AppSpacing.screenHorizontal,
        AppSpacing.s24,
      ),
      children: [
        _StatsGrid(state: widget.state),
        const SizedBox(height: AppSpacing.s16),
        _SalesTrendCard(
          period: widget.state.period,
          summary: summary,
          totalUtang: widget.state.totalUtang,
        ),
        const SizedBox(height: AppSpacing.s16),
        _TopProductsCard(
          period: widget.state.period,
          topProducts: widget.state.topProducts,
        ),
        const SizedBox(height: AppSpacing.s12),
        TindaSecondaryButton(
          label: localizations.reportsExportPdf,
          icon: Icons.picture_as_pdf_outlined,
          onPressed: _isExporting ? null : _exportPdf,
        ),
        const SizedBox(height: AppSpacing.s10),
        TindaSecondaryButton(
          label: localizations.reportsExportCsv,
          icon: Icons.table_view_outlined,
          onPressed: () => unawaited(_exportSalesCsv()),
        ),
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
          width: double.infinity,
          height: AppSizes.secondaryButtonHeight,
          child: FilledButton.icon(
            onPressed: () {
              final periodLabel = switch (widget.state.period) {
                ReportPeriod.today => localizations.reportsToday,
                ReportPeriod.week => localizations.reportsWeek,
                ReportPeriod.month => localizations.reportsMonth,
              };
              unawaited(
                ChatSheet.show(
                  context,
                  contextHint: '${localizations.reportsAskAi} ($periodLabel)',
                  extraSuggestions: [
                    '${localizations.chatSuggestionSales} ($periodLabel)',
                    localizations.chatSuggestionLowStock,
                    localizations.chatSuggestionUtang,
                  ],
                  onOpenTab: widget.onOpenTab,
                ),
              );
            },
            icon: SvgPicture.asset(
              'assets/icons/ai_sparkle.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                AppPalette.of(context).onAccentSoft,
                BlendMode.srcIn,
              ),
            ),
            label: Text(localizations.reportsAskAi),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.of(context).accentSoft,
              foregroundColor: AppPalette.of(context).onAccentSoft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.mainButton),
              ),
              textStyle: AppTypography.bodyStrong(
                AppPalette.of(context).onAccentSoft,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        _ExpensesSection(grossProfit: widget.state.summary.profit),
        const SizedBox(height: AppSpacing.s16),
        _MilestonesSection(
          saleCount: widget.state.summary.saleCount,
          totalRevenueMinor: widget.state.summary.revenue.minorUnits,
        ),
        const SizedBox(height: AppSpacing.s16),
        const _RecentSalesSection(),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.state});

  final UlatState state;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final summary = state.summary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatCard(
                label: localizations.reportsSalesCard,
                value: formatMoney(summary.revenue),
                valueColor: palette.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _StatCard(
                label: localizations.reportsProfitCard,
                value: formatMoney(summary.profit),
                valueColor: palette.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatCard(
                label: localizations.reportsTransactionsCard,
                value: '${summary.saleCount}',
                valueColor: palette.text,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _StatCard(
                label: localizations.reportsNewUtangCard,
                value: formatMoney(state.totalUtang),
                valueColor: state.totalUtang.isPositive
                    ? palette.danger
                    : palette.text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return TindaCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.meta(palette.textMuted, size: 13),
          ),
          const SizedBox(height: AppSpacing.s8),
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: AppTypography.title(valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

String _periodLabel(AppLocalizations localizations, ReportPeriod period) =>
    switch (period) {
      ReportPeriod.today => localizations.reportsToday,
      ReportPeriod.week => localizations.reportsWeek,
      ReportPeriod.month => localizations.reportsMonth,
    };

class _SalesTrendCard extends StatelessWidget {
  const _SalesTrendCard({
    required this.period,
    required this.summary,
    required this.totalUtang,
  });

  final ReportPeriod period;
  final SalesSummary summary;
  final Money totalUtang;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final hasActivity = summary.saleCount > 0 || totalUtang.isPositive;
    final periodLabel = _periodLabel(localizations, period);
    final chartTitle = localizations.reportsChartTitlePeriod(periodLabel);
    final emptyTitle = localizations.reportsEmptyTitlePeriod(periodLabel);

    return TindaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chartTitle,
            style: AppTypography.bodyStrong(
              palette.text,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (!hasActivity)
            TindaEmptyState(
              icon: Icons.bar_chart_rounded,
              title: emptyTitle,
              body: localizations.reportsEmptyBody,
            )
          else ...[
            Semantics(
              label:
                  '$chartTitle: '
                  '${localizations.reportsSalesCard} '
                  '${formatMoney(summary.revenue)}, '
                  '${localizations.reportsProfitCard} '
                  '${formatMoney(summary.profit)}',
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(
                    '${summary.revenue.minorUnits}-${summary.profit.minorUnits}-${totalUtang.minorUnits}',
                  ),
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(
                    milliseconds:
                        MediaQuery.disableAnimationsOf(context) ? 0 : 450,
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => CustomPaint(
                    painter: _SalesTrendPainter(
                      revenueMinor: summary.revenue.minorUnits,
                      profitMinor: math.max(0, summary.profit.minorUnits),
                      utangMinor: totalUtang.minorUnits,
                      primaryColor: palette.primary,
                      successColor: palette.success,
                      dangerColor: palette.danger,
                      trackColor: palette.surfaceMuted,
                      progress: progress,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s16,
              runSpacing: AppSpacing.s8,
              children: [
                _ChartLegendItem(
                  color: palette.primary,
                  label: localizations.reportsSalesCard,
                ),
                _ChartLegendItem(
                  color: palette.success,
                  label: localizations.reportsProfitCard,
                ),
                _ChartLegendItem(
                  color: palette.danger,
                  label: localizations.reportsNewUtangCard,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text(label, style: AppTypography.meta(palette.textMuted)),
      ],
    );
  }
}

class _SalesTrendPainter extends CustomPainter {
  const _SalesTrendPainter({
    required this.revenueMinor,
    required this.profitMinor,
    required this.utangMinor,
    required this.primaryColor,
    required this.successColor,
    required this.dangerColor,
    required this.trackColor,
    this.progress = 1,
  });

  final int revenueMinor;
  final int profitMinor;
  final int utangMinor;
  final Color primaryColor;
  final Color successColor;
  final Color dangerColor;
  final Color trackColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final maxMinor = math.max(
      1,
      math.max(revenueMinor, math.max(profitMinor, utangMinor)),
    );
    final values = [revenueMinor, profitMinor, utangMinor];
    final colors = [primaryColor, successColor, dangerColor];
    final barWidth = math.min(44.0, size.width / 6);
    final slotWidth = size.width / values.length;
    final radius = const Radius.circular(AppRadii.smallButton);

    for (var index = 0; index < values.length; index++) {
      final left = slotWidth * index + (slotWidth - barWidth) / 2;
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, barWidth, size.height),
        radius,
      );
      canvas.drawRRect(trackRect, Paint()..color = trackColor);

      final ratio = (values[index] / maxMinor) * progress;
      final barHeight = math.max(
        values[index] > 0 ? 8.0 * progress : 0.0,
        size.height * ratio,
      );
      if (barHeight > 0) {
        final barRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
          radius,
        );
        canvas.drawRRect(barRect, Paint()..color = colors[index]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SalesTrendPainter oldDelegate) =>
      oldDelegate.revenueMinor != revenueMinor ||
      oldDelegate.profitMinor != profitMinor ||
      oldDelegate.utangMinor != utangMinor ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.successColor != successColor ||
      oldDelegate.dangerColor != dangerColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progress != progress;
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.period, required this.topProducts});

  final ReportPeriod period;
  final List<TopProduct> topProducts;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final periodLabel = _periodLabel(localizations, period);
    return TindaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localizations.reportsTopProductsTitle,
            style: AppTypography.bodyStrong(
              palette.text,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (topProducts.isEmpty)
            TindaEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: localizations.reportsEmptyTitlePeriod(periodLabel),
              body: localizations.reportsEmptyBody,
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < topProducts.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.s12),
                  _TopProductRow(rank: index + 1, item: topProducts[index]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.rank, required this.item});

  final int rank;
  final TopProduct item;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final soldSummary = localizations.reportsTopProductSold(
      formatQuantity(item.totalQuantity, item.unit),
      formatMoney(item.totalRevenue),
    );

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank == 1 ? palette.accentSoft : palette.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$rank',
            style: AppTypography.bodyStrong(
              rank == 1 ? palette.onAccentSoft : palette.textMuted,
              size: 13,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.productName,
                style: AppTypography.bodyStrong(palette.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                soldSummary,
                style: AppTypography.meta(palette.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentSalesSection extends ConsumerWidget {
  const _RecentSalesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final salesAsync = ref.watch(ulatRecentSalesProvider);
    final sales = salesAsync.value ?? const <SaleRecord>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.ulatRecentSales,
          style: AppTypography.meta(
            palette.textMuted,
            size: 13,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        if (sales.isEmpty)
          TindaCard(
            child: Text(
              localizations.ulatNoRecentSales,
              style: AppTypography.body(palette.textMuted),
            ),
          )
        else
          for (final sale in sales) ...[
            TindaCard(
              onTap: () => _showSaleDetailSheet(context, ref, sale),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            TindaBadge(
                              label: _methodLabel(localizations, sale.method),
                              isDanger: sale.method == PaymentMethod.utang,
                            ),
                            if (sale.customerName != null) ...[
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  sale.customerName!,
                                  style: AppTypography.meta(palette.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          '${DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(sale.createdAtMs).toLocal())} · '
                          '${localizations.ulatSaleItemsCount(sale.lines.length)}',
                          style: AppTypography.meta(palette.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    formatMoney(sale.total),
                    style: AppTypography.bodyStrong(palette.text),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
      ],
    );
  }

  String _methodLabel(AppLocalizations localizations, PaymentMethod method) =>
      switch (method) {
        PaymentMethod.cash => localizations.checkoutMethodCash,
        PaymentMethod.ewallet => localizations.checkoutMethodEwallet,
        PaymentMethod.utang => localizations.checkoutMethodUtang,
      };

  void _showSaleDetailSheet(
    BuildContext context,
    WidgetRef ref,
    SaleRecord sale,
  ) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: palette.scrim,
        builder: (sheetContext) => TindaBottomSheet(
          title: localizations.ulatSaleDetailTitle,
          closeTooltip: localizations.commonClose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in sale.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.productName} × '
                          '${formatQuantity(line.quantity, line.unit)} '
                          '${localizedUnit(localizations, line.unit)}',
                          style: AppTypography.body(palette.text),
                        ),
                      ),
                      Text(
                        formatMoney(line.lineTotal),
                        style: AppTypography.bodyStrong(palette.text),
                      ),
                    ],
                  ),
                ),
              Divider(color: palette.border),
              const SizedBox(height: AppSpacing.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.ulatSaleTotalLabel,
                    style: AppTypography.bodyStrong(palette.text),
                  ),
                  Text(
                    formatMoney(sale.total),
                    style: AppTypography.title(palette.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.ulatSalePaidLabel,
                    style: AppTypography.meta(palette.textMuted),
                  ),
                  Text(
                    formatMoney(sale.paid),
                    style: AppTypography.meta(palette.textMuted),
                  ),
                ],
              ),
              if (sale.ewalletReference != null &&
                  sale.ewalletReference!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '${localizations.ulatSaleReferenceLabel}: '
                  '${sale.ewalletReference}',
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              TindaSecondaryButton(
                label: localizations.receiptPrint58mm,
                icon: Icons.print_outlined,
                onPressed: () {
                  final storeName =
                      ref.read(_ulatStoreProfileProvider).asData?.value.name ?? '';
                  unawaited(
                    ReceiptPreviewSheet.show(
                      sheetContext,
                      storeName: storeName.trim().isEmpty
                          ? localizations.appTitle
                          : storeName,
                      lines: [
                        for (final line in sale.lines)
                          '${line.productName} x${formatQuantity(line.quantity, line.unit)} '
                              '${localizedUnit(localizations, line.unit)} = ${formatMoney(line.lineTotal)}',
                      ],
                      total: sale.total,
                      paid: sale.paid,
                      change: sale.paid.minorUnits >= sale.total.minorUnits
                          ? sale.paid - sale.total
                          : Money.zero(sale.total.currency),
                      paymentLabel: _methodLabel(localizations, sale.method),
                      timestamp: DateTime.fromMillisecondsSinceEpoch(
                        sale.createdAtMs,
                      ).toLocal(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s8),
              TindaTextLinkButton(
                label: localizations.ulatVoidSaleButton,
                isDanger: true,
                onPressed: () =>
                    unawaited(_confirmVoidSale(sheetContext, context, ref, sale)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmVoidSale(
    BuildContext sheetContext,
    BuildContext parentContext,
    WidgetRef ref,
    SaleRecord sale,
  ) async {
    final localizations = AppLocalizations.of(parentContext);
    final messenger = ScaffoldMessenger.of(parentContext);
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.ulatVoidSaleConfirmTitle),
        content: Text(localizations.ulatVoidSaleConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.ulatVoidSaleButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final pinService = ref.read(storePinServiceProvider);
    if (await pinService.hasPin()) {
      if (!sheetContext.mounted) return;
      final verified = await verifyStorePin(
        sheetContext,
        ref,
        title: localizations.settingsPinPromptTitle,
      );
      if (!verified) return;
    }
    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    await ref.read(saleRepositoryProvider).voidSale(sale.id);
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.ulatVoidSaleSuccess)),
    );
  }
}

class _ExpensesSection extends ConsumerWidget {
  const _ExpensesSection({required this.grossProfit});

  final Money grossProfit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final expenses = ref.watch(ulatExpensesProvider).value ?? const <ExpenseEntry>[];
    final totalExpenses = expenses.fold(
      Money.zero(grossProfit.currency),
      (sum, entry) => sum + entry.amount,
    );
    final netIncome = grossProfit - totalExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizations.ulatExpensesTitle,
              style: AppTypography.meta(
                palette.textMuted,
                size: 13,
                weight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => unawaited(_showAddExpenseDialog(context, ref)),
              child: Text(localizations.ulatAddExpenseButton),
            ),
          ],
        ),
        TindaCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  localizations.ulatNetIncomeLabel,
                  style: AppTypography.body(palette.textMuted),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  formatMoney(netIncome),
                  key: ValueKey(netIncome.minorUnits),
                  style: AppTypography.title(
                    netIncome.isNegative ? palette.danger : palette.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        if (expenses.isEmpty)
          TindaCard(
            child: Text(
              localizations.ulatNoExpenses,
              style: AppTypography.body(palette.textMuted),
            ),
          )
        else
          for (final entry in expenses) ...[
            TindaCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: AppTypography.bodyStrong(palette.text),
                    ),
                  ),
                  Text(
                    formatMoney(entry.amount),
                    style: AppTypography.bodyStrong(palette.danger),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: palette.textMuted),
                    onPressed: () => unawaited(
                      ref.read(expenseRepositoryProvider).deleteExpense(entry.id),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
      ],
    );
  }

  Future<void> _showAddExpenseDialog(BuildContext context, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isFilipino = localizations.localeName.startsWith('fil');

    final saveRequest = await showDialog<({String title, Money amount})>(
      context: context,
      builder: (dialogContext) =>
          _AddExpenseDialog(currency: ref.read(storeCurrencyProvider)),
    );
    if (saveRequest == null) return;

    final result = await ref.read(expenseRepositoryProvider).addExpense(
      title: saveRequest.title,
      amount: saveRequest.amount,
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok<String, ExpenseFailure>():
        messenger.showSnackBar(
          SnackBar(
            content: Text(localizations.ulatExpenseSaved),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Err<String, ExpenseFailure>(:final failure):
        final errorMessage = switch (failure) {
          ExpenseTitleRequired() => isFilipino
              ? 'Kailangan ang pangalan ng gastos.'
              : 'Expense name is required.',
          ExpenseAmountInvalid() => isFilipino
              ? 'Hindi wasto ang halaga ng gastos.'
              : 'Expense amount is invalid.',
          ExpenseUnavailable() => isFilipino
              ? 'Hindi ma-save ang gastos ngayon. Subukan ulit.'
              : 'Could not save expense. Please try again.',
        };
        messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog({required this.currency});

  final Currency currency;

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _clearValidation() {
    if (_validationMessage == null) return;
    setState(() => _validationMessage = null);
  }

  void _save() {
    final localizations = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final amount = parseMoneyInput(_amountController.text, widget.currency);
    if (title.isEmpty || amount == null || !amount.isPositive) {
      setState(() {
        _validationMessage = localizations.localeName.startsWith('fil')
            ? 'Ilagay ang tamang pangalan at halaga ng gastos.'
            : 'Enter a valid expense name and amount.';
      });
      return;
    }
    Navigator.of(context).pop((title: title, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(localizations.ulatAddExpenseButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_validationMessage case final message?) ...[
            Text(
              message,
              style: AppTypography.meta(
                AppPalette.of(context).danger,
                size: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: localizations.ulatExpenseTitleLabel,
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearValidation(),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: localizations.ulatExpenseAmountLabel,
            ),
            onChanged: (_) => _clearValidation(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.commonCancel),
        ),
        TextButton(
          onPressed: _save,
          child: Text(localizations.commonSave),
        ),
      ],
    );
  }
}

class _MilestonesSection extends ConsumerWidget {
  const _MilestonesSection({
    required this.saleCount,
    required this.totalRevenueMinor,
  });

  final int saleCount;
  final int totalRevenueMinor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final isFilipino = localizations.localeName.startsWith('fil');
    final productCount =
        ref.watch(inventoryProductsProvider).value?.length ?? 0;
    final milestones = computeStoreMilestones(
      saleCount: saleCount,
      totalRevenueMinor: totalRevenueMinor,
      productCount: productCount,
    );
    final unlockedCount =
        milestones.where((milestone) => milestone.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isFilipino ? 'Mga Tagumpay' : 'Store Achievements',
              style: AppTypography.meta(
                palette.textMuted,
                size: 13,
                weight: FontWeight.w700,
              ),
            ),
            TindaBadge(label: '$unlockedCount / ${milestones.length}'),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        TindaCard(
          child: Column(
            children: [
              for (var index = 0; index < milestones.length; index++) ...[
                if (index > 0) Divider(color: palette.border, height: AppSpacing.s16),
                _MilestoneRow(
                  milestone: milestones[index],
                  isFilipino: isFilipino,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone, required this.isFilipino});

  final StoreMilestone milestone;
  final bool isFilipino;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final progress = milestone.target == 0
        ? 0.0
        : (milestone.current / milestone.target).clamp(0.0, 1.0);
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: milestone.isUnlocked ? 1.0 : 0.92),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: child,
          ),
          child: Icon(
            milestone.isUnlocked
                ? Icons.emoji_events_rounded
                : Icons.lock_outline_rounded,
            color: milestone.isUnlocked ? palette.primary : palette.textMuted,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFilipino ? milestone.titleFil : milestone.titleEn,
                style: AppTypography.bodyStrong(
                  milestone.isUnlocked ? palette.text : palette.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 450),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: palette.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      milestone.isUnlocked ? palette.primary : palette.borderStrong,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
