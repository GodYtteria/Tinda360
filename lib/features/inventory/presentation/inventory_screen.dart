import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/inventory/data/product_csv_exporter.dart';
import 'package:tinda360/features/inventory/data/product_csv_importer.dart';
import 'package:tinda360/shared/widgets/csv_preview_sheet.dart';
import 'package:tinda360/features/inventory/presentation/inventory_rules.dart';
import 'package:tinda360/features/inventory/presentation/product_sheet.dart';
import 'package:tinda360/features/pos/presentation/pos_screen.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

final inventoryProductsProvider =
    StreamProvider.autoDispose<List<StockedProduct>>(
      (ref) => ref.watch(productRepositoryProvider).watchActive(),
    );

enum InventoryFilter { all, lowStock, expiring }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({
    required this.onOpenSettings,
    required this.onOpenAiChat,
    super.key,
  });

  final VoidCallback onOpenSettings;

  final VoidCallback onOpenAiChat;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  InventoryFilter _filter = InventoryFilter.all;

  LocalDay get _today => LocalDay.fromLocal(ref.read(clockProvider).now());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StockedProduct> _filterProducts(List<StockedProduct> products) {
    final query = _searchQuery.trim().toLowerCase();
    return products.where((item) {
      if (_filter == InventoryFilter.lowStock && !item.isLowOnStock) {
        return false;
      }
      if (_filter == InventoryFilter.expiring &&
          !InventoryRules.isExpiringSoon(item, _today)) {
        return false;
      }
      if (query.isEmpty) return true;
      final product = item.product;
      final matchesName = product.name.toLowerCase().contains(query);
      final matchesBarcode =
          product.barcode?.toLowerCase().contains(query) ?? false;
      return matchesName || matchesBarcode;
    }).toList();
  }

  void _openProductSheet([StockedProduct? existing]) {
    unawaited(ProductSheet.show(context, existing: existing));
  }

  Future<void> _shareShoppingList(List<StockedProduct> products) async {
    final localizations = AppLocalizations.of(context);
    final storeName = ref.read(posStoreProfileProvider).value?.name ?? '';
    final text = InventoryRules.buildShoppingListText(
      localizations: localizations,
      storeName: storeName,
      products: products,
    );
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _openCsvImportSheet() {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: palette.scrim,
        builder: (sheetContext) => TindaBottomSheet(
          title: localizations.inventoryImportCsvTitle,
          closeTooltip: localizations.commonClose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localizations.inventoryImportCsvSubtitle,
                style: AppTypography.body(palette.textMuted),
              ),
              const SizedBox(height: AppSpacing.s16),
              TindaPrimaryButton(
                label: localizations.inventoryImportCsvPickButton,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_pickAndImportCsv());
                },
              ),
              const SizedBox(height: AppSpacing.s10),
              TindaSecondaryButton(
                label: localizations.inventoryImportCsvTemplateButton,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_saveCsvTemplate());
                },
              ),
              const SizedBox(height: AppSpacing.s10),
              TindaSecondaryButton(
                label: localizations.inventoryExportCsvButton,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_exportProductsCsv());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const int _maxListedSkippedRows = 10;

  Future<void> _pickAndImportCsv() async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(productRepositoryProvider);
    final currency = ref.read(storeCurrencyProvider);
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv', 'txt'],
    );
    final pickedPath = pickedFiles.firstOrNull?.path;
    if (pickedPath == null) return;

    try {
      final csvContent = await File(pickedPath).readAsString();
      final report = await const ProductCsvImporter().importCsv(
        csvContent: csvContent,
        repository: repository,
        currency: currency,
      );
      if (report.importedCount == 0 && report.skippedCount == 0) {
        messenger.showSnackBar(
          SnackBar(content: Text(localizations.inventoryImportCsvEmpty)),
        );
        return;
      }
      final summary = localizations.inventoryImportCsvSuccess(
        report.importedCount,
        report.skippedCount,
      );
      final skippedRows = report.errors
          .take(_maxListedSkippedRows)
          .map((error) => error.rowNumber)
          .join(', ');
      messenger.showSnackBar(
        SnackBar(
          duration: Duration(seconds: report.errors.isEmpty ? 4 : 8),
          content: Text(
            report.errors.isEmpty
                ? summary
                : '$summary\n'
                      '${localizations.inventoryImportSkippedRows(skippedRows)}',
          ),
        ),
      );
    } on Exception {
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.inventoryImportCsvReadError)),
      );
    }
  }

  Future<void> _saveCsvTemplate() async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final savedPath = await FilePicker.saveFile(
      dialogTitle: localizations.inventoryImportCsvTemplateButton,
      fileName: 'tinda360_products_template.csv',
      bytes: utf8.encode(ProductCsvImporter.sampleCsv),
    );
    if (savedPath == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.inventoryImportCsvTemplateSaved)),
    );
  }

  Future<void> _exportProductsCsv() async {
    final localizations = AppLocalizations.of(context);
    final products = await ref.read(inventoryProductsProvider.future);
    final csvContent = exportProductsCsv(products);
    final parsed = parseCsvForPreview(csvContent);
    if (!mounted) return;
    await CsvPreviewSheet.show(
      context,
      title: localizations.inventoryExportCsvButton,
      headers: parsed.headers,
      rows: parsed.rows,
      fileName: 'tinda360_products.csv',
      csvContent: csvContent,
      successMessage: localizations.inventoryExportCsvSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final productsAsync = ref.watch(inventoryProductsProvider);
    final allProducts = productsAsync.value ?? const <StockedProduct>[];
    final lowStockCount = InventoryRules.lowStockCount(allProducts);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          Column(
            children: [
              TindaHeaderBar(
                title: Text(localizations.navInventory),
                subtitle: localizations.inventorySummary(
                  allProducts.length,
                  lowStockCount,
                ),
                actions: [
                  if (InventoryRules.shoppingItems(allProducts).isNotEmpty)
                    TindaIconButton(
                      icon: Icons.shopping_cart_outlined,
                      tooltip: localizations.inventoryShareShoppingList,
                      onHeader: true,
                      onPressed: () =>
                          unawaited(_shareShoppingList(allProducts)),
                    ),
                  TindaIconButton(
                    icon: Icons.upload_file_rounded,
                    tooltip: localizations.inventoryImportCsvTooltip,
                    onHeader: true,
                    onPressed: _openCsvImportSheet,
                  ),
                  TindaIconButton(
                    svgAsset: 'assets/icons/settings.svg',
                    tooltip: localizations.posOpenSettings,
                    onHeader: true,
                    onPressed: widget.onOpenSettings,
                  ),
                ],
                bottom: TindaSearchField(
                  hintText: localizations.posSearchHint,
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Expanded(
                child: TindaScreenBody(
                  child: _InventoryBody(
                    productsAsync: productsAsync,
                    filteredProducts: _filterProducts(allProducts),
                    filter: _filter,
                    today: _today,
                    onFilterChanged: (filter) =>
                        setState(() => _filter = filter),
                    onTapProduct: _openProductSheet,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: AppSpacing.screenHorizontal,
            bottom: AppSpacing.s16,
            child: _AddProductPill(
              label: localizations.inventoryAddProduct,
              onPressed: _openProductSheet,
            ),
          ),
          Positioned(
            right: AppSpacing.screenHorizontal,
            bottom: AppSpacing.s16,
            child: TindaAiFab(
              onPressed: widget.onOpenAiChat,
              tooltip: localizations.chatOpenTindaAi,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryBody extends StatelessWidget {
  const _InventoryBody({
    required this.productsAsync,
    required this.filteredProducts,
    required this.filter,
    required this.today,
    required this.onFilterChanged,
    required this.onTapProduct,
  });

  final AsyncValue<List<StockedProduct>> productsAsync;
  final List<StockedProduct> filteredProducts;
  final InventoryFilter filter;
  final LocalDay today;
  final ValueChanged<InventoryFilter> onFilterChanged;
  final ValueChanged<StockedProduct> onTapProduct;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 0 : 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: productsAsync.when(
        loading: () => const Padding(
          key: ValueKey('inventory-loading'),
          padding: EdgeInsets.all(AppSpacing.s16),
          child: TindaListSkeleton(),
        ),
        error: (_, _) => Center(
          key: const ValueKey('inventory-error'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Text(
              localizations.homeLoadFailed,
              style: AppTypography.body(palette.danger),
            ),
          ),
        ),
        data: (allProducts) {
          final listKey = ValueKey(
            'inv-${filter.name}-${filteredProducts.length}-${allProducts.length}',
          );
          final Widget content;
          if (allProducts.isEmpty) {
            content = TindaEmptyState(
              key: const ValueKey('inv-empty-all'),
              icon: Icons.inventory_2_outlined,
              title: localizations.inventoryEmptyTitle,
              body: localizations.inventoryEmptyBody,
            );
          } else if (filteredProducts.isEmpty) {
            content = TindaEmptyState(
              key: const ValueKey('inv-empty-filter'),
              icon: Icons.search_off_rounded,
              title: localizations.inventoryFilterEmptyTitle,
              body: localizations.inventoryFilterEmptyBody,
            );
          } else {
            content = TindaGroupedCard(
              key: listKey,
              children: [
                for (var index = 0; index < filteredProducts.length; index++)
                  _AnimatedInventoryRow(
                    key: ValueKey(filteredProducts[index].product.id),
                    index: index,
                    child: _InventoryProductRow(
                      item: filteredProducts[index],
                      today: today,
                      onTap: () => onTapProduct(filteredProducts[index]),
                    ),
                  ),
              ],
            );
          }
          return ListView(
            key: const ValueKey('inventory-data'),
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screenHorizontal,
              AppSpacing.s14,
              AppSpacing.screenHorizontal,
              TindaScreenBody.floatingBottomPadding(context),
            ),
            children: [
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  TindaFilterChip(
                    label: localizations.commonAll,
                    selected: filter == InventoryFilter.all,
                    onTap: () => onFilterChanged(InventoryFilter.all),
                  ),
                  TindaFilterChip(
                    label: localizations.inventoryLowFilter,
                    selected: filter == InventoryFilter.lowStock,
                    onTap: () => onFilterChanged(InventoryFilter.lowStock),
                  ),
                  TindaFilterChip(
                    label: localizations.inventoryExpiringFilter,
                    selected: filter == InventoryFilter.expiring,
                    onTap: () => onFilterChanged(InventoryFilter.expiring),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              AnimatedSwitcher(
                duration: Duration(milliseconds: reduceMotion ? 0 : 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: content,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnimatedInventoryRow extends StatelessWidget {
  const _AnimatedInventoryRow({
    required this.index,
    required this.child,
    super.key,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return child;
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
      child: child,
    );
  }
}

class _InventoryProductRow extends StatelessWidget {
  const _InventoryProductRow({
    required this.item,
    required this.today,
    required this.onTap,
  });

  final StockedProduct item;
  final LocalDay today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final product = item.product;
    final stockFormatted = formatQuantity(item.stock, product.unit);
    final subtitle =
        '${formatMoney(product.price)} ${localizedUnit(localizations, product.unit)}'
        ' · ${localizations.inventoryCostSummary(formatMoney(product.cost))}';

    final stockText = item.tracksStock
        ? localizations.posStockLabel(stockFormatted)
        : localizations.inventoryNoCountLabel;
    final expiryStatus = ExpiryRules.statusFor(product.expiryDay, today);
    final expiryLabel = switch (expiryStatus) {
      ExpiryExpired() => localizations.inventoryExpiredBadge,
      ExpiryNear(:final daysLeft) => localizations.inventoryExpiryDaysBadge(
        daysLeft,
      ),
      null => null,
    };
    final badgeLabel = item.isLowOnStock
        ? '$stockText · ${localizations.posLowStockBadge}'
        : stockText;

    return InkWell(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: AdaptiveBadges(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: AppTypography.bodyStrong(palette.text),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  subtitle,
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
            ),
            badges: [
              TindaBadge(
                label: badgeLabel,
                isWarning: item.isLowOnStock,
              ),
              if (expiryLabel != null)
                TindaBadge(
                  label: expiryLabel,
                  isWarning: expiryStatus is ExpiryNear,
                  isDanger: expiryStatus is ExpiryExpired,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProductPill extends StatelessWidget {
  const _AddProductPill({
    required this.label,
    required this.onPressed,
  });

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
        child: FilledButton(
          onPressed: () {
            unawaited(HapticFeedback.lightImpact());
            onPressed();
          },
          style: FilledButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
            shape: const StadiumBorder(),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s12,
            ),
            elevation: 6,
            shadowColor: palette.primary.withValues(alpha: 0.32),
            textStyle: AppTypography.bodyStrong(
              palette.onPrimary,
              size: 15,
              weight: FontWeight.w700,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
