import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/chat/presentation/chat_sheet.dart';
import 'package:tinda360/features/chat/presentation/yumi_screen.dart';
import 'package:tinda360/features/inventory/presentation/inventory_screen.dart';
import 'package:tinda360/features/pos/presentation/pos_screen.dart';
import 'package:tinda360/features/ulat/presentation/ulat_screen.dart';
import 'package:tinda360/features/utang/presentation/utang_screen.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/theme/adaptive_layout.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class MainShell extends ConsumerStatefulWidget {
  const new({
    required this.onOpenSettings,
    super.key,
    this.initialIndex = 0,
  });

  final VoidCallback onOpenSettings;

  final int initialIndex;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishYumiScreen();
    });
  }

  void _publishYumiScreen() {
    ref
        .read(yumiScreenProvider.notifier)
        .setScreen(yumiScreenForTab(_currentIndex));
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    _publishYumiScreen();
  }

  void _openChat() {
    unawaited(ChatSheet.show(context, onOpenTab: _selectTab));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final navHeight = textScale > 1.3
        ? AppSizes.bottomNavLargeHeight
        : AppSizes.bottomNavHeight;

    final pages = [
      PosScreen(
        onOpenSettings: widget.onOpenSettings,
        onOpenAiChat: _openChat,
      ),
      InventoryScreen(
        onOpenSettings: widget.onOpenSettings,
        onOpenAiChat: _openChat,
      ),
      UtangScreen(
        onOpenSettings: widget.onOpenSettings,
        onOpenAiChat: _openChat,
      ),
      UlatScreen(
        onOpenSettings: widget.onOpenSettings,
        onOpenAiChat: _openChat,
        onOpenTab: _selectTab,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.32
                    : 0.06,
              ),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: navHeight,
            child: Row(
              children: [
                _NavTabItem(
                  svgAsset: 'assets/icons/nav_benta.svg',
                  label: localizations.navSales,
                  selected: _currentIndex == 0,
                  onTap: () => _selectTab(0),
                ),
                _NavTabItem(
                  svgAsset: 'assets/icons/nav_imbentaryo.svg',
                  label: localizations.navInventory,
                  selected: _currentIndex == 1,
                  onTap: () => _selectTab(1),
                ),
                _NavTabItem(
                  svgAsset: 'assets/icons/nav_utang.svg',
                  label: localizations.navUtang,
                  selected: _currentIndex == 2,
                  onTap: () => _selectTab(2),
                ),
                _NavTabItem(
                  svgAsset: 'assets/icons/nav_ulat.svg',
                  label: localizations.navReports,
                  selected: _currentIndex == 3,
                  onTap: () => _selectTab(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  const new({
    required this.svgAsset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String svgAsset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = selected ? palette.primary : palette.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: () {
            if (!selected) unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: Duration(milliseconds: reduceMotion ? 0 : 180),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: SvgPicture.asset(
                    svgAsset,
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AdaptiveTextScale(
                maxScale: AdaptiveLayout.maxChromeTextScale,
                child: AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 180),
                  curve: Curves.easeOut,
                  style: AppTypography.navLabel(color, active: selected),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1, softWrap: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
