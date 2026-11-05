import 'package:flutter/material.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class ProductNoCountSwitchRow extends StatelessWidget {
  const ProductNoCountSwitchRow({
    required this.noCount,
    required this.onChanged,
    super.key,
  });

  final bool noCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.productNoCountSwitch,
                style: AppTypography.meta(
                  palette.text,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
              Text(
                localizations.productNoCountHint,
                style: AppTypography.meta(palette.textMuted, size: 12),
              ),
            ],
          ),
        ),
        TindaToggleSwitch(value: noCount, onChanged: onChanged),
      ],
    );
  }
}

class ProductExpiryField extends StatelessWidget {
  const ProductExpiryField({
    required this.expiryDay,
    required this.today,
    required this.onChanged,
    super.key,
  });

  final LocalDay? expiryDay;
  final LocalDay today;
  final ValueChanged<LocalDay?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final initial = (expiryDay ?? today).toLocalDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    onChanged(LocalDay.fromLocal(picked));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final day = expiryDay;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pick(context),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                day == null
                    ? localizations.productExpiryLabel
                    : '${localizations.productExpiryLabel}: '
                          '${ExpiryRules.formatIso(day)}',
              ),
            ),
          ),
        ),
        if (day != null)
          IconButton(
            icon: Icon(Icons.close_rounded, color: palette.textMuted),
            tooltip: localizations.productExpiryClear,
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

class ProductFormWarning extends StatelessWidget {
  const ProductFormWarning({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Text(
        message,
        style: AppTypography.meta(palette.accent, size: 13),
      ),
    );
  }
}
