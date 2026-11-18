part of 'ulat_screen.dart';

class _RecentSalesSection extends ConsumerWidget {
  const _RecentSalesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final salesAsync = ref.watch(ulatRecentSalesProvider);
    final sales = salesAsync.value ?? const <SaleRecord>[];
    ref.watch(_ulatStoreProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.ulatRecentSales,
          style: AppTypography.meta(
            palette.textMuted,
            size: 13,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        AnimatedSwitcher(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
          ),
          child: sales.isEmpty
              ? TindaCard(
                  key: const ValueKey('recent-empty'),
                  child: Text(
                    localizations.ulatNoRecentSales,
                    style: AppTypography.body(palette.textMuted),
                  ),
                )
              : Column(
                  key: ValueKey<int>(sales.length),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < sales.length; index++) ...[
                      _AnimatedListEntry(
                        index: index,
                        child: TindaCard(
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            _showSaleDetailSheet(context, ref, sales[index]);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: TindaBadge(
                                            label: localizedPaymentMethod(
                                              localizations,
                                              sales[index].method,
                                            ),
                                            isDanger:
                                                sales[index].method ==
                                                PaymentMethod.utang,
                                          ),
                                        ),
                                        if (sales[index].customerName !=
                                            null) ...[
                                          const SizedBox(width: AppSpacing.s8),
                                          Expanded(
                                            child: Text(
                                              sales[index].customerName!,
                                              style: AppTypography.meta(
                                                palette.textMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.s4),
                                    Text(
                                      '${DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(sales[index].createdAtMs).toLocal())} · '
                                      '${localizations.ulatSaleItemsCount(sales[index].lines.length)}',
                                      style: AppTypography.meta(
                                        palette.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Flexible(
                                child: MoneyText(
                                  sales[index].total,
                                  alignment: AlignmentDirectional.centerEnd,
                                  style: AppTypography.bodyStrong(palette.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index < sales.length - 1)
                        const SizedBox(height: AppSpacing.s8),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  void _showSaleDetailSheet(
    BuildContext context,
    WidgetRef ref,
    SaleRecord sale,
  ) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: palette.scrim,
        builder: (sheetContext) => TindaBottomSheet(
          title: localizations.ulatSaleDetailTitle,
          closeTooltip: localizations.commonClose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in sale.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.productName} × '
                          '${formatQuantity(line.quantity, line.unit)} '
                          '${localizedUnit(localizations, line.unit)}',
                          style: AppTypography.body(palette.text),
                        ),
                      ),
                      Text(
                        formatMoney(line.lineTotal),
                        style: AppTypography.bodyStrong(palette.text),
                      ),
                    ],
                  ),
                ),
              Divider(color: palette.border),
              const SizedBox(height: AppSpacing.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      localizations.ulatSaleTotalLabel,
                      style: AppTypography.bodyStrong(palette.text),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: MoneyText(
                      sale.total,
                      alignment: AlignmentDirectional.centerEnd,
                      style: AppTypography.title(palette.primary),
                    ),
                  ),
                ],
              ),
              if (sale.refunded.isPositive) ...[
                _SaleDetailAmountRow(
                  label: localizations.receiptRefunded,
                  amount: Money(
                    -sale.refunded.minorUnits,
                    sale.refunded.currency,
                  ),
                ),
                _SaleDetailAmountRow(
                  label: localizations.receiptNetTotal,
                  amount: sale.netTotal,
                ),
              ],
              _SaleDetailAmountRow(
                label: localizations.ulatSalePaidLabel,
                amount: sale.received,
              ),
              if (sale.change.isPositive)
                _SaleDetailAmountRow(
                  label: localizations.receiptChange,
                  amount: sale.change,
                ),
              if (sale.paid < sale.total)
                _SaleDetailAmountRow(
                  label: localizations.receiptUtang,
                  amount: sale.total - sale.paid + sale.interest,
                ),
              if (sale.paid < sale.total && sale.interest.isPositive)
                _SaleDetailAmountRow(
                  label: localizations.receiptInterest,
                  amount: sale.interest,
                ),
              if (sale.cashierName != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '${localizations.receiptBantayLabel}: ${sale.cashierName}',
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
              if (sale.ewalletReference != null &&
                  sale.ewalletReference!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '${localizations.ulatSaleReferenceLabel}: '
                  '${sale.ewalletReference}',
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              TindaSecondaryButton(
                label: localizations.receiptPrint58mm,
                icon: Icons.print_outlined,
                onPressed: () {
                  unawaited(HapticFeedback.lightImpact());
                  final storeProfile = ref
                      .read(_ulatStoreProfileProvider)
                      .asData
                      ?.value;
                  final storeName = storeProfile?.name ?? '';
                  unawaited(
                    ReceiptPreviewSheet.show(
                      sheetContext,
                      storeName: storeName.trim().isEmpty
                          ? localizations.appTitle
                          : storeName,
                      lines: [
                        for (final line in sale.lines)
                          '${line.productName} x${formatQuantity(line.quantity, line.unit)} '
                              '${localizedUnit(localizations, line.unit)} = ${formatMoney(line.lineTotal)}',
                      ],
                      total: sale.total,
                      paid: sale.received,
                      change: sale.change,
                      paymentLabel: localizedPaymentMethod(
                        localizations,
                        sale.method,
                      ),
                      timestamp: DateTime.fromMillisecondsSinceEpoch(
                        sale.createdAtMs,
                      ).toLocal(),
                      details: ReceiptDetails(
                        receiptNumber: sale.receiptNumber,
                        customerName: sale.customerName,
                        ewalletReference: sale.ewalletReference,
                        interest: sale.interest,
                        refunded: sale.refunded,
                        cashierName: sale.cashierName,
                        storeAddress: storeProfile?.address,
                        storePhone: storeProfile?.phone,
                      ),
                    ),
                  );
                },
              ),
              if (sale.lines.any(
                (line) => line.returnableQuantity.isPositive,
              )) ...[
                const SizedBox(height: AppSpacing.s8),
                TindaSecondaryButton(
                  label: localizations.ulatReturnTitle,
                  icon: Icons.assignment_return_outlined,
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    Navigator.of(sheetContext).pop();
                    unawaited(showSaleReturnSheet(context, sale: sale));
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.s8),
              TindaTextLinkButton(
                label: localizations.ulatVoidSaleButton,
                isDanger: true,
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  unawaited(_confirmVoidSale(sheetContext, context, ref, sale));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmVoidSale(
    BuildContext sheetContext,
    BuildContext parentContext,
    WidgetRef ref,
    SaleRecord sale,
  ) async {
    final localizations = AppLocalizations.of(parentContext);
    final messenger = ScaffoldMessenger.of(parentContext);
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.ulatVoidSaleConfirmTitle),
        content: Text(localizations.ulatVoidSaleConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.ulatVoidSaleButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !sheetContext.mounted) return;
    final verified = await confirmStorePinIfSet(
      sheetContext,
      ref,
      title: localizations.settingsPinPromptTitle,
    );
    if (!verified) return;
    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    final result = await ref.read(saleRepositoryProvider).voidSale(sale.id);
    final message = switch (result) {
      Ok() => localizations.ulatVoidSaleSuccess,
      Err(:final failure) => localizedFailureMessage(localizations, failure),
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SaleDetailAmountRow extends StatelessWidget {
  const _SaleDetailAmountRow({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: AppTypography.meta(palette.textMuted)),
          ),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: MoneyText(
              amount,
              alignment: AlignmentDirectional.centerEnd,
              style: AppTypography.meta(palette.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
