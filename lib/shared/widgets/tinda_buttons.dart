import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class TindaPrimaryButton extends StatelessWidget {
  const TindaPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
  });

  final String label;

  final VoidCallback? onPressed;

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
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}

class TindaSecondaryButton extends StatelessWidget {
  const TindaSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;

  final VoidCallback? onPressed;

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
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TindaAccentButton extends StatelessWidget {
  const TindaAccentButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;

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

class TindaTextLinkButton extends StatelessWidget {
  const TindaTextLinkButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isDanger = false,
  });

  final String label;

  final VoidCallback? onPressed;

  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = isDanger ? palette.danger : palette.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: TextButton(
        onPressed: onPressed == null
            ? null
            : () {
                unawaited(HapticFeedback.selectionClick());
                onPressed!();
              },
        style: TextButton.styleFrom(foregroundColor: color),
        child: Text(
          label,
          style:
              AppTypography.bodyStrong(
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

class TindaGoogleButton extends StatelessWidget {
  const TindaGoogleButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: AppSizes.touchTargetMin,
      ),
      child: OutlinedButton(
        onPressed: onPressed == null
            ? null
            : () {
                unawaited(HapticFeedback.lightImpact());
                onPressed!();
              },
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
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F1F1F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TindaIconButton extends StatelessWidget {
  const TindaIconButton({
    required this.tooltip,
    required this.onPressed,
    super.key,
    this.icon,
    this.svgAsset,
    this.onHeader = false,
  }) : assert(icon != null || svgAsset != null, 'Provide icon or svgAsset');

  final IconData? icon;

  final String? svgAsset;

  final String tooltip;

  final VoidCallback? onPressed;

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
