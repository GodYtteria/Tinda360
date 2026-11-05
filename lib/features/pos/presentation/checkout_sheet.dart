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
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/pos/presentation/cart_price_override_provider.dart';
import 'package:tinda360/features/pos/presentation/cash_quick_amounts_row.dart';
import 'package:tinda360/features/pos/presentation/cart_quantity_dialog.dart';
import 'package:tinda360/features/pos/presentation/checkout_credit_limit.dart';
import 'package:tinda360/features/pos/presentation/checkout_interest.dart';
import 'package:tinda360/features/pos/presentation/checkout_interest_field.dart';
import 'package:tinda360/features/pos/presentation/checkout_items_card.dart';
import 'package:tinda360/features/pos/presentation/checkout_price_dialog.dart';
import 'package:tinda360/features/pos/presentation/checkout_shortfall.dart';
import 'package:tinda360/features/pos/presentation/checkout_suki_picker.dart';
import 'package:tinda360/features/pos/presentation/checkout_utang_pricing.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';
import 'package:tinda360/features/pos/presentation/pos_screen.dart';
import 'package:tinda360/features/pos/presentation/sale_done_sheet.dart';
import 'package:tinda360/features/pos/presentation/receipt_preview_sheet.dart';
import 'package:tinda360/features/settings/presentation/settings_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/bantay_name_store.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

bool addToCartOrWarn(
  BuildContext context,
  PosCartNotifier cartNotifier,
  StockedProduct item,
) {
  if (cartNotifier.increment(item.product.id, available: item.sellCap)) {
    return true;
  }
  unawaited(HapticFeedback.heavyImpact());
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).posOutOfStock(item.product.name),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  return false;
}

