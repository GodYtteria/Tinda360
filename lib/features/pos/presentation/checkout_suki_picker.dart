import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/presentation/checkout_sheet.dart';
import 'package:tinda360/features/pos/presentation/checkout_shortfall.dart';
import 'package:tinda360/features/utang/presentation/utang_pay_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class CheckoutSukiPicker extends ConsumerStatefulWidget {
  const new({
    required this.selectedCustomerId,
    required this.onSelectCustomer,
    this.additionalUtang,
    this.footer = const [],
    super.key,
  });

  final String? selectedCustomerId;
  final ValueChanged<String> onSelectCustomer;
  final Money? additionalUtang;
  final List<Widget> footer;

  @override
  ConsumerState<CheckoutSukiPicker> createState() => _CheckoutSukiPickerState();
}

class _CheckoutSukiPickerState extends ConsumerState<CheckoutSukiPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CustomerBalance? _findSelectedCustomer(List<CustomerBalance> customers) {
    final selectedId = widget.selectedCustomerId;
    if (selectedId == null) return null;
    for (final item in customers) {
      if (item.customer.id == selectedId) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final customersAsync = ref.watch(checkoutCustomersProvider);

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 0 : 200),
      child: customersAsync.when(
        loading: () => const Center(
          key: ValueKey('checkout-customers-loading'),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.s16),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, _) => Text(
          localizations.homeLoadFailed,
          key: const ValueKey('checkout-customers-error'),
          style: AppTypography.body(palette.danger),
        ),
        data: (customers) {
          final query = _searchQuery.trim().toLowerCase();
          final filtered = query.isEmpty
              ? customers
              : customers.where((item) {
                  final nameMatch = item.customer.name.toLowerCase().contains(
                    query,
                  );
                  final phoneMatch =
                      item.customer.phone?.toLowerCase().contains(query) ??
                      false;
                  return nameMatch || phoneMatch;
                }).toList();
          final selectedCustomer = _findSelectedCustomer(customers);
          final showCreditLimitWarning =
              selectedCustomer != null &&
              isNearOrOverCreditLimit(
                balance: selectedCustomer.balance,
                creditLimit: selectedCustomer.customer.creditLimit,
                additionalUtang:
                    widget.additionalUtang ??
                    Money.zero(selectedCustomer.balance.currency),
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      localizations.checkoutSelectSuki,
                      style: AppTypography.meta(
                        palette.text,
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TindaTextLinkButton(
                    label: localizations.utangAddSuki,
                    onPressed: () async {
                      unawaited(HapticFeedback.selectionClick());
                      final createdCustomerId = await UtangPaySheet.showNewSuki(
                        context,
                      );
                      if (createdCustomerId != null && mounted) {
                        widget.onSelectCustomer(createdCustomerId);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              TindaTextInput(
                label: localizations.commonSearch,
                hintText: localizations.utangSearchHint,
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: AppSpacing.s12),
              if (customers.isEmpty)
                TindaCard(
                  backgroundColor: palette.surfaceMuted,
                  child: Text(
                    localizations.checkoutNoSuki,
                    style: AppTypography.body(palette.textMuted),
                  ),
                )
              else if (filtered.isEmpty)
                TindaCard(
                  backgroundColor: palette.surfaceMuted,
                  child: Text(
                    localizations.utangEmptyTitle,
                    style: AppTypography.body(palette.textMuted),
                  ),
                )
              else
                for (final item in filtered) ...[
                  TindaListRow(
                    title: item.customer.name,
                    subtitle: formatMoney(item.balance),
                    trailing: Icon(
                      item.customer.id == widget.selectedCustomerId
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: item.customer.id == widget.selectedCustomerId
                          ? palette.primary
                          : palette.textMuted,
                    ),
                    onTap: () => widget.onSelectCustomer(item.customer.id),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                ],
              if (showCreditLimitWarning) ...[
                const SizedBox(height: AppSpacing.s4),
                TindaBanner(
                  icon: Icons.warning_amber_rounded,
                  title: localizations.checkoutCreditNearTitle,
                  body: localizations.checkoutCreditNearBody(
                    selectedCustomer.customer.name,
                    formatMoney(selectedCustomer.balance),
                    formatMoney(selectedCustomer.customer.creditLimit!),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              ...widget.footer,
            ],
          );
        },
      ),
    );
  }
}
