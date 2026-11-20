import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/calendar/time_greeting.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/features/pos/data/popular_sort.dart';
import 'package:tinda360/features/pos/data/product_popularity_provider.dart';
import 'package:tinda360/features/pos/presentation/backup_warning_banner.dart';
import 'package:tinda360/features/pos/presentation/bantay_chip.dart';
import 'package:tinda360/features/pos/presentation/cart_price_override_provider.dart';
import 'package:tinda360/features/pos/presentation/cart_quantity_dialog.dart';
import 'package:tinda360/features/pos/presentation/checkout_sheet.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/barcode_scanner_sheet.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_logo.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/adaptive_layout.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';
import 'package:tinda360/services/store_sounds.dart';

final StreamProvider<StoreProfile> posStoreProfileProvider =
    StreamProvider.autoDispose<StoreProfile>(
      (ref) => ref.watch(storeProfileRepositoryProvider).watch(),
    );

final StreamProvider<List<StockedProduct>> posProductsProvider =
    StreamProvider.autoDispose<List<StockedProduct>>((
      ref,
    ) {
      final unitsSold = ref.watch(productPopularityProvider).value ?? const {};
      return ref
          .watch(productRepositoryProvider)
          .watchActive()
          .map((products) => sortProductsByPopularity(products, unitsSold));
    });

class PosScreen extends ConsumerStatefulWidget {
  const new({
    required this.onOpenSettings,
    required this.onOpenAiChat,
    super.key,
    this.showStorageWarning = false,
  });

  final VoidCallback onOpenSettings;

  final VoidCallback onOpenAiChat;

  final bool showStorageWarning;

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  static const double _minHeightForGreeting = 700;

