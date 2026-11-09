import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinda360/core/achievements/store_milestone.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/failures/cash_count_failure.dart';
import 'package:tinda360/core/failures/expense_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/repositories/cash_count_providers.dart';
import 'package:tinda360/data/repositories/cash_count_repository.dart';
import 'package:tinda360/features/chat/presentation/chat_sheet.dart';
import 'package:tinda360/features/inventory/data/product_csv_exporter.dart';
import 'package:tinda360/features/inventory/presentation/inventory_screen.dart';
import 'package:tinda360/features/pos/presentation/receipt_preview_sheet.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/features/ulat/presentation/sale_return_sheet.dart';
import 'package:tinda360/features/ulat/presentation/ulat_notifier.dart';
import 'package:tinda360/features/ulat/presentation/ulat_range_math.dart';
import 'package:tinda360/features/ulat/presentation/ulat_report_text.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/report_pdf_service.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/csv_preview_sheet.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

part 'ulat_cash_count_section.dart';
part 'ulat_expenses_section.dart';
part 'ulat_range_bar.dart';
part 'ulat_recent_sales_section.dart';
part 'ulat_share_report_button.dart';

final StreamProvider<StoreProfile> _ulatStoreProfileProvider =
    StreamProvider.autoDispose<StoreProfile>(
      (ref) => ref.watch(storeProfileRepositoryProvider).watch(),
    );

class UlatScreen extends ConsumerWidget {
  const new({
    required this.onOpenSettings,
    required this.onOpenAiChat,
    super.key,
    this.onOpenTab,
  });

  final VoidCallback onOpenSettings;