final checkoutCustomersProvider =
    StreamProvider.autoDispose<List<CustomerBalance>>(
      (ref) => ref.watch(customerRepositoryProvider).watchBalances(),
    );

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({
    required this.products,
    required this.cart,
    super.key,
  });

  final List<StockedProduct> products;

  final Map<String, Quantity> cart;

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  final TextEditingController _tenderedController = TextEditingController();
  final TextEditingController _ewalletRefController = TextEditingController();
  final TextEditingController _paidNowController = TextEditingController();

  final TextEditingController _interestController = TextEditingController();

  InterestInputMode _interestMode = InterestInputMode.percent;
  PaymentMethod _method = PaymentMethod.cash;
  String? _selectedCustomerId;
  String? _inlineError;
  bool _isSubmitting = false;
  ({String customerId, Money projectedBalance})? _creditLimitApproval;

  CreditLimitDecision? _creditLimitDecision({
    required Money? saleUtang,
    required Money saleInterest,
    required bool usesCustomer,
  }) {
    final customerId = _selectedCustomerId;
    if (!usesCustomer || customerId == null || saleUtang == null) return null;
    final customers = ref.watch(checkoutCustomersProvider).asData?.value;
    for (final item in customers ?? const <CustomerBalance>[]) {
      if (item.customer.id != customerId) continue;
      final unapproved = decideCreditLimit(
        currentBalance: item.balance,
        creditLimit: item.customer.creditLimit,
        saleUtang: saleUtang,
        saleInterest: saleInterest,
        ownerApproved: false,
      );
      final approval = _creditLimitApproval;
      final isApproved =
          approval != null &&
          approval.customerId == customerId &&
          approval.projectedBalance == unapproved.projectedBalance;
      return isApproved
          ? decideCreditLimit(
              currentBalance: item.balance,
              creditLimit: item.customer.creditLimit,
              saleUtang: saleUtang,
              saleInterest: saleInterest,
              ownerApproved: true,
            )
          : unapproved;
    }
    return null;
  }

  Future<void> _requestCreditLimitApproval(
    CreditLimitDecision decision,
  ) async {
    final customerId = _selectedCustomerId;
    if (customerId == null) return;
    final approved = await confirmStorePinIfSet(
      context,
      ref,
      title: AppLocalizations.of(context).settingsPinPromptTitle,
    );
    if (!approved || !mounted) return;
    setState(
      () => _creditLimitApproval = (
        customerId: customerId,
        projectedBalance: decision.projectedBalance,
      ),
    );
  }

  @override
  void dispose() {
    _tenderedController.dispose();
    _ewalletRefController.dispose();
    _paidNowController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Money? _parsedTendered(Currency currency) =>
      parseMoneyInput(_tenderedController.text, currency);

  Money? _parsedPaidNow(Currency currency) {
    if (_method != PaymentMethod.utang) return null;
    final rawText = _paidNowController.text.trim();
    if (rawText.isEmpty) return Money.zero(currency);
    return parseMoneyInput(rawText, currency);
  }

  InterestResolution _interestResolution(Currency currency, Money? base) =>
      resolveCheckoutInterest(
        text: _interestController.text,
        mode: _interestMode,
        utangAmount: base,
        currency: currency,
      );

  void _selectCustomer(String customerId) {
    unawaited(HapticFeedback.selectionClick());
    final customers = ref.read(checkoutCustomersProvider).asData?.value;
    int? rateTenths;
    for (final item in customers ?? const <CustomerBalance>[]) {
      if (item.customer.id == customerId) {
        rateTenths = item.customer.interestPercentTenths;
      }
    }
    setState(() {
      _selectedCustomerId = customerId;
      _interestMode = InterestInputMode.percent;
      _interestController.text = interestPrefillText(rateTenths);
      _inlineError = null;
    });
  }

  Future<void> _editLinePrice(CheckoutLine line) async {
    final overrides = ref.read(cartPriceOverrideProvider.notifier);
    final choice = await showLinePriceDialog(
      context,
      productName: line.stocked.product.name,
      normalPrice: line.stocked.product.price,
      currentOverride: line.unitPriceOverride,
    );
    if (choice == null) return;
    final price = choice.price;
    if (price == null) {
      overrides.resetPrice(line.stocked.product.id);
      return;
    }
    if (price == line.stocked.product.price) {
      overrides.resetPrice(line.stocked.product.id);
      return;
    }
    overrides.setPrice(line.stocked.product.id, price);
  }

  Future<void> _submitSale(
    List<CheckoutLine> lines,
    Money total,
    Money? shortfall,
  ) async {
    if (_isSubmitting) return;
    final currency = ref.read(storeCurrencyProvider);
    final tendered = _parsedTendered(currency);
    final paidNow = _parsedPaidNow(currency);
    if (_method == PaymentMethod.utang && paidNow == null) {
      setState(
        () => _inlineError = AppLocalizations.of(
          context,
        ).checkoutPaidNowInvalid,
      );
      return;
    }
    final ewalletRef = _ewalletRefController.text.trim();
    final shortfallCustomerId = _selectedCustomerId;
    if (shortfall != null &&
        !canRecordCashShortfall(
          shortfall: shortfall,
          customerId: shortfallCustomerId,
        )) {
      return;
    }
    final interestBase = interestBaseAmount(
      method: _method,
      total: total,
      paidNow: paidNow,
      cashShortfall: shortfall,
    );
    final interestResolution = _interestResolution(currency, interestBase);
    if (interestBase != null && interestResolution.error != null) return;
    final interest = interestBase == null ? null : interestResolution.interest;
    final lineDrafts = [
      for (final line in lines)
        SaleLineDraft(
          productId: line.stocked.product.id,
          quantity: line.quantity,
          unitPriceOverride: line.saleUnitPriceOverride,
        ),
    ];
    final cashierName = ref.read(bantayNameProvider).value;
    final regularDraft = SaleDraft(
      method: _method,
      cashierName: cashierName,
      paidNow: paidNow,
      interest: _method == PaymentMethod.utang ? interest : null,
      lines: lineDrafts,
      cashTendered: _method == PaymentMethod.cash ? tendered : null,
      customerId: _method == PaymentMethod.utang ? _selectedCustomerId : null,
      ewalletReference:
          _method == PaymentMethod.ewallet && ewalletRef.isNotEmpty
          ? ewalletRef
          : null,
    );
    final draft = shortfall == null
        ? regularDraft
        : buildCashShortfallDraft(
            lines: lineDrafts,
            cashReceived: tendered!,
            customerId: shortfallCustomerId!,
            interest: interest,
            cashierName: cashierName,
          );
    final soldMethod = draft.method;

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });
    final cartNotifier = ref.read(posCartProvider.notifier);
    final overrides = ref.read(cartPriceOverrideProvider.notifier);
    final saleRepository = ref.read(saleRepositoryProvider);
    final customers = ref.read(checkoutCustomersProvider).asData?.value;
    final result = await saleRepository.record(draft);
    String? receiptNumber;
    if (result is Ok<String, SaleFailure>) {
      cartNotifier.clear();
      overrides.clear();
      receiptNumber = await saleRepository.receiptNumberOf(result.value);
    }
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    switch (result) {
      case Ok<String, SaleFailure>():
        _handleSaleSuccess(
          lines,
          total,
          method: soldMethod,
          paid: switch (soldMethod) {
            PaymentMethod.cash => tendered ?? total,
            PaymentMethod.ewallet => total,
            PaymentMethod.utang =>
              shortfall != null ? tendered! : paidNow ?? Money.zero(currency),
          },
          details: ReceiptDetails(
            receiptNumber: receiptNumber,
            customerName: soldMethod == PaymentMethod.utang
                ? _customerNameFor(customers)
                : null,
            interest: draft.interest,
            ewalletReference:
                _method == PaymentMethod.ewallet && ewalletRef.isNotEmpty
                ? ewalletRef
                : null,
          ),
          currency: currency,
        );
      case Err<String, SaleFailure>(:final failure):
        setState(() {
          _isSubmitting = false;
          _inlineError = localizedFailureMessage(localizations, failure);
        });
    }
  }

  String? _customerNameFor(List<CustomerBalance>? customers) {
    if (customers == null) return null;
    for (final item in customers) {
      if (item.customer.id == _selectedCustomerId) return item.customer.name;
    }
    return null;
  }

  void _handleSaleSuccess(
    List<CheckoutLine> lines,
    Money total, {
    required PaymentMethod method,
    required Money paid,
    required ReceiptDetails details,
    required Currency currency,
  }) {
    final localizations = AppLocalizations.of(context);
    final change = method == PaymentMethod.cash
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
          paymentMethod: method,
          storeName: storeName,
          timestamp: timestamp,
          details: details,
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
    final products = ref.watch(posProductsProvider).value ?? widget.products;
    final overrides = ref.watch(cartPriceOverrideProvider);
    final tendered = _parsedTendered(currency);
    final cashTotal = sumCheckoutLines(
      resolveCheckoutLines(
        cart: cart,
        products: products,
        manualOverrides: overrides,
        useUtangPrices: false,
      ),
      currency,
    );
    final utangTotal = sumCheckoutLines(
      resolveCheckoutLines(
        cart: cart,
        products: products,
        manualOverrides: overrides,
        useUtangPrices: true,
      ),
      currency,
    );
    final shortfall = resolveCashShortfall(
      method: _method,
      cashTotal: cashTotal,
      utangTotal: utangTotal,
      cashReceived: tendered,
    );
    final lines = resolveCheckoutLines(
      cart: cart,
      products: products,
      manualOverrides: overrides,
      useUtangPrices: usesUtangPrices(
        method: _method,
        cashShortfallDetected: shortfall != null,
        customerSelected: _selectedCustomerId != null,
      ),
    );
    final total = sumCheckoutLines(lines, currency);
    final paidNow = _parsedPaidNow(currency);
    final utangRemaining =
        (paidNow == null || paidNow.isNegative || paidNow > total)
        ? null
        : total - paidNow;
    final change = tendered == null
        ? null
        : SaleMath.changeDue(total: total, tendered: tendered);
    final interestBase = interestBaseAmount(
      method: _method,
      total: total,
      paidNow: paidNow,
      cashShortfall: shortfall,
    );
    final interestResolution = _interestResolution(currency, interestBase);
    final interestField = interestBase == null
        ? null
        : (shortfall != null && _selectedCustomerId == null)
        ? null
        : CheckoutInterestField(
            controller: _interestController,
            mode: _interestMode,
            onModeChanged: (mode) {
              unawaited(HapticFeedback.selectionClick());
              setState(() => _interestMode = mode);
            },
            onChanged: (_) => setState(() => _inlineError = null),
            resolution: interestResolution,
            preview: interestPreviewAmounts(
              utangAmount: interestBase,
              interest: interestResolution.interest,
            ),
          );

    final creditDecision = _creditLimitDecision(
      saleUtang: interestBase,
      saleInterest: interestResolution.error == null
          ? interestResolution.interest ?? Money.zero(currency)
          : Money.zero(currency),
      usesCustomer: _method == PaymentMethod.utang || shortfall != null,
    );
    final isCreditBlocked = creditDecision?.isBlocked ?? false;

    return PopScope(
      canPop: !_isSubmitting,
      child: TindaBottomSheet(
        title: localizations.checkoutTitle,
        closeTooltip: localizations.commonClose,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isCreditBlocked) ...[
              Text(
                localizations.checkoutCreditLimitExceeded(
                  formatMoney(creditDecision!.creditLimit!),
                ),
                key: const ValueKey('checkout-credit-limit-blocked'),
                style: AppTypography.body(palette.danger),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
            TindaPrimaryButton(
              label: isCreditBlocked
                  ? localizations.checkoutCreditLimitOverride
                  : (_method == PaymentMethod.utang || shortfall != null)
                  ? localizations.checkoutRecordUtang
                  : localizations.checkoutFinishSale,
              isLoading: _isSubmitting,
              onPressed:
                  (_isSubmitting ||
                      lines.isEmpty ||
                      (shortfall != null &&
                          !canRecordCashShortfall(
                            shortfall: shortfall,
                            customerId: _selectedCustomerId,
                          )) ||
                      (interestBase != null &&
                          interestResolution.error != null))
                  ? null
                  : isCreditBlocked
                  ? () =>
                        unawaited(_requestCreditLimitApproval(creditDecision!))
                  : () => _submitSale(lines, total, shortfall),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckoutItemsCard(
              lines: lines,
              total: total,
              onDecrement: cartNotifier.decrement,
              onIncrement: (stocked) =>
                  addToCartOrWarn(context, cartNotifier, stocked),
              onEditPrice: (line) => unawaited(_editLinePrice(line)),
              onEditQuantity: (line) => unawaited(
                askAndSetCartQuantity(
                  context,
                  cartNotifier: cartNotifier,
                  stocked: line.stocked,
                  currentQuantity: line.quantity,
                  unitPrice: line.effectiveUnitPrice,
                ),
              ),
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
                        total: total,
                        change: change,
                        errorText: _inlineError,
                        shortfallSection: shortfall == null
                            ? null
                            : _ShortfallSection(
                                shortfall: shortfall,
                                selectedCustomerId: _selectedCustomerId,
                                onSelectCustomer: _selectCustomer,
                                interestField: interestField,
                              ),
                        onAmountSelected: (amount) {
                          unawaited(HapticFeedback.lightImpact());
                          _tenderedController.text = amount.toString();
                          setState(() => _inlineError = null);
                        },
                        onExactSelected: (exactText) {
                          unawaited(HapticFeedback.lightImpact());
                          _tenderedController.text = exactText;
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
                        paidNowController: _paidNowController,
                        utangRemaining: utangRemaining,
                        onPaidNowChanged: (_) =>
                            setState(() => _inlineError = null),
                        onSelectCustomer: _selectCustomer,
                        interestField: interestField,
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
      ),
    );
  }
}

class _CashSection extends StatelessWidget {
  const _CashSection({
    required this.controller,
    required this.total,
    required this.change,
    required this.errorText,
    required this.shortfallSection,
    required this.onAmountSelected,
    required this.onExactSelected,
    required this.onChanged,
  });

  final TextEditingController controller;
  final Money total;
  final Money? change;
  final String? errorText;
  final Widget? shortfallSection;
  final ValueChanged<int> onAmountSelected;
  final ValueChanged<String> onExactSelected;
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
        CashQuickAmountsRow(
          total: total,
          onAmountSelected: onAmountSelected,
          onExactSelected: onExactSelected,
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
                        Flexible(
                          child: Text(
                            localizations.checkoutChangeLabel,
                            style: AppTypography.bodyStrong(palette.text),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: MoneyText(
                            change!,
                            alignment: AlignmentDirectional.centerEnd,
                            style: AppTypography.title(palette.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        ?shortfallSection,
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

class _UtangSection extends StatelessWidget {
  const _UtangSection({
    required this.selectedCustomerId,
    required this.errorText,
    required this.onSelectCustomer,
    required this.paidNowController,
    required this.utangRemaining,
    required this.onPaidNowChanged,
    required this.interestField,
  });

  final Widget? interestField;
  final String? selectedCustomerId;
  final String? errorText;
  final TextEditingController paidNowController;
  final Money? utangRemaining;
  final ValueChanged<String> onPaidNowChanged;
  final ValueChanged<String> onSelectCustomer;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return CheckoutSukiPicker(
      selectedCustomerId: selectedCustomerId,
      onSelectCustomer: onSelectCustomer,
      footer: [
        const SizedBox(height: AppSpacing.s4),
        TindaTextInput(
          label: localizations.checkoutPaidNowLabel,
          controller: paidNowController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: onPaidNowChanged,
        ),
        if (utangRemaining != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            localizations.checkoutPaidNowRemaining(
              formatMoney(utangRemaining!),
            ),
            style: AppTypography.bodyStrong(palette.text),
          ),
        ],
        if (interestField != null) ...[
          const SizedBox(height: AppSpacing.s12),
          interestField!,
        ],
        const SizedBox(height: AppSpacing.s8),
        Text(
          localizations.checkoutUtangNote,
          style: AppTypography.meta(palette.textMuted, size: 13),
        ),
      ],
    );
  }
}

class _ShortfallSection extends StatelessWidget {
  const _ShortfallSection({
    required this.shortfall,
    required this.selectedCustomerId,
    required this.onSelectCustomer,
    required this.interestField,
  });

  final Widget? interestField;
  final Money shortfall;
  final String? selectedCustomerId;
  final ValueChanged<String> onSelectCustomer;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        TindaCard(
          backgroundColor: palette.surfaceMuted,
          child: Text(
            localizations.checkoutShortfallPrompt(formatMoney(shortfall)),
            style: AppTypography.bodyStrong(palette.text),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        CheckoutSukiPicker(
          selectedCustomerId: selectedCustomerId,
          onSelectCustomer: onSelectCustomer,
          additionalUtang: shortfall,
        ),
        if (interestField != null) ...[
          const SizedBox(height: AppSpacing.s12),
          interestField!,
        ],
      ],
    );
  }
}
