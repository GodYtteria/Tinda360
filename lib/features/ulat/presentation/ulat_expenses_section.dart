part of 'ulat_screen.dart';

class _ExpensesSection extends ConsumerWidget {
  const _ExpensesSection({required this.grossProfit});

  final Money grossProfit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final expensesAsync = ref.watch(ulatExpensesProvider);
    final expensesLoaded = expensesAsync.hasValue;
    final expenses = expensesAsync.value ?? const <ExpenseEntry>[];
    final totalExpenses = expenses.fold(
      Money.zero(grossProfit.currency),
      (sum, entry) => sum + entry.amount,
    );
    final netIncome = grossProfit - totalExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                localizations.ulatExpensesTitle,
                style: AppTypography.meta(
                  palette.textMuted,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: () {
                  unawaited(HapticFeedback.lightImpact());
                  unawaited(_showAddExpenseDialog(context, ref));
                },
                child: Text(localizations.ulatAddExpenseButton),
              ),
            ),
          ],
        ),
        TindaCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  localizations.ulatNetIncomeLabel,
                  style: AppTypography.body(palette.textMuted),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: MoneyText.text(
                    expensesLoaded ? formatMoney(netIncome) : '—',
                    key: ValueKey(netIncome.minorUnits),
                    alignment: AlignmentDirectional.centerEnd,
                    style: AppTypography.title(
                      netIncome.isNegative ? palette.danger : palette.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        AnimatedSwitcher(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
          ),
          child: expenses.isEmpty
              ? TindaCard(
                  key: const ValueKey('expenses-empty'),
                  child: Text(
                    localizations.ulatNoExpenses,
                    style: AppTypography.body(palette.textMuted),
                  ),
                )
              : Column(
                  key: ValueKey<int>(expenses.length),
                  children: [
                    for (var index = 0; index < expenses.length; index++) ...[
                      _AnimatedListEntry(
                        index: index,
                        child: TindaCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  expenses[index].title,
                                  style: AppTypography.bodyStrong(palette.text),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Flexible(
                                child: MoneyText(
                                  expenses[index].amount,
                                  alignment: AlignmentDirectional.centerEnd,
                                  style: AppTypography.bodyStrong(
                                    palette.danger,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: localizations.commonDelete,
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: palette.textMuted,
                                ),
                                onPressed: () async {
                                  unawaited(HapticFeedback.selectionClick());
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final verified = await confirmStorePinIfSet(
                                    context,
                                    ref,
                                    title: localizations.settingsPinPromptTitle,
                                  );
                                  if (!verified) return;
                                  final deleted = await ref
                                      .read(expenseRepositoryProvider)
                                      .deleteExpense(expenses[index].id);
                                  if (!deleted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          localizations.ulatExpenseDeleteFailed,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index < expenses.length - 1)
                        const SizedBox(height: AppSpacing.s8),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showAddExpenseDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isFilipino = localizations.localeName.startsWith('fil');

    final saveRequest = await showDialog<({String title, Money amount})>(
      context: context,
      builder: (dialogContext) =>
          _AddExpenseDialog(currency: ref.read(storeCurrencyProvider)),
    );
    if (saveRequest == null) return;

    final result = await ref
        .read(expenseRepositoryProvider)
        .addExpense(
          title: saveRequest.title,
          amount: saveRequest.amount,
        );
    if (!context.mounted) return;
    switch (result) {
      case Ok<String, ExpenseFailure>():
        messenger.showSnackBar(
          SnackBar(
            content: Text(localizations.ulatExpenseSaved),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Err<String, ExpenseFailure>(:final failure):
        final errorMessage = switch (failure) {
          ExpenseTitleRequired() =>
            isFilipino
                ? 'Kailangan ang pangalan ng gastos.'
                : 'Expense name is required.',
          ExpenseAmountInvalid() =>
            isFilipino
                ? 'Hindi wasto ang halaga ng gastos.'
                : 'Expense amount is invalid.',
          ExpenseUnavailable() =>
            isFilipino
                ? 'Hindi ma-save ang gastos ngayon. Subukan ulit.'
                : 'Could not save expense. Please try again.',
        };
        messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog({required this.currency});

  final Currency currency;

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _clearValidation() {
    if (_validationMessage == null) return;
    setState(() => _validationMessage = null);
  }

  void _save() {
    final localizations = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final amount = parseMoneyInput(_amountController.text, widget.currency);
    if (title.isEmpty || amount == null || !amount.isPositive) {
      setState(() {
        _validationMessage = localizations.ulatExpenseInvalid;
      });
      return;
    }
    Navigator.of(context).pop((title: title, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(localizations.ulatAddExpenseButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_validationMessage case final message?) ...[
            Text(
              message,
              style: AppTypography.meta(
                AppPalette.of(context).danger,
                size: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: localizations.ulatExpenseTitleLabel,
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearValidation(),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: localizations.ulatExpenseAmountLabel,
            ),
            onChanged: (_) => _clearValidation(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.commonCancel),
        ),
        TextButton(
          onPressed: _save,
          child: Text(localizations.commonSave),
        ),
      ],
    );
  }
}
