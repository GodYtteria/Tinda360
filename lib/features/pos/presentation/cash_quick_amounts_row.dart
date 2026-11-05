import 'package:flutter/material.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/data/suggested_cash_amounts.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/theme/app_tokens.dart';

String formatExactTenderedText(int totalMinorUnits) {
  final pesos = totalMinorUnits ~/ 100;
  final cents = totalMinorUnits % 100;
  if (cents == 0) return pesos.toString();
  return '$pesos.${cents.toString().padLeft(2, '0')}';
}

class CashQuickAmountsRow extends StatelessWidget {
  const CashQuickAmountsRow({
    required this.total,
    required this.onAmountSelected,
    required this.onExactSelected,
    super.key,
  });

  final Money total;
  final ValueChanged<int> onAmountSelected;
  final ValueChanged<String> onExactSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final amounts = suggestedCashAmounts(total.minorUnits);
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        if (total.isPositive)
          TindaFilterChip(
            label: localizations.checkoutExactAmountChip,
            selected: false,
            onTap: () =>
                onExactSelected(formatExactTenderedText(total.minorUnits)),
          ),
        for (final amount in amounts)
          TindaFilterChip(
            label: '₱$amount',
            selected: false,
            onTap: () => onAmountSelected(amount),
          ),
      ],
    );
  }
}
