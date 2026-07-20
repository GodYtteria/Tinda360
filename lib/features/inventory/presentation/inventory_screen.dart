import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/inventory/data/product_csv_exporter.dart';
import 'package:tinda360/features/inventory/data/product_csv_importer.dart';
import 'package:tinda360/shared/widgets/csv_preview_sheet.dart';
import 'package:tinda360/features/inventory/presentation/product_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Watches active stocked products for the Inventory screen.
final inventoryProductsProvider =
    StreamProvider.autoDispose<List<StockedProduct>>(
      (ref) => ref.watch(productRepositoryProvider).watchActive(),
    );

/// Inventory management screen with search, low-stock filter, and product
/// add/edit sheet triggers.
class InventoryScreen extends ConsumerStatefulWidget {
  /// Creates the inventory screen.
  const InventoryScreen({
    required this.onOpenSettings,
    required this.onOpenAiChat,
    super.key,
  });

  /// Opens the settings screen.
  final VoidCallback onOpenSettings;

  /// Opens the Tinda AI chat sheet.
  final VoidCallback onOpenAiChat;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StockedProduct> _filterProducts(List<StockedProduct> products) {
    final query = _searchQuery.trim().toLowerCase();
    return products.where((item) {
      if (_lowStockOnly && !item.isLowOnStock) return false;
      if (query.isEmpty) return true;
      final product = item.product;
      final matchesName = product.name.toLowerCase().contains(query);
      final matchesBarcode =
          product.barcode?.toLowerCase().contains(query) ?? false;
      return matchesName || matchesBarcode;
    }).toList();
  }

  void _openProductSheet([StockedProduct? existing]) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: AppPalette.of(context).scrim,
        builder: (_) => ProductSheet(existing: existing),
      ),
    );
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

  Future<void> _pickAndImportCsv() async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv', 'txt'],
    );
    final pickedPath = pickedFiles?.firstOrNull?.path;
    if (pickedPath == null) return;

    try {
      final csvContent = await File(pickedPath).readAsString();
      final report = await const ProductCsvImporter().importCsv(
        csvContent: csvContent,
        repository: ref.read(productRepositoryProvider),
        currency: ref.read(storeCurrencyProvider),
      );
      if (report.importedCount == 0 && report.skippedCount == 0) {
        messenger.showSnackBar(
          SnackBar(content: Text(localizations.inventoryImportCsvEmpty)),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            localizations.inventoryImportCsvSuccess(
              report.importedCount,
              report.skippedCount,
            ),
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
    final products = ref.read(inventoryProductsProvider).value ?? const [];
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
    final lowStockCount = allProducts.where((item) => item.isLowOnStock).length;

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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _InventoryBody(
                      productsAsync: productsAsync,
                      filteredProducts: _filterProducts(allProducts),
                      lowStockOnly: _lowStockOnly,
                      onFilterChanged: (lowOnly) =>
                          setState(() => _lowStockOnly = lowOnly),
                      onTapProduct: _openProductSheet,
                    ),
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
    required this.lowStockOnly,
    required this.onFilterChanged,
    required this.onTapProduct,
  });

  final AsyncValue<List<StockedProduct>> productsAsync;
  final List<StockedProduct> filteredProducts;
  final bool lowStockOnly;
  final ValueChanged<bool> onFilterChanged;
  final ValueChanged<StockedProduct> onTapProduct;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Text(
            localizations.homeLoadFailed,
            style: AppTypography.body(palette.danger),
          ),
        ),
      ),
      data: (allProducts) {
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenHorizontal,
            AppSpacing.s14,
            AppSpacing.screenHorizontal,
            96,
          ),
          children: [
            Row(
              children: [
                TindaFilterChip(
                  label: localizations.commonAll,
                  selected: !lowStockOnly,
                  onTap: () => onFilterChanged(false),
                ),
                const SizedBox(width: AppSpacing.s8),
                TindaFilterChip(
                  label: localizations.inventoryLowFilter,
                  selected: lowStockOnly,
                  onTap: () => onFilterChanged(true),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            if (allProducts.isEmpty)
              TindaEmptyState(
                icon: Icons.inventory_2_outlined,
                title: localizations.inventoryEmptyTitle,
                body: localizations.inventoryEmptyBody,
              )
            else if (filteredProducts.isEmpty)
              TindaEmptyState(
                icon: Icons.search_off_rounded,
                title: localizations.inventoryFilterEmptyTitle,
                body: localizations.inventoryFilterEmptyBody,
              )
            else
              TindaGroupedCard(
                children: [
                  for (final item in filteredProducts)
                    _InventoryProductRow(
                      item: item,
                      onTap: () => onTapProduct(item),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _InventoryProductRow extends StatelessWidget {
  const _InventoryProductRow({
    required this.item,
    required this.onTap,
  });

  final StockedProduct item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final product = item.product;
    final stockFormatted = formatQuantity(item.stock, product.unit);
    final subtitle =
        '${formatMoney(product.price)} ${localizedUnit(localizations, product.unit)}'
        ' · Puhunan ${formatMoney(product.cost)}';

    final stockText = localizations.posStockLabel(stockFormatted);
    final badgeLabel = item.isLowOnStock
        ? '$stockText · ${localizations.posLowStockBadge}'
        : stockText;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: AppSpacing.s12),
              TindaBadge(
                label: badgeLabel,
                isWarning: item.isLowOnStock,
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
          onPressed: onPressed,
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
