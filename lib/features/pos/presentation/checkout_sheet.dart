import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/failures/sale_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';
import 'package:tinda360/features/pos/presentation/pos_screen.dart';
import 'package:tinda360/features/pos/presentation/sale_done_sheet.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/features/utang/presentation/utang_pay_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Watches active customers and their utang balances for the utang picker.
final checkoutCustomersProvider =
    StreamProvider.autoDispose<List<CustomerBalance>>(
      (ref) => ref.watch(customerRepositoryProvider).watchBalances(),
    );

/// Bottom sheet for reviewing cart items, choosing payment method, and
/// recording a sale.
class CheckoutSheet extends ConsumerStatefulWidget {
  /// Creates the checkout sheet.
  const CheckoutSheet({
    required this.products,
    required this.cart,
    super.key,
  });

  /// Active products snapshot used to resolve names, prices, and units.
  final List<StockedProduct> products;

  /// Cart quantities keyed by product id.
  final Map<String, Quantity> cart;

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  static const List<int> _quickPesoAmounts = [20, 50, 100, 500, 1000];

  final TextEditingController _tenderedController = TextEditingController();
  final TextEditingController _ewalletRefController = TextEditingController();

  PaymentMethod _method = PaymentMethod.cash;
  String? _selectedCustomerId;
  String? _inlineError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _tenderedController.dispose();
    _ewalletRefController.dispose();
    super.dispose();
  }

  List<_CheckoutLine> _resolveLines(Map<String, Quantity> cart) {
    final byId = <String, StockedProduct>{
      for (final item in widget.products) item.product.id: item,
    };
    final lines = <_CheckoutLine>[];
    for (final entry in cart.entries) {
      final item = byId[entry.key];
      if (item == null) continue;
      lines.add(
        _CheckoutLine(
          stocked: item,
          quantity: entry.value,
          subtotal: SaleMath.lineTotal(item.product.price, entry.value),
        ),
      );
    }
    return lines;
  }

  Money _computeTotal(List<_CheckoutLine> lines, Currency currency) {
    var total = Money.zero(currency);
    for (final line in lines) {
      total += line.subtotal;
    }
    return total;
  }

  Money? _parsedTendered(Currency currency) =>
      parseMoneyInput(_tenderedController.text, currency);

  Future<void> _submitSale(List<_CheckoutLine> lines, Money total) async {
    if (_isSubmitting) return;
    final currency = ref.read(storeCurrencyProvider);
    final tendered = _parsedTendered(currency);
    final ewalletRef = _ewalletRefController.text.trim();
    final draft = SaleDraft(
      method: _method,
      lines: ref.read(posCartProvider.notifier).toSaleLines(),
      cashTendered: _method == PaymentMethod.cash ? tendered : null,
      customerId: _method == PaymentMethod.utang ? _selectedCustomerId : null,
      ewalletReference:
          _method == PaymentMethod.ewallet && ewalletRef.isNotEmpty
              ? ewalletRef
              : null,
    );

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });
    final result = await ref.read(saleRepositoryProvider).record(draft);
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    switch (result) {
      case Ok<String, SaleFailure>():
        _handleSaleSuccess(lines, total, tendered ?? total, currency);
      case Err<String, SaleFailure>(:final failure):
        setState(() {
          _isSubmitting = false;
          _inlineError = localizedFailureMessage(localizations, failure);
        });
    }
  }

  void _handleSaleSuccess(
    List<_CheckoutLine> lines,
    Money total,
    Money tendered,
    Currency currency,
  ) {
    final localizations = AppLocalizations.of(context);
    final paid = _method == PaymentMethod.cash ? tendered : total;
    final change = _method == PaymentMethod.cash
        ? SaleMath.changeDue(total: total, tendered: paid)
        : Money.zero(currency);
    final receiptLines = [
      for (final line in lines)
        '${line.stocked.product.name} '
            'x${formatQuantity(line.quantity, line.stocked.product.unit)} '
            '${localizedUnit(localizations, line.stocked.product.unit)} '
            '= ${formatMoney(line.subtotal)}',
    ];
    final storeName =
        ref.read(posStoreProfileProvider).asData?.value.name ?? '';
    final timestamp = DateTime.now();
    ref.read(posCartProvider.notifier).clear();
    unawaited(
      ref.read(settingsNotifierProvider.notifier).triggerAutoBackupIfEnabled(),
    );
    final navigator = Navigator.of(context);
    final scrimColor = AppPalette.of(context).scrim;
    navigator.pop();
    unawaited(
      showModalBottomSheet<void>(
        context: navigator.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: scrimColor,
        builder: (_) => SaleDoneSheet(
          total: total,
          paid: paid,
          change: change,
          receiptLines: receiptLines,
          storeName: storeName,
          timestamp: timestamp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final currency = ref.watch(storeCurrencyProvider);
    final cart = ref.watch(posCartProvider);
    final cartNotifier = ref.read(posCartProvider.notifier);
    final lines = _resolveLines(cart);
    final total = _computeTotal(lines, currency);
    final tendered = _parsedTendered(currency);
    final change = tendered == null
        ? null
        : SaleMath.changeDue(total: total, tendered: tendered);

    return TindaBottomSheet(
      title: localizations.checkoutTitle,
      closeTooltip: localizations.commonClose,
      footer: TindaPrimaryButton(
        label: _method == PaymentMethod.utang
            ? localizations.checkoutRecordUtang
            : localizations.checkoutFinishSale,
        isLoading: _isSubmitting,
        onPressed: (_isSubmitting || lines.isEmpty)
            ? null
            : () => _submitSale(lines, total),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ItemsSummaryCard(
            lines: lines,
            total: total,
            onDecrement: cartNotifier.decrement,
            onIncrement: cartNotifier.increment,
          ),
          const SizedBox(height: AppSpacing.s16),
          TindaSegmentedControl<PaymentMethod>(
            segments: {
              PaymentMethod.cash: localizations.checkoutMethodCash,
              PaymentMethod.ewallet: localizations.checkoutMethodEwallet,
              PaymentMethod.utang: localizations.checkoutMethodUtang,
            },
            selected: _method,
            onChanged: (method) {
              if (method == _method) return;
              unawaited(HapticFeedback.selectionClick());
              setState(() {
                _method = method;
                _inlineError = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.s16),
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
            ),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_method),
              child: _method == PaymentMethod.cash
                  ? _CashSection(
                      controller: _tenderedController,
                      quickAmounts: _quickPesoAmounts,
                      change: change,
                      errorText: _inlineError,
                      onAmountSelected: (amount) {
                        unawaited(HapticFeedback.lightImpact());
                        _tenderedController.text = amount.toString();
                        setState(() => _inlineError = null);
                      },
                      onChanged: (_) => setState(() => _inlineError = null),
                    )
                  : _method == PaymentMethod.ewallet
                      ? _EwalletSection(
                          controller: _ewalletRefController,
                          errorText: _inlineError,
                        )
                      : _UtangSection(
                          selectedCustomerId: _selectedCustomerId,
                          errorText: _inlineError,
                          onSelectCustomer: (customerId) {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() {
                              _selectedCustomerId = customerId;
                              _inlineError = null;
                            });
                          },
                        ),
            ),
          ),
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
            ),
            child: (_method != PaymentMethod.cash && _inlineError != null)
                ? Padding(
                    key: ValueKey<String>(_inlineError!),
                    padding: const EdgeInsets.only(top: AppSpacing.s8),
                    child: Text(
                      _inlineError!,
                      style: AppTypography.meta(palette.danger, size: 13),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CheckoutLine {
  const _CheckoutLine({
    required this.stocked,
    required this.quantity,
    required this.subtotal,
  });

  final StockedProduct stocked;
  final Quantity quantity;
  final Money subtotal;
}

class _ItemsSummaryCard extends StatelessWidget {
  const _ItemsSummaryCard({
    required this.lines,
    required this.total,
    required this.onDecrement,
    required this.onIncrement,
  });

  final List<_CheckoutLine> lines;
  final Money total;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onIncrement;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return TindaCard(
      backgroundColor: palette.surfaceMuted,
      child: Column(
        children: [
          for (final line in lines) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${line.stocked.product.name} '
                    '× ${formatQuantity(line.quantity, line.stocked.product.unit)}',
                    style: AppTypography.body(palette.text),
                  ),
                ),
                _LineQuantityButton(
                  icon: Icons.remove,
                  tooltip: localizations.posRemoveFromCart(
                    line.stocked.product.name,
                  ),
                  onPressed: () => onDecrement(line.stocked.product.id),
                  palette: palette,
                ),
                const SizedBox(width: AppSpacing.s4),
                _LineQuantityButton(
                  icon: Icons.add,
                  tooltip: localizations.posAddToCart(
                    line.stocked.product.name,
                  ),
                  onPressed: () => onIncrement(line.stocked.product.id),
                  palette: palette,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  formatMoney(line.subtotal),
                  style: AppTypography.bodyStrong(palette.text),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          Divider(color: palette.borderStrong),
          const SizedBox(height: AppSpacing.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations.checkoutTotalLabel,
                style: AppTypography.bodyStrong(palette.text, size: 16),
              ),
              Text(
                formatMoney(total),
                style: AppTypography.display(palette.primary, size: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineQuantityButton extends StatelessWidget {
  const _LineQuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.palette,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            side: BorderSide(color: palette.border),
          ),
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onPressed();
            },
            borderRadius: BorderRadius.circular(AppRadii.button),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              child: Icon(icon, size: 18, color: palette.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _CashSection extends StatelessWidget {
  const _CashSection({
    required this.controller,
    required this.quickAmounts,
    required this.change,
    required this.errorText,
    required this.onAmountSelected,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<int> quickAmounts;
  final Money? change;
  final String? errorText;
  final ValueChanged<int> onAmountSelected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TindaTextInput(
          label: localizations.checkoutTenderedLabel,
          controller: controller,
          errorText: errorText,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            for (var index = 0; index < quickAmounts.length; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: AppSizes.touchTargetMin,
                  child: OutlinedButton(
                    onPressed: () => onAmountSelected(quickAmounts[index]),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: palette.surface,
                      foregroundColor: palette.text,
                      side: BorderSide(color: palette.borderStrong, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppRadii.smallButton,
                        ),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₱${quickAmounts[index]}',
                        maxLines: 1,
                        style: AppTypography.meta(
                          palette.text,
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        AnimatedSwitcher(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
          ),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: (change != null && !change!.isNegative)
              ? Padding(
                  key: ValueKey<int>(change!.minorUnits),
                  padding: const EdgeInsets.only(top: AppSpacing.s12),
                  child: Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s14,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadii.input),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations.checkoutChangeLabel,
                          style: AppTypography.bodyStrong(palette.text),
                        ),
                        Text(
                          formatMoney(change!),
                          style: AppTypography.title(palette.primary),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _EwalletSection extends StatelessWidget {
  const _EwalletSection({
    required this.controller,
    required this.errorText,
  });

  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TindaTextInput(
          label: localizations.checkoutEwalletRefLabel,
          hintText: localizations.checkoutEwalletRefHint,
          controller: controller,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: palette.onAccentSoft,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  localizations.checkoutEwalletReminder,
                  style: AppTypography.meta(palette.onAccentSoft, size: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UtangSection extends ConsumerStatefulWidget {
  const _UtangSection({
    required this.selectedCustomerId,
    required this.errorText,
    required this.onSelectCustomer,
  });

  final String? selectedCustomerId;
  final String? errorText;
  final ValueChanged<String> onSelectCustomer;

  @override
  ConsumerState<_UtangSection> createState() => _UtangSectionState();
}

class _UtangSectionState extends ConsumerState<_UtangSection> {
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

  bool _isNearOrOverCreditLimit(CustomerBalance? selectedBalance) {
    if (selectedBalance == null) return false;
    final creditLimit = selectedBalance.customer.creditLimit;
    if (!selectedBalance.balance.isPositive || creditLimit == null) {
      return false;
    }
    return selectedBalance.balance.minorUnits * 100 >=
        creditLimit.minorUnits * 80;
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
                final nameMatch =
                    item.customer.name.toLowerCase().contains(query);
                final phoneMatch =
                    item.customer.phone?.toLowerCase().contains(query) ?? false;
                return nameMatch || phoneMatch;
              }).toList();
        final selectedCustomer = _findSelectedCustomer(customers);
        final showCreditLimitWarning =
            _isNearOrOverCreditLimit(selectedCustomer);

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
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(UtangPaySheet.showNewSuki(context));
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
                title: 'Utang near credit limit',
                body:
                    '${selectedCustomer!.customer.name} already has '
                    '${formatMoney(selectedCustomer.balance)} unpaid utang '
                    '(credit limit: '
                    '${formatMoney(selectedCustomer.customer.creditLimit!)}).',
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
            const SizedBox(height: AppSpacing.s4),
            Text(
              localizations.checkoutUtangNote,
              style: AppTypography.meta(palette.textMuted, size: 13),
            ),
          ],
        );
      },
      ),
    );
  }
}
