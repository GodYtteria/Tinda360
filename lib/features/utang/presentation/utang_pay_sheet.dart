import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/failures/customer_failure.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Whether the user is paying the full utang balance or a partial amount.
enum UtangPaymentMode {
  /// Pays the entire outstanding balance.
  full,

  /// Pays a user-entered partial amount.
  partial,
}

/// Computes the preview balance after [payment] is applied to [currentBalance].
Money computeRemainingBalance(Money currentBalance, Money? payment) {
  if (payment == null || !payment.isPositive) return currentBalance;
  if (payment > currentBalance) return Money.zero(currentBalance.currency);
  return currentBalance - payment;
}

/// Bottom sheet for recording a suki payment or adding a new suki.
class UtangPaySheet extends ConsumerStatefulWidget {
  /// Opens the sheet in payment mode for [balance].
  const UtangPaySheet.pay({required CustomerBalance balance, super.key})
    : _balance = balance;

  /// Opens the sheet in new-suki creation mode.
  const UtangPaySheet.newSuki({super.key}) : _balance = null;

  final CustomerBalance? _balance;

  /// Presents the payment sheet for [balance].
  static Future<void> showPay(
    BuildContext context,
    CustomerBalance balance,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppPalette.of(context).scrim,
    builder: (_) => UtangPaySheet.pay(balance: balance),
  );

  /// Presents the new-suki sheet.
  static Future<void> showNewSuki(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: AppPalette.of(context).scrim,
        builder: (_) => const UtangPaySheet.newSuki(),
      );

  @override
  ConsumerState<UtangPaySheet> createState() => _UtangPaySheetState();
}

