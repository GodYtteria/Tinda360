import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/utang/presentation/suki_ledger_sheet.dart';
import 'package:tinda360/features/utang/presentation/utang_pay_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Live stream of customer utang balances ordered by debt descending.
final utangBalancesProvider =
    StreamProvider.autoDispose<List<CustomerBalance>>(
      (ref) => ref.watch(customerRepositoryProvider).watchBalances(),
    );

/// Computes total outstanding utang across [balances].
Money computeTotalUtang(
  List<CustomerBalance> balances,
  Currency currency,
) => balances.fold(
  Money.zero(currency),
  (runningTotal, item) => runningTotal + item.balance,
);

/// Filters [balances] by [query] against customer name or mobile number.
List<CustomerBalance> filterUtangBalances(
  List<CustomerBalance> balances,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return balances;
  return balances.where((item) {
    final nameMatch = item.customer.name.toLowerCase().contains(normalized);
    final phone = item.customer.phone ?? '';
    final phoneMatch = phone.toLowerCase().contains(normalized);
    return nameMatch || phoneMatch;
  }).toList();
}

/// Utang tab showing total debt, suki balances, search, and quick actions.
class UtangScreen extends ConsumerStatefulWidget {
  /// Creates the utang screen.
  const UtangScreen({
    required this.onOpenSettings,
    required this.onOpenAiChat,
    super.key,
  });

  /// Callback to open settings.
  final VoidCallback onOpenSettings;

  /// Callback to open Tinda AI chat.
  final VoidCallback onOpenAiChat;

  @override
  ConsumerState<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends ConsumerState<UtangScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final palette = AppPalette.of(context);
    final currency = ref.watch(storeCurrencyProvider);
    final balancesAsync = ref.watch(utangBalancesProvider);
    final balances = balancesAsync.value ?? const <CustomerBalance>[];
    final totalUtang = computeTotalUtang(balances, currency);
    final filtered = filterUtangBalances(balances, _searchQuery);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          Column(
            children: [
              _UtangHeader(
                totalUtang: totalUtang,
                sukiCount: balances.length,
                onOpenSettings: widget.onOpenSettings,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.s16,
                  AppSpacing.screenHorizontal,
                  AppSpacing.s12,
                ),
                child: TindaSearchField(
                  controller: _searchController,
                  hintText: localizations.utangSearchHint,
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _buildBody(
                      context: context,
                      localizations: localizations,
                      palette: palette,
                      balancesAsync: balancesAsync,
                      filtered: filtered,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildBottomActions(context, localizations, palette),
        ],
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AppLocalizations localizations,
    required AppPalette palette,
    required AsyncValue<List<CustomerBalance>> balancesAsync,
    required List<CustomerBalance> filtered,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget content;
    if (balancesAsync.isLoading && !balancesAsync.hasValue) {
      content = Center(
        key: const ValueKey('utang-loading'),
        child: CircularProgressIndicator(color: palette.primary),
      );
    } else if (balancesAsync.hasError && !balancesAsync.hasValue) {
      content = TindaEmptyState(
        key: const ValueKey('utang-error'),
        icon: Icons.error_outline_rounded,
        title: localizations.homeLoadFailed,
        body: localizations.utangEmptyBody,
        action: TindaSecondaryButton(
          label: localizations.commonRetry,
          onPressed: () => ref.invalidate(utangBalancesProvider),
        ),
      );
    } else if (filtered.isEmpty) {
      content = TindaEmptyState(
        key: const ValueKey('utang-empty'),
        icon: Icons.account_balance_wallet_outlined,
        title: localizations.utangEmptyTitle,
        body: localizations.utangEmptyBody,
      );
    } else {
      content = ListView.separated(
        key: ValueKey('utang-list-${filtered.length}'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenHorizontal,
          AppSpacing.s4,
          AppSpacing.screenHorizontal,
          96,
        ),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s10),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final card = _SukiBalanceCard(
            balance: item,
            onTap: () => SukiLedgerSheet.show(
              context,
              balance: item,
              onPay: () {
                Navigator.of(context).pop();
                unawaited(UtangPaySheet.showPay(context, item));
              },
            ),
            onPay: () => UtangPaySheet.showPay(context, item),
          );
          if (reduceMotion) return card;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 180 + (index.clamp(0, 8) * 20)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 8),
                child: child,
              ),
            ),
            child: card,
          );
        },
      );
    }
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 0 : 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: content,
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    AppLocalizations localizations,
    AppPalette palette,
  ) => Positioned.fill(
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          AppSpacing.s16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _AddSukiPillButton(
              label: localizations.utangAddSuki,
              onPressed: () => UtangPaySheet.showNewSuki(context),
            ),
            TindaAiFab(
              onPressed: widget.onOpenAiChat,
              tooltip: localizations.chatOpenTindaAi,
            ),
          ],
        ),
      ),
    ),
  );
}

class _UtangHeader extends StatelessWidget {
  const _UtangHeader({
    required this.totalUtang,
    required this.sukiCount,
    required this.onOpenSettings,
  });

  final Money totalUtang;
  final int sukiCount;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final palette = AppPalette.of(context);
    return TindaHeaderBar(
      title: Text(localizations.utangTitle),
      actions: [
        TindaIconButton(
          svgAsset: 'assets/icons/settings.svg',
          tooltip: localizations.posOpenSettings,
          onPressed: onOpenSettings,
          onHeader: true,
        ),
      ],
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localizations.utangTotalLabel,
            style: AppTypography.meta(
              palette.onHeader.withValues(alpha: 0.85),
              size: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s4,
            children: [
              Text(
                formatMoney(totalUtang),
                style: AppTypography.display(palette.onHeader),
              ),
              Text(
                localizations.utangSukiCount(sukiCount),
                style: AppTypography.meta(
                  palette.onHeader.withValues(alpha: 0.9),
                  size: 13,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SukiBalanceCard extends StatelessWidget {
  const _SukiBalanceCard({
    required this.balance,
    required this.onTap,
    required this.onPay,
  });

  final CustomerBalance balance;
  final VoidCallback onTap;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final palette = AppPalette.of(context);
    final customer = balance.customer;
    return TindaCard(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    customer.name,
                    style: AppTypography.bodyStrong(palette.text),
                  ),
                  if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      customer.phone!,
                      style: AppTypography.meta(palette.textMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatMoney(balance.balance),
                        style: AppTypography.bodyStrong(
                          balance.owes ? palette.danger : palette.textMuted,
                          size: 16,
                          weight: FontWeight.w700,
                        ),
                      ),
                      TindaBadge(
                        label: localizations.utangBalanceLabel,
                        isDanger: balance.owes,
                      ),
                      if (balance.isOverLimit)
                        TindaBadge(
                          label: localizations.utangOverLimit,
                          isDanger: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            TindaAccentButton(
              label: localizations.utangPayButton,
              onPressed: balance.owes ? onPay : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSukiPillButton extends StatelessWidget {
  const _AddSukiPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTargetMin),
        child: Material(
          color: palette.primary,
          shape: const StadiumBorder(),
          elevation: 4,
          shadowColor: palette.primary.withValues(alpha: 0.3),
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s18,
                vertical: AppSpacing.s12,
              ),
              child: Text(
                label,
                style: AppTypography.bodyStrong(
                  palette.onPrimary,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
