import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tinda360/features/chat/presentation/chat_sheet.dart';
import 'package:tinda360/features/inventory/presentation/inventory_screen.dart';
import 'package:tinda360/features/pos/presentation/pos_screen.dart';
import 'package:tinda360/features/ulat/presentation/ulat_screen.dart';
import 'package:tinda360/features/utang/presentation/utang_screen.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Root 4-tab shell: Benta (POS), Imbentaryo, Utang, and Ulat.
class MainShell extends StatefulWidget {
  /// Creates the main tab shell.
  const MainShell({
    required this.onOpenSettings,
    super.key,
    this.initialIndex = 0,
  });

  /// Opens the Settings screen.
  final VoidCallback onOpenSettings;

  /// Initial tab index.
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex = widget.initialIndex;

  void _openChat() {
    unawaited(
      ChatSheet.show(
        context,
        onOpenTab: (index) => setState(() => _currentIndex = index),
      ),
    );
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
        onOpenTab: (index) => setState(() => _currentIndex = index),
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
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavTabItem(
                  svgAsset: 'assets/icons/nav_imbentaryo.svg',
                  label: localizations.navInventory,
                  selected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavTabItem(
                  svgAsset: 'assets/icons/nav_utang.svg',
                  label: localizations.navUtang,
                  selected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavTabItem(
                  svgAsset: 'assets/icons/nav_ulat.svg',
                  label: localizations.navReports,
                  selected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
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
  const _NavTabItem({
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
    final color = selected ? palette.primary : palette.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                svgAsset,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.navLabel(color, active: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