class _UtangPaySheetState extends ConsumerState<UtangPaySheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();

  UtangPaymentMode _paymentMode = UtangPaymentMode.full;
  bool _isSubmitting = false;
  String? _amountError;
  String? _nameError;
  String? _limitError;
  String? _generalError;

  bool get _isPayMode => widget._balance != null;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (_isPayMode) {
      return _buildPaySheet(context, localizations, widget._balance!);
    }
    return _buildNewSukiSheet(context, localizations);
  }

  Widget _buildPaySheet(
    BuildContext context,
    AppLocalizations localizations,
    CustomerBalance balance,
  ) {
    final palette = AppPalette.of(context);
    final currency = balance.balance.currency;
    final enteredAmount = _paymentMode == UtangPaymentMode.full
        ? balance.balance
        : parseMoneyInput(_amountController.text, currency);
    final previewBalance = computeRemainingBalance(
      balance.balance,
      enteredAmount,
    );

    return TindaBottomSheet(
      title: localizations.utangPayTitle,
      closeTooltip: localizations.commonClose,
      footer: TindaPrimaryButton(
        label: localizations.utangRecordPayment,
        isLoading: _isSubmitting,
        onPressed: () => _submitPayment(localizations, balance),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrentBalanceCard(balance: balance),
          const SizedBox(height: AppSpacing.s16),
          TindaSegmentedControl<UtangPaymentMode>(
            segments: {
              UtangPaymentMode.full: localizations.utangFullPayment,
              UtangPaymentMode.partial: localizations.utangPartialPayment,
            },
            selected: _paymentMode,
            onChanged: (mode) => setState(() {
              _paymentMode = mode;
              _amountError = null;
              _generalError = null;
            }),
          ),
          if (_paymentMode == UtangPaymentMode.partial) ...[
            const SizedBox(height: AppSpacing.s16),
            TindaTextInput(
              controller: _amountController,
              label: localizations.utangPaymentAmountLabel,
              hintText: '0.00',
              errorText: _amountError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              autofocus: true,
              onChanged: (_) => setState(() {
                _amountError = null;
                _generalError = null;
              }),
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          _NewBalancePreview(
            label: localizations.utangNewBalanceLabel,
            amount: previewBalance,
          ),
          if (_generalError != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              _generalError!,
              style: AppTypography.meta(palette.danger, size: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewSukiSheet(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final palette = AppPalette.of(context);
    return TindaBottomSheet(
      title: localizations.utangNewSukiTitle,
      closeTooltip: localizations.commonClose,
      footer: TindaPrimaryButton(
        label: localizations.utangSaveSuki,
        isLoading: _isSubmitting,
        onPressed: () => _submitNewSuki(localizations),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TindaTextInput(
            controller: _nameController,
            label: localizations.utangSukiNameLabel,
            errorText: _nameError,
            textInputAction: TextInputAction.next,
            autofocus: true,
            onChanged: (_) => setState(() {
              _nameError = null;
              _generalError = null;
            }),
          ),
          const SizedBox(height: AppSpacing.s14),
          TindaTextInput(
            controller: _phoneController,
            label: localizations.utangSukiPhoneLabel,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.s14),
          TindaTextInput(
            controller: _limitController,
            label: localizations.utangSukiLimitLabel,
            hintText: '0.00',
            errorText: _limitError,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _limitError = null;
              _generalError = null;
            }),
          ),
          if (_generalError != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              _generalError!,
              style: AppTypography.meta(palette.danger, size: 13),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitPayment(
    AppLocalizations localizations,
    CustomerBalance balance,
  ) async {
    if (_isSubmitting) return;
    final currency = balance.balance.currency;
    final amount = _paymentMode == UtangPaymentMode.full
        ? balance.balance
        : parseMoneyInput(_amountController.text, currency);

    if (amount == null || !amount.isPositive) {
      setState(() {
        _amountError = localizations.failureCustomerAmountInvalid;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _amountError = null;
      _generalError = null;
    });

    final result = await ref
        .read(customerRepositoryProvider)
        .recordPayment(balance.customer.id, amount);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        final message = localizedFailureMessage(localizations, failure);
        setState(() {
          if (failure is PaymentExceedsBalance ||
              failure is CustomerAmountInvalid) {
            _amountError = message;
          } else {
            _generalError = message;
          }
        });
    }
  }

  Future<void> _submitNewSuki(AppLocalizations localizations) async {
    if (_isSubmitting) return;
    final currency = ref.read(storeCurrencyProvider);
    final rawLimit = _limitController.text.trim();
    Money? limit;
    if (rawLimit.isNotEmpty) {
      limit = parseMoneyInput(rawLimit, currency);
      if (limit == null || !limit.isPositive) {
        setState(() {
          _limitError = localizations.failureCustomerAmountInvalid;
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _nameError = null;
      _limitError = null;
      _generalError = null;
    });

    final result = await ref
        .read(customerRepositoryProvider)
        .create(
          CustomerDraft(
            name: _nameController.text,
            phone: _phoneController.text,
            creditLimit: limit,
          ),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        final message = localizedFailureMessage(localizations, failure);
        setState(() {
          switch (failure) {
            case CustomerNameRequired():
              _nameError = message;
            case CustomerAmountInvalid():
              _limitError = message;
            case CustomerNotFound() ||
                PaymentExceedsBalance() ||
                CustomerStoreUnavailable():
              _generalError = message;
          }
        });
    }
  }
}

class _CurrentBalanceCard extends StatelessWidget {
  const _CurrentBalanceCard({required this.balance});

  final CustomerBalance balance;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final palette = AppPalette.of(context);
    return TindaCard(
      backgroundColor: palette.dangerSoft,
      borderColor: palette.danger.withValues(alpha: 0.25),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  balance.customer.name,
                  style: AppTypography.bodyStrong(palette.text),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  localizations.utangCurrentBalance,
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Text(
            formatMoney(balance.balance),
            style: AppTypography.title(palette.danger),
          ),
        ],
      ),
    );
  }
}

class _NewBalancePreview extends StatelessWidget {
  const _NewBalancePreview({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.meta(
                palette.textMuted,
                size: 13,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            formatMoney(amount),
            style: AppTypography.bodyStrong(
              palette.text,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
