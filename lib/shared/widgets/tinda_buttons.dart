import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Full-width primary action button (56 dp height, 14 dp radius).
class TindaPrimaryButton extends StatelessWidget {
  /// Creates a primary button.
  const TindaPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
  });

  /// Button label.
  final String label;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  /// Shows a compact spinner when true.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      width: double.infinity,
      height: AppSizes.mainButtonHeight,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.mainButton),
          ),
          textStyle: AppTypography.bodyStrong(
            palette.onPrimary,
            size: 16,
            weight: FontWeight.w700,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: palette.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Outlined secondary action button (52 dp height, 14 dp radius).
class TindaSecondaryButton extends StatelessWidget {
  /// Creates a secondary button.
  const TindaSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  /// Button label.
  final String label;

  /// Tap handler.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      width: double.infinity,
      height: AppSizes.secondaryButtonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.surface,
          foregroundColor: palette.text,
          side: BorderSide(color: palette.borderStrong, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.mainButton),
          ),
          textStyle: AppTypography.bodyStrong(
            palette.text,
            weight: FontWeight.w700,
          ),
        ),
        child: icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(child: Text(label)),
                ],
              ),
      ),
    );
  }
}

/// Compact mango accent button (46 dp height, 12 dp radius), e.g. Bayad.
class TindaAccentButton extends StatelessWidget {
  /// Creates an accent button.
  const TindaAccentButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// Button label.
  final String label;

  /// Tap handler.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: AppSizes.accentButtonHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: AppTypography.bodyStrong(
            palette.onAccent,
            weight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Underlined text link button (48 dp min height).
class TindaTextLinkButton extends StatelessWidget {
  /// Creates a text link button.
  const TindaTextLinkButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isDanger = false,
  });

  /// Button label.
  final String label;

  /// Tap handler.
  final VoidCallback? onPressed;

  /// Uses danger color when true (e.g. Delete product).
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = isDanger ? palette.danger : palette.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: color),
        child: Text(
          label,
          style: AppTypography.bodyStrong(
            color,
            weight: FontWeight.w700,
          ).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}

/// Google sign-in pill button (44 dp height).
class TindaGoogleButton extends StatelessWidget {
  /// Creates a Google sign-in button.
  const TindaGoogleButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// Button label.
  final String label;

  /// Tap handler.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.touchTargetMin,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: const Color(0xFF1F1F1F),
          side: const BorderSide(color: Color(0xFF747775)),
          shape: const StadiumBorder(),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s16,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.g_mobiledata_rounded,
              size: 24,
              color: Color(0xFF4285F4),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 44x44 icon button with 12 dp radius and semantic tooltip.
class TindaIconButton extends StatelessWidget {
  /// Creates an icon button.
  const TindaIconButton({
    required this.tooltip,
    required this.onPressed,
    super.key,
    this.icon,
    this.svgAsset,
    this.onHeader = false,
  }) : assert(icon != null || svgAsset != null, 'Provide icon or svgAsset');

  /// Icon glyph.
  final IconData? icon;

  /// Optional SVG asset path from `assets/icons/`.
  final String? svgAsset;

  /// Accessible tooltip label.
  final String tooltip;

  /// Tap handler.
  final VoidCallback? onPressed;

  /// Uses translucent white fill on dark header; muted surface in sheets.
  final bool onHeader;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final background = onHeader
        ? palette.onHeader.withValues(alpha: 0.14)
        : palette.surfaceMuted;
    final foreground = onHeader ? palette.onHeader : palette.text;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadii.button),
            child: SizedBox(
              width: AppSizes.touchTargetMin,
              height: AppSizes.touchTargetMin,
              child: Center(
                child: svgAsset != null
                    ? SvgPicture.asset(
                        svgAsset!,
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          foreground,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(icon, size: 20, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
