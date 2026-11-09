part of 'ulat_screen.dart';

class _ShareReportTextButton extends ConsumerWidget {
  const new({required this.state});

  final UlatState state;

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    unawaited(HapticFeedback.lightImpact());
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = await ref
          .read(storeProfileRepositoryProvider)
          .watch()
          .first;
      final expenses = await ref.read(ulatExpensesProvider.future);
      final totalExpenses = expenses.fold(
        Money.zero(state.summary.profit.currency),
        (sum, entry) => sum + entry.amount,
      );
      CashCountEntry? latestCashCount;
      if (state.period == ReportPeriod.today) {
        final counts = await ref
            .read(cashCountRepositoryProvider)
            .watchInRange(state.range)
            .first;
        for (final entry in counts) {
          if (latestCashCount == null ||
              entry.createdAtMs > latestCashCount.createdAtMs) {
            latestCashCount = entry;
          }
        }
      }
      final text = buildUlatReportText(
        localizations: localizations,
        storeName: profile.name,
        rangeLabel: _periodLabel(localizations, state.period, state.range),
        summary: state.summary,
        topProducts: state.topProducts,
        totalExpenses: totalExpenses,
        totalUtang: state.totalUtang,
        latestCashCount: latestCashCount,
      );
      await SharePlus.instance.share(ShareParams(text: text));
    } on Exception {
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.reportsExportPdfError)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TindaSecondaryButton(
      label: AppLocalizations.of(context).ulatShareButton,
      icon: Icons.share_outlined,
      onPressed: () => unawaited(_share(context, ref)),
    );
  }
}