  static const double _compactChromeMaxWidth = 400;
  bool _showGreeting = true;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<StockedProduct>>>(
      posProductsProvider,
      (previousProducts, nextProducts) {
        final liveProducts = nextProducts.value;
        if (liveProducts != null) {
          ref.read(posCartProvider.notifier).keepWithinStock(liveProducts);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _extractCategories(List<StockedProduct> products) {
    final unique = <String>{};
    for (final item in products) {
      final category = item.product.categoryId?.trim();
      if (category != null && category.isNotEmpty) {
        unique.add(category);
      }
    }
    return unique.toList()..sort();
  }

  List<StockedProduct> _filterProducts(List<StockedProduct> products) {
    final query = _searchQuery.trim().toLowerCase();
    return products.where((item) {
      final product = item.product;
      if (_selectedCategory != null &&
          product.categoryId?.trim() != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      final matchesName = product.name.toLowerCase().contains(query);
      final matchesBarcode =
          product.barcode?.toLowerCase().contains(query) ?? false;
      return matchesName || matchesBarcode;
    }).toList();
  }

  Future<void> _scanBarcode(
    List<StockedProduct> products,
    PosCartNotifier cartNotifier,
    AppLocalizations localizations,
  ) async {
    await BarcodeScannerSheet.show(
      context,
      continuous: true,
      onCode: (code) {
        if (!mounted) return false;
        final match = products.where((item) => item.product.barcode == code);
        if (match.isNotEmpty) {
          if (addToCartOrWarn(context, cartNotifier, match.first)) {
            unawaited(HapticFeedback.mediumImpact());
          }
          return true;
        }
        ref.read(storeSoundPlayerProvider).play(StoreSound.notFound);
        unawaited(HapticFeedback.heavyImpact());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.scannerProductNotFound(code)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return true;
      },
    );
  }

  void _openCheckout(
    List<StockedProduct> products,
    Map<String, Quantity> cart,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppPalette.of(context).scrim,
      builder: (_) => CheckoutSheet(products: products, cart: cart),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final storeName = ref.watch(posStoreProfileProvider).value?.name;
    final productsAsync = ref.watch(posProductsProvider);
    final cart = ref.watch(posCartProvider);
    final cartNotifier = ref.read(posCartProvider.notifier);
    final currency = ref.watch(storeCurrencyProvider);
    final products = productsAsync.value ?? const <StockedProduct>[];
    final hasCartItems = cart.isNotEmpty;
    final screenSize = MediaQuery.sizeOf(context);
    final useCompactChrome =
        screenSize.width < _compactChromeMaxWidth ||
        AdaptiveLayout.textScaleOf(context) > AdaptiveLayout.largeTextThreshold;
    final showGreetingBubble =
        _showGreeting &&
        screenSize.height >= _minHeightForGreeting &&
        AdaptiveLayout.textScaleOf(context) <=
            AdaptiveLayout.largeTextThreshold;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          Column(
            children: [
              TindaHeaderBar(
                leading: const TindaLogoMark(size: 32, onDarkHeader: true),
                title: const TindaWordmark(),
                subtitle: storeName,
                belowSubtitle: useCompactChrome
                    ? const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.s8),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: BantayChip(),
                        ),
                      )
                    : null,
                actions: [
                  if (!useCompactChrome) const BantayChip(),
                  TindaIconButton(
                    svgAsset: 'assets/icons/scan_barcode.svg',
                    tooltip: localizations.posScanBarcode,
                    onHeader: true,
                    onPressed: () => unawaited(
                      _scanBarcode(products, cartNotifier, localizations),
                    ),
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
                  child: _PosBody(
                    productsAsync: productsAsync,
                    filteredProducts: _filterProducts(products),
                    categories: _extractCategories(products),
                    selectedCategory: _selectedCategory,
                    showStorageWarning: widget.showStorageWarning,
                    onOpenSettings: widget.onOpenSettings,
                    hasCartItems: hasCartItems,
                    cart: cart,
                    onCategorySelected: (category) =>
                        setState(() => _selectedCategory = category),
                    onIncrement: (item) =>
                        addToCartOrWarn(context, cartNotifier, item),
                    onSetQuantity: (item) => unawaited(
                      askAndSetCartQuantity(
                        context,
                        cartNotifier: cartNotifier,
                        stocked: item,
                        currentQuantity:
                            cart[item.product.id] ?? const Quantity.whole(1),
                      ),
                    ),
                    onDecrement: (id) {
                      final quantity = cart[id];
                      cartNotifier.decrement(id);
                      if (quantity != null &&
                          quantity.milli <= Quantity.milliPerUnit) {
                        final name = products
                            .where((item) => item.product.id == id)
                            .map((item) => item.product.name)
                            .cast<String?>()
                            .firstWhere(
                              (value) => value != null,
                              orElse: () => null,
                            );
                        final messenger = ScaffoldMessenger.of(context)
                          ..clearSnackBars();
                        messenger.showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            persist: false,
                            content: Text(
                              localizations.posRemovedFromCart(name ?? '—'),
                            ),
                            action: SnackBarAction(
                              label: localizations.commonUndo,
                              onPressed: () {
                                final liveItem =
                                    (ref.read(posProductsProvider).value ??
                                            products)
                                        .where(
                                          (entry) => entry.product.id == id,
                                        )
                                        .firstOrNull;
                                final restored =
                                    liveItem != null &&
                                    cartNotifier.setQuantity(
                                      id,
                                      quantity,
                                      available: liveItem.sellCap,
                                    );
                                if (!restored && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        localizations.posOutOfStock(
                                          name ?? '—',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          if (showGreetingBubble)
            Positioned(
              right: 88,
              bottom: hasCartItems ? 96 : 20,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: _GreetingBubble(
                  onTap: widget.onOpenAiChat,
                  onDismiss: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _showGreeting = false);
                  },
                ),
              ),
            ),
          Positioned(
            right: AppSpacing.screenHorizontal,
            bottom: hasCartItems
                ? TindaScreenBody.floatingBottomPadding(context)
                : AppSpacing.s16,
            child: TindaAiFab(
              onPressed: widget.onOpenAiChat,
              tooltip: localizations.chatOpenTindaAi,
            ),
          ),
          if (hasCartItems)
            Positioned(
              left: AppSpacing.screenHorizontal,
              right: AppSpacing.screenHorizontal,
              bottom: AppSpacing.s16,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('cart_${cartNotifier.itemCount}_${cart.length}'),
                tween: Tween(begin: 0.97, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: TindaCartBar(
                  itemsLabel: localizations.posCartItems(
                    cartNotifier.itemCount,
                  ),
                  totalLabel: formatMoney(
                    cartNotifier.totalFor(
                      products,
                      currency,
                      priceOverrides: ref.watch(cartPriceOverrideProvider),
                    ),
                  ),
                  payLabel: localizations.posPayButton,
                  onPay: () {
                    unawaited(HapticFeedback.mediumImpact());
                    _openCheckout(products, cart);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const double _cartBarExtraClearance = 72;

class _PosBody extends StatelessWidget {
  const new({
    required this.productsAsync,
    required this.filteredProducts,
    required this.categories,
    required this.selectedCategory,
    required this.showStorageWarning,
    required this.onOpenSettings,
    required this.hasCartItems,
    required this.cart,
    required this.onCategorySelected,
    required this.onIncrement,
    required this.onSetQuantity,
    required this.onDecrement,
  });

  final AsyncValue<List<StockedProduct>> productsAsync;
  final List<StockedProduct> filteredProducts;
  final List<String> categories;
  final String? selectedCategory;
  final bool showStorageWarning;
  final VoidCallback onOpenSettings;
  final bool hasCartItems;
  final Map<String, Quantity> cart;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<StockedProduct> onIncrement;
  final ValueChanged<StockedProduct> onSetQuantity;
  final ValueChanged<String> onDecrement;

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
          key: ValueKey('pos-loading'),
          padding: EdgeInsets.all(AppSpacing.s16),
          child: TindaListSkeleton(),
        ),
        error: (_, _) => Center(
          key: const ValueKey('pos-error'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Text(
              localizations.homeLoadFailed,
              style: AppTypography.body(palette.danger),
            ),
          ),
        ),
        data: (allProducts) {
          Widget listContent;
          if (allProducts.isEmpty) {
            listContent = TindaEmptyState(
              key: const ValueKey('pos-empty-all'),
              icon: Icons.storefront_outlined,
              title: localizations.posEmptyTitle,
              body: localizations.posEmptyBody,
            );
          } else if (filteredProducts.isEmpty) {
            listContent = TindaEmptyState(
              key: const ValueKey('pos-empty-filter'),
              icon: Icons.search_off_rounded,
              title: localizations.posEmptyTitle,
              body: localizations.posSearchHint,
            );
          } else {
            listContent = TindaGroupedCard(
              key: ValueKey(
                'pos-list-${selectedCategory ?? 'all'}-${filteredProducts.length}',
              ),
              children: [
                for (var index = 0; index < filteredProducts.length; index++)
                  _AnimatedPosRow(
                    key: ValueKey(filteredProducts[index].product.id),
                    index: index,
                    child: _PosProductRow(
                      item: filteredProducts[index],
                      cartQuantity: cart[filteredProducts[index].product.id],
                      onAdd: () => onIncrement(filteredProducts[index]),
                      onSetQuantity: () =>
                          onSetQuantity(filteredProducts[index]),
                      onRemove: () =>
                          onDecrement(filteredProducts[index].product.id),
                    ),
                  ),
              ],
            );
          }
          return ListView(
            key: const ValueKey('pos-data'),
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screenHorizontal,
              AppSpacing.s14,
              AppSpacing.screenHorizontal,
              TindaScreenBody.floatingBottomPadding(context) +
                  (hasCartItems ? _cartBarExtraClearance : 0),
            ),
            children: [
              if (showStorageWarning) ...[
                TindaBanner(
                  icon: Icons.warning_amber_rounded,
                  title: localizations.posStorageFullTitle,
                  body: localizations.posStorageFullBody,
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              BackupWarningBanner(onOpenSettings: onOpenSettings),
              if (categories.isNotEmpty) ...[
                _CategoryChipsRow(
                  categories: categories,
                  selectedCategory: selectedCategory,
                  onSelected: onCategorySelected,
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              AnimatedSwitcher(
                duration: Duration(milliseconds: reduceMotion ? 0 : 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: listContent,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GreetingBubble extends StatelessWidget {
  const new({required this.onTap, required this.onDismiss});

  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return Material(
      color: palette.surface,
      elevation: 6,
      shadowColor: palette.text.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(AppRadii.card),
          topEnd: Radius.circular(AppRadii.card),
          bottomStart: Radius.circular(AppRadii.card),
          bottomEnd: Radius.circular(AppSpacing.s4),
        ),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.s14,
          AppSpacing.s10,
          AppSpacing.s4,
          AppSpacing.s10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: onTap,
                child: Text(
                  localizations.posGreeting.replaceFirst(
                    'Magandang araw!',
                    timeOfDayGreeting(
                      DateTime.now(),
                      isFilipino: localizations.localeName.startsWith('fil'),
                    ),
                  ),
                  style: AppTypography.body(palette.text, size: 13),
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: localizations.posGreetingDismiss,
              icon: Icon(Icons.close, size: 16, color: palette.textMuted),
              constraints: const BoxConstraints(
                minWidth: AppSizes.touchTargetMin,
                minHeight: AppSizes.touchTargetMin,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  const new({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          TindaFilterChip(
            label: localizations.commonAll,
            selected: selectedCategory == null,
            onTap: () => onSelected(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: AppSpacing.s8),
            TindaFilterChip(
              label: category,
              selected: selectedCategory == category,
              onTap: () => onSelected(category),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimatedPosRow extends StatelessWidget {
  const new({
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
      duration: Duration(milliseconds: 160 + (index.clamp(0, 10) * 18)),
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

class _PosProductRow extends StatelessWidget {
  const new({
    required this.item,
    required this.cartQuantity,
    required this.onAdd,
    required this.onSetQuantity,
    required this.onRemove,
  });

  final StockedProduct item;
  final Quantity? cartQuantity;
  final VoidCallback onAdd;
  final VoidCallback onSetQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final product = item.product;
    final stockText = item.tracksStock
        ? localizations.posStockLabel(formatQuantity(item.stock, product.unit))
        : localizations.inventoryNoCountLabel;
    final subtitle =
        '${formatMoney(product.price)} ${localizedUnit(localizations, product.unit)} · $stockText';

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.s16,
        AppSpacing.s10,
        AppSpacing.s10,
        AppSpacing.s10,
      ),
      child: Row(
        children: [
          Expanded(
            child: AdaptiveBadges(
              content: InkWell(
                onTap: onSetQuantity,
                borderRadius: BorderRadius.circular(AppRadii.chip),
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
              badges: [
                if (!item.isSellable)
                  TindaBadge(
                    label: localizations.posOutOfStockBadge,
                    isWarning: true,
                  )
                else if (item.isLowOnStock)
                  TindaBadge(
                    label: localizations.posLowStockBadge,
                    isWarning: true,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          if (cartQuantity != null) ...[
            _RemoveFromCartButton(
              tooltip: localizations.posRemoveFromCart(product.name),
              onPressed: onRemove,
              palette: palette,
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
          _AddToCartButton(
            tooltip: localizations.posAddToCart(product.name),
            countLabel: cartQuantity == null
                ? null
                : formatQuantity(cartQuantity!, product.unit),
            onPressed: onAdd,
            isInStock: item.isSellable,
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _RemoveFromCartButton extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.onPressed,
    required this.palette,
  });

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
          color: palette.surfaceMuted,
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
                minWidth: AppSizes.touchTargetMin,
                minHeight: AppSizes.touchTargetMin,
              ),
              child: Icon(Icons.remove, size: 20, color: palette.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.countLabel,
    required this.onPressed,
    required this.isInStock,
    required this.palette,
  });

  final String tooltip;
  final String? countLabel;
  final VoidCallback onPressed;
  final bool isInStock;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: isInStock ? palette.primary : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onPressed();
            },
            borderRadius: BorderRadius.circular(AppRadii.button),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppSizes.touchTargetMin,
                minHeight: AppSizes.touchTargetMin,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.s10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      size: 20,
                      color: isInStock ? palette.onPrimary : palette.textMuted,
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: countLabel == null
                          ? const SizedBox.shrink(key: ValueKey('none'))
                          : Padding(
                              key: ValueKey(countLabel),
                              padding: const EdgeInsetsDirectional.only(
                                start: AppSpacing.s4,
                              ),
                              child: Text(
                                countLabel!,
                                style: AppTypography.meta(
                                  palette.onPrimary,
                                  size: 13,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
