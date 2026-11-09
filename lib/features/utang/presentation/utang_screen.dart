import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/unpaid_utang.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/repositories/utang_age_providers.dart';
import 'package:tinda360/data/repositories/utang_age_repository.dart';
import 'package:tinda360/features/utang/data/utang_csv_exporter.dart';
import 'package:tinda360/features/utang/presentation/suki_ledger_sheet.dart';
import 'package:tinda360/features/utang/presentation/utang_balances_provider.dart';
import 'package:tinda360/features/utang/presentation/utang_pay_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/csv_preview_sheet.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

Money computeTotalUtang(
  List<CustomerBalance> balances,
  Currency currency,
) => totalUnpaidUtang(balances, currency: currency);

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

class UtangScreen extends ConsumerStatefulWidget {
  const new({
    required this.onOpenSettings,
    required this.onOpenAiChat,
    super.key,
  });

  final VoidCallback onOpenSettings;

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

  Future<void> _exportUtangCsv(List<CustomerBalance> balances) async {
    unawaited(HapticFeedback.lightImpact());
    final localizations = AppLocalizations.of(context);
    final appLog = ref.read(appLogProvider);
    final clock = ref.read(clockProvider);
    try {
      final ledgerByCustomer = await ref
          .read(utangAgeRepositoryProvider)
          .loadLedgerByCustomer();
      final csvContent = exportUtangCsv(
        balances: balances,
        ledgerByCustomer: ledgerByCustomer,
        now: clock.now(),
      );
      final parsed = parseCsvForPreview(csvContent);
      if (!mounted) return;
      await CsvPreviewSheet.show(
        context,
        title: localizations.utangExportCsv,
        headers: parsed.headers,
        rows: parsed.rows,
        fileName: 'tinda360_utang.csv',
        csvContent: csvContent,
        successMessage: localizations.reportsExportCsvSuccess,
      );
    } on Exception catch (error, stackTrace) {
      appLog.error('utang_export_csv_failed', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.reportsExportCsvError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final currency = ref.watch(storeCurrencyProvider);
    final ageDaysByCustomer = ref.watch(utangAgeDaysProvider).value;
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
                onExportCsv: () => unawaited(_exportUtangCsv(balances)),
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
                child: TindaScreenBody(
                  child: _buildBody(
                    context: context,
                    localizations: localizations,
                    palette: palette,
                    balancesAsync: balancesAsync,
                    filtered: filtered,
                    ageDaysByCustomer: ageDaysByCustomer,
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
    required Map<String, int>? ageDaysByCustomer,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget content;
    if (balancesAsync.isLoading && !balancesAsync.hasValue) {
      content = const Padding(
        key: ValueKey('utang-loading'),
        padding: EdgeInsets.all(AppSpacing.s16),
        child: TindaListSkeleton(),
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
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenHorizontal,
          AppSpacing.s4,
          AppSpacing.screenHorizontal,
          TindaScreenBody.floatingBottomPadding(context),
        ),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s10),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final card = _SukiBalanceCard(
            balance: item,
            ageDays: !item.owes || ageDaysByCustomer == null
                ? null
                : ageDaysByCustomer[item.customer.id],
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
  const new({
    required this.totalUtang,
    required this.sukiCount,
    required this.onOpenSettings,
    required this.onExportCsv,
  });

  final Money totalUtang;
  final int sukiCount;
  final VoidCallback onOpenSettings;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return TindaHeaderBar(
      title: Text(localizations.utangTitle),
      actions: [
        TindaIconButton(
          icon: Icons.file_download_outlined,
          tooltip: localizations.utangExportCsv,
          onPressed: onExportCsv,
          onHeader: true,
        ),
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
              MoneyText(
                totalUtang,
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
  const new({
    required this.balance,
    required this.ageDays,
    required this.onTap,
    required this.onPay,
  });

  final CustomerBalance balance;
  final int? ageDays;
  final VoidCallback onTap;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
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
                      MoneyText(
                        balance.balance,
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
                      if (ageDays != null && ageDays! >= 1)
                        Text(
                          localizations.utangAgeDays(ageDays!),
                          key: ValueKey('utang-age-${customer.id}'),
                          style: AppTypography.meta(
                            ageDays! >= utangOverdueDays
                                ? palette.danger
                                : palette.textMuted,
                            weight: ageDays! >= utangOverdueDays
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
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
  const new({required this.label, required this.onPressed});

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
