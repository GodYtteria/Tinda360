import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/customers/interest_rate.dart';
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

class SukiEditSheet extends ConsumerStatefulWidget {
  const SukiEditSheet({required this.customer, super.key});

  final Customer customer;

  static Future<bool?> show(BuildContext context, Customer customer) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: AppPalette.of(context).scrim,
        builder: (_) => SukiEditSheet(customer: customer),
      );

  @override
  ConsumerState<SukiEditSheet> createState() => _SukiEditSheetState();
}

class _SukiEditSheetState extends ConsumerState<SukiEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _limitController;
  late final TextEditingController _interestController;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer.name);
    _phoneController = TextEditingController(text: customer.phone ?? '');
    final limit = customer.creditLimit;
    _limitController = TextEditingController(
      text: limit == null ? '' : _plainAmount(limit),
    );
    final interestTenths = customer.interestPercentTenths;
    _interestController = TextEditingController(
      text: interestTenths == null ? '' : formatInterestPercent(interestTenths),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _limitController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  String _plainAmount(Money amount) =>
      formatMoney(amount).replaceFirst('₱', '');

  Future<void> _save() async {
    if (_isSaving) return;
    final localizations = AppLocalizations.of(context);
    final currency = ref.read(storeCurrencyProvider);
    final limitText = _limitController.text.trim();
    Money? limit;
    if (limitText.isNotEmpty) {
      limit = parseMoneyInput(limitText, currency);
      if (limit == null) {
        setState(
          () => _errorMessage = localizations.failureCustomerAmountInvalid,
        );
        return;
      }
    }
    final interestText = _interestController.text.trim();
    int? interestTenths;
    if (interestText.isNotEmpty) {
      interestTenths = parseInterestPercentTenths(interestText);
      if (interestTenths == null) {
        setState(() => _errorMessage = localizations.sukiTuboInvalid);
        return;
      }
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final result = await ref
        .read(customerRepositoryProvider)
        .update(
          widget.customer.id,
          CustomerDraft(
            name: _nameController.text,
            phone: _phoneController.text,
            creditLimit: limit,
            interestPercentTenths: interestTenths,
          ),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _isSaving = false;
          _errorMessage = localizedFailureMessage(localizations, failure);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return TindaBottomSheet(
      title: localizations.sukiEditTitle,
      closeTooltip: localizations.commonClose,
      footer: TindaPrimaryButton(
        label: localizations.sukiSaveChanges,
        isLoading: _isSaving,
        onPressed: _isSaving ? null : _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TindaTextInput(
            controller: _nameController,
            label: localizations.utangSukiNameLabel,
            textInputAction: TextInputAction.next,
            autofocus: true,
            onChanged: (_) => setState(() => _errorMessage = null),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _errorMessage = null),
          ),
          const SizedBox(height: AppSpacing.s14),
          TindaTextInput(
            controller: _interestController,
            label: localizations.sukiTuboLabel,
            hintText: localizations.sukiTuboHint,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _errorMessage = null),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              _errorMessage!,
              style: AppTypography.meta(palette.danger, size: 13),
            ),
          ],
        ],
      ),
    );
  }
}