  final VoidCallback onOpenAiChat;

  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
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
                ReportPeriod.custom: localizations.reportsCustom,
              },
              selected: selectedPeriod,
              onChanged: (period) {
                if (period != ReportPeriod.custom) {
                  ref.read(ulatPeriodProvider.notifier).select(period);
                  return;
                }
                if (ref.read(ulatCustomRangeProvider) != null) {
                  ref
                      .read(ulatPeriodProvider.notifier)
                      .select(ReportPeriod.custom);
                  return;
                }
                unawaited(_pickCustomRange(context, ref));
              },
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
                data: (state) => TindaScreenBody(
                  key: ValueKey(
                    'ulat-${state.period.name}-${state.range.first.serial}-${state.range.last.serial}-${state.summary.revenue.minorUnits}-${state.summary.saleCount}',
                  ),
                  child: _ReportContent(
                    state: state,
                    onOpenAiChat: onOpenAiChat,
                    onOpenTab: onOpenTab,
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
  const new({
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
    unawaited(HapticFeedback.lightImpact());
    final localizations = AppLocalizations.of(context);
    setState(() => _isExporting = true);
    try {
      final profile = await ref
          .read(storeProfileRepositoryProvider)
          .watch()
          .first;
      final expenses = await ref.read(ulatExpensesProvider.future);
      final totalExpenses = expenses.fold(
        Money.zero(widget.state.summary.profit.currency),
        (sum, entry) => sum + entry.amount,
      );
      final bytes = await ReportPdfService.buildReportPdf(
        storeName: profile.name,
        totalExpenses: totalExpenses,
        periodLabel: _periodLabel(
          localizations,
          widget.state.period,
          widget.state.range,
        ),
        state: widget.state,
        localizations: localizations,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'tinda360_report_${_rangeFileSuffix(widget.state)}.pdf',
      );
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLogProvider)
          .error('ulat_export_pdf_failed', error, stackTrace);
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
    unawaited(HapticFeedback.lightImpact());
    final localizations = AppLocalizations.of(context);
    try {
      final sales = await ref
          .read(saleRepositoryProvider)
          .watchRecentSales(widget.state.range, limit: null)
          .first;
      final csvContent = exportSalesCsv(sales);
      final parsed = parseCsvForPreview(csvContent);
      if (!mounted) return;
      await CsvPreviewSheet.show(
        context,
        title: localizations.reportsExportCsv,
        headers: parsed.headers,
        rows: parsed.rows,
        fileName: 'tinda360_sales_${_rangeFileSuffix(widget.state)}.csv',
        csvContent: csvContent,
        successMessage: localizations.reportsExportCsvSuccess,
      );
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLogProvider)
          .error('ulat_export_csv_failed', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.reportsExportCsvError)),
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
        if (widget.state.period == ReportPeriod.custom)
          _RangeBar(range: widget.state.range),
        _StatsGrid(state: widget.state),
        const SizedBox(height: AppSpacing.s16),
        _SalesTrendCard(
          period: widget.state.period,
          range: widget.state.range,
          summary: summary,
          totalUtang: widget.state.totalUtang,
        ),
        const SizedBox(height: AppSpacing.s16),
        _TopProductsCard(
          period: widget.state.period,
          range: widget.state.range,
          topProducts: widget.state.topProducts,
        ),
        if (widget.state.period == ReportPeriod.today) ...[
          const SizedBox(height: AppSpacing.s16),
          const _CashCountSection(),
        ],
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
        const SizedBox(height: AppSpacing.s10),
        _ShareReportTextButton(state: widget.state),
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
          width: double.infinity,
          height: AppSizes.secondaryButtonHeight,
          child: FilledButton.icon(
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              final periodLabel = _periodLabel(
                localizations,
                widget.state.period,
                widget.state.range,
              );
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
  const new({required this.state});

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
  const new({
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
            child: SizedBox(
              key: ValueKey<String>(value),
              width: double.infinity,
              child: MoneyText.text(
                value,
                style: AppTypography.title(valueColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _periodLabel(
  AppLocalizations localizations,
  ReportPeriod period,
  DayRange range,
) => switch (period) {
  ReportPeriod.today => localizations.reportsToday,
  ReportPeriod.week => localizations.reportsWeek,
  ReportPeriod.month => localizations.reportsMonth,
  ReportPeriod.custom => _formatRangeLabel(localizations, range),
};

String _rangeFileSuffix(UlatState state) => state.period == ReportPeriod.custom
    ? '${state.range.first.serial}_${state.range.last.serial}'
    : state.period.name;

class _SalesTrendCard extends StatelessWidget {
  const new({
    required this.period,
    required this.range,
    required this.summary,
    required this.totalUtang,
  });

  final ReportPeriod period;
  final DayRange range;
  final SalesSummary summary;
  final Money totalUtang;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final hasActivity = summary.saleCount > 0 || totalUtang.isPositive;
    final periodLabel = _periodLabel(localizations, period, range);
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
                    milliseconds: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : 450,
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
  const new({required this.color, required this.label});

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
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta(palette.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SalesTrendPainter extends CustomPainter {
  const new({
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
    final barWidth = math.min<double>(44, size.width / 6);
    final slotWidth = size.width / values.length;
    const radius = Radius.circular(AppRadii.smallButton);

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
  const new({
    required this.period,
    required this.range,
    required this.topProducts,
  });

  final ReportPeriod period;
  final DayRange range;
  final List<TopProduct> topProducts;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final periodLabel = _periodLabel(localizations, period, range);
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
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
            ),
            child: topProducts.isEmpty
                ? TindaEmptyState(
                    key: const ValueKey('top-empty'),
                    icon: Icons.shopping_bag_outlined,
                    title: localizations.reportsEmptyTitlePeriod(periodLabel),
                    body: localizations.reportsEmptyBody,
                  )
                : Column(
                    key: ValueKey<int>(topProducts.length),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < topProducts.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: AppSpacing.s12),
                        _AnimatedListEntry(
                          index: index,
                          child: _TopProductRow(
                            rank: index + 1,
                            item: topProducts[index],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const new({required this.rank, required this.item});

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

class _AnimatedListEntry extends StatelessWidget {
  const new({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 160 + (index.clamp(0, 8) * 18)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _MilestonesSection extends ConsumerWidget {
  const new({
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
    final unlockedCount = milestones
        .where((milestone) => milestone.isUnlocked)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                isFilipino ? 'Mga Tagumpay' : 'Store Achievements',
                style: AppTypography.meta(
                  palette.textMuted,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            TindaBadge(label: '$unlockedCount / ${milestones.length}'),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        TindaCard(
          child: Column(
            children: [
              for (var index = 0; index < milestones.length; index++) ...[
                if (index > 0)
                  Divider(color: palette.border, height: AppSpacing.s16),
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
  const new({required this.milestone, required this.isFilipino});

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
                      milestone.isUnlocked
                          ? palette.primary
                          : palette.borderStrong,
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
