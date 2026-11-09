import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/pos/presentation/checkout_interest.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

String interestErrorMessage(
  AppLocalizations localizations,
  InterestInputError error,
) => switch (error) {
  InterestInputError.invalidPercent =>
    localizations.checkoutInterestPercentInvalid,
  InterestInputError.invalidAmount =>
    localizations.checkoutInterestAmountInvalid,
  InterestInputError.exceedsUtang => localizations.checkoutInterestTooMuch,
};

class CheckoutInterestField extends StatelessWidget {
  const new({
    required this.controller,
    required this.mode,
    required this.onModeChanged,
    required this.onChanged,
    required this.resolution,
    required this.preview,
    super.key,
  });

  final TextEditingController controller;
  final InterestInputMode mode;
  final ValueChanged<InterestInputMode> onModeChanged;
  final ValueChanged<String> onChanged;
  final InterestResolution resolution;
  final InterestPreviewAmounts? preview;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final error = resolution.error;
    final previewAmounts = preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.checkoutInterestPrompt,
          style: AppTypography.meta(palette.textMuted, size: 13),
        ),
        const SizedBox(height: AppSpacing.s8),
        TindaSegmentedControl<InterestInputMode>(
          segments: const {
            InterestInputMode.percent: '%',
            InterestInputMode.peso: '₱',
          },
          selected: mode,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: AppSpacing.s8),
        TindaTextInput(
          label: localizations.checkoutInterestLabel,
          controller: controller,
          errorText: error == null
              ? null
              : interestErrorMessage(localizations, error),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
        ),
        if (previewAmounts != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            localizations.checkoutInterestPreview(
              formatMoney(previewAmounts.utang),
              formatMoney(previewAmounts.interest),
              formatMoney(previewAmounts.total),
            ),
            style: AppTypography.bodyStrong(palette.text),
          ),
        ],
      ],
    );
  }
}
