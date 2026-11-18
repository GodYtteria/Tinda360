part of 'ulat_screen.dart';

const int _cashCountHistoryDays = 7;

final _cashExpectedProvider = StreamProvider.autoDispose<Money>((ref) {
  final today = ref.watch(ulatTodayProvider);
  return ref.watch(cashCountRepositoryProvider).watchExpectedCash(today);
});

final _cashCountHistoryProvider =
    StreamProvider.autoDispose<List<CashCountEntry>>((ref) {
      final today = ref.watch(ulatTodayProvider);
      final range = DayRange(today.plusDays(1 - _cashCountHistoryDays), today);
      return ref.watch(cashCountRepositoryProvider).watchInRange(range);
    });

String _differenceText(AppLocalizations localizations, Money difference) {
  if (difference.isPositive) {
    return localizations.cashCountOver(formatMoney(difference));
  }
  if (difference.isNegative) {
    return localizations.cashCountShort(
      formatMoney(Money(-difference.minorUnits, difference.currency)),
    );
  }
  return localizations.cashCountExact;
}

Color _differenceColor(AppPalette palette, Money difference) {
  if (difference.isNegative) return palette.danger;
  if (difference.isPositive) return palette.primary;
  return palette.success;
}

class _CashCountSection extends ConsumerStatefulWidget {
  const _CashCountSection();

  @override
  ConsumerState<_CashCountSection> createState() => _CashCountSectionState();
}

class _CashCountSectionState extends ConsumerState<_CashCountSection> {
  final TextEditingController _countedController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _countedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final counted = parseMoneyInput(
      _countedController.text,
      ref.read(storeCurrencyProvider),
    );
    if (counted == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.cashCountInvalidAmount)),
      );
      return;
    }
    setState(() => _isSaving = true);
    unawaited(HapticFeedback.lightImpact());
    final result = await ref
        .read(cashCountRepositoryProvider)
        .saveCount(counted: counted, note: _noteController.text);
    if (!mounted) return;
    setState(() => _isSaving = false);
    switch (result) {
      case Ok<String, CashCountFailure>():
        _countedController.clear();
        _noteController.clear();
        messenger.showSnackBar(
          SnackBar(content: Text(localizations.cashCountSaved)),
        );
      case Err<String, CashCountFailure>(:final failure):
        final message = switch (failure) {
          CashCountAmountInvalid() => localizations.cashCountInvalidAmount,
          CashCountUnavailable() => localizations.cashCountSaveFailed,
        };
        messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final currency = ref.watch(storeCurrencyProvider);
    final today = ref.watch(ulatTodayProvider);
    final expected = ref.watch(_cashExpectedProvider).value;
    final entries =
        ref.watch(_cashCountHistoryProvider).value ?? const <CashCountEntry>[];
    final todayEntries = entries.where((entry) => entry.day == today).toList();
    final earlierEntries = entries
        .where((entry) => entry.day != today)
        .toList();
    final typedCounted = parseMoneyInput(_countedController.text, currency);

    return TindaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.cashCountTitle,
            style: AppTypography.bodyStrong(
              palette.text,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  localizations.cashCountExpectedLabel,
                  style: AppTypography.meta(palette.textMuted, size: 13),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: MoneyText.text(
                  expected == null ? '-' : formatMoney(expected),
                  alignment: AlignmentDirectional.centerEnd,
                  style: AppTypography.bodyStrong(
                    palette.text,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _countedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: localizations.cashCountCountedLabel,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (typedCounted != null && expected != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              _differenceText(localizations, typedCounted - expected),
              style: AppTypography.bodyStrong(
                _differenceColor(palette, typedCounted - expected),
                weight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: localizations.cashCountNoteLabel,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TindaPrimaryButton(
            label: localizations.cashCountSaveButton,
            isLoading: _isSaving,
            onPressed: _save,
          ),
          if (todayEntries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            _CashCountList(
              heading: localizations.cashCountTodayHeading,
              entries: todayEntries,
              showDay: false,
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          if (earlierEntries.isEmpty && todayEntries.isEmpty)
            Text(
              localizations.cashCountNoHistory,
              style: AppTypography.meta(palette.textMuted, size: 13),
            )
          else if (earlierEntries.isNotEmpty)
            _CashCountList(
              heading: localizations.cashCountHistoryHeading,
              entries: earlierEntries,
              showDay: true,
            ),
        ],
      ),
    );
  }
}

class _CashCountList extends StatelessWidget {
  const _CashCountList({
    required this.heading,
    required this.entries,
    required this.showDay,
  });

  final String heading;
  final List<CashCountEntry> entries;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading,
          style: AppTypography.meta(
            palette.textMuted,
            size: 13,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showDay
                            ? '${_formatDayLabel(localizations, entry.day)} · ${localizations.cashCountRowSummary(formatMoney(entry.counted), formatMoney(entry.expected))}'
                            : localizations.cashCountRowSummary(
                                formatMoney(entry.counted),
                                formatMoney(entry.expected),
                              ),
                        style: AppTypography.meta(palette.text, size: 13),
                      ),
                      if (entry.note != null)
                        Text(
                          entry.note!,
                          style: AppTypography.meta(
                            palette.textMuted,
                            size: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: Text(
                    _differenceText(localizations, entry.difference),
                    textAlign: TextAlign.end,
                    style: AppTypography.bodyStrong(
                      _differenceColor(palette, entry.difference),
                      size: 13,
                      weight: FontWeight.w700,
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
