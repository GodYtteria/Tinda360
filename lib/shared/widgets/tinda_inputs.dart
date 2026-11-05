import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tinda360/theme/adaptive_layout.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class TindaTextInput extends StatelessWidget {
  const TindaTextInput({
    required this.label,
    super.key,
    this.controller,
    this.hintText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.autofocus = false,
  });

  final String label;

  final TextEditingController? controller;

  final String? hintText;

  final String? errorText;

  final TextInputType? keyboardType;

  final TextInputAction? textInputAction;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  final Widget? suffixIcon;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide(color: palette.borderStrong, width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.meta(
            palette.text,
            size: 13,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          style: AppTypography.bodyStrong(palette.text, size: 15),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.body(palette.textMuted),
            errorText: errorText,
            errorMaxLines: 2,
            filled: true,
            fillColor: palette.surface,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s14,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: palette.primary, width: 2),
            ),
            errorBorder: border.copyWith(
              borderSide: BorderSide(color: palette.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class TindaSearchField extends StatelessWidget {
  const TindaSearchField({
    required this.hintText,
    required this.onChanged,
    super.key,
    this.controller,
  });

  final String hintText;

  final ValueChanged<String> onChanged;

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: AppSizes.searchHeight,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.body(palette.text, size: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.body(palette.textMuted, size: 14),
          prefixIcon: Icon(Icons.search, color: palette.textMuted, size: 20),
          filled: true,
          fillColor: palette.surface,
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            borderSide: BorderSide(color: palette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            borderSide: BorderSide(color: palette.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class TindaFilterChip extends StatelessWidget {
  const TindaFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;

  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final enabled = onTap != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSizes.chipHeight,
        minWidth: AppSizes.touchTargetMin,
      ),
      child: Material(
        color: selected ? palette.primary : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          side: selected
              ? BorderSide.none
              : BorderSide(color: palette.borderStrong, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  unawaited(HapticFeedback.selectionClick());
                  onTap!();
                },
          borderRadius: BorderRadius.circular(AppRadii.chip),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s8,
            ),
            child: Align(
              widthFactor: 1,
              child: Text(
                label,
                style: AppTypography.meta(
                  selected ? palette.onPrimary : palette.text,
                  size: 13,
                  weight: enabled ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TindaSegmentedControl<T> extends StatelessWidget {
  const TindaSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Map<T, String> segments;

  final T selected;

  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          for (final entry in segments.entries)
            Expanded(
              child: _SegmentButton(
                label: entry.value,
                isSelected: entry.key == selected,
                onTap: () {
                  if (entry.key != selected) {
                    unawaited(HapticFeedback.selectionClick());
                  }
                  onChanged(entry.key);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.touchTargetMin),
      child: Material(
        color: isSelected ? palette.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.smallButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.smallButton),
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s8,
              ),
              child: AdaptiveTextScale(
                maxScale: AdaptiveLayout.maxChromeTextScale,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: AppTypography.meta(
                      isSelected ? palette.onPrimary : palette.text,
                      size: 13,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TindaStepper extends StatelessWidget {
  const TindaStepper({
    required this.valueLabel,
    required this.onDecrement,
    required this.decrementTooltip,
    this.onIncrement,
    required this.incrementTooltip,
    super.key,
    this.onValueTap,
  });

  final String valueLabel;

  final VoidCallback? onDecrement;

  final VoidCallback? onIncrement;

  final String decrementTooltip;

  final String incrementTooltip;

  final VoidCallback? onValueTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: palette.borderStrong, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            tooltip: decrementTooltip,
            icon: const Icon(Icons.remove),
            constraints: const BoxConstraints(
              minWidth: AppSizes.touchTargetMin,
              minHeight: AppSizes.touchTargetMin,
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s12,
              ),
              child: InkWell(
                onTap: onValueTap,
                borderRadius: BorderRadius.circular(AppRadii.smallButton),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.s4,
                    vertical: AppSpacing.s4,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valueLabel,
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.bodyStrong(
                        palette.text,
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            tooltip: incrementTooltip,
            icon: const Icon(Icons.add),
            constraints: const BoxConstraints(
              minWidth: AppSizes.touchTargetMin,
              minHeight: AppSizes.touchTargetMin,
            ),
          ),
        ],
      ),
    );
  }
}

class TindaToggleSwitch extends StatelessWidget {
  const TindaToggleSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: palette.primary,
      activeThumbColor: palette.onPrimary,
      inactiveTrackColor: palette.textMuted.withValues(alpha: 0.45),
      inactiveThumbColor: palette.surface,
    );
  }
}
