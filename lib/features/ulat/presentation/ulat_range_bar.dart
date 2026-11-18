part of 'ulat_screen.dart';

String _formatRangeLabel(AppLocalizations localizations, DayRange range) {
  final firstDate = dateOfLocalDay(range.first);
  final lastDate = dateOfLocalDay(range.last);
  final spansYears = firstDate.year != lastDate.year;
  final formatter = spansYears
      ? DateFormat.yMMMd(localizations.localeName)
      : DateFormat.MMMd(localizations.localeName);
  return localizations.reportsRangeLabel(
    formatter.format(firstDate),
    formatter.format(lastDate),
  );
}

String _formatDayLabel(AppLocalizations localizations, LocalDay day) =>
    DateFormat.MMMd(localizations.localeName).format(dateOfLocalDay(day));

Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
  final localizations = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final today = ref.read(ulatTodayProvider);
  final currentRange = ref.read(ulatCustomRangeProvider);
  final picked = await showDateRangePicker(
    context: context,
    firstDate: dateOfLocalDay(today.plusDays(1 - maxCustomRangeDays)),
    lastDate: dateOfLocalDay(today),
    initialDateRange: currentRange == null
        ? null
        : DateTimeRange(
            start: dateOfLocalDay(currentRange.first),
            end: dateOfLocalDay(currentRange.last),
          ),
  );
  if (picked == null) return;
  final range = customRangeFromPicker(
    start: picked.start,
    end: picked.end,
    today: today,
  );
  if (range == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.reportsRangeInvalid)),
    );
    return;
  }
  ref.read(ulatCustomRangeProvider.notifier).choose(range);
}

class _RangeBar extends ConsumerWidget {
  const _RangeBar({required this.range});

  final DayRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final today = ref.watch(ulatTodayProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatRangeLabel(localizations, range),
            style: AppTypography.bodyStrong(
              palette.text,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              ActionChip(
                label: Text(localizations.reportsThisMonth),
                onPressed: () => ref
                    .read(ulatCustomRangeProvider.notifier)
                    .choose(thisMonthRange(today)),
              ),
              ActionChip(
                label: Text(localizations.reportsLastMonth),
                onPressed: () => ref
                    .read(ulatCustomRangeProvider.notifier)
                    .choose(lastMonthRange(today)),
              ),
              ActionChip(
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(localizations.reportsPickDates),
                onPressed: () => unawaited(_pickCustomRange(context, ref)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
