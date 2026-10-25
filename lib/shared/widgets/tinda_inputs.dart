import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Labeled form input with 1.5 px borderStrong outline and 14 dp radius.
class TindaTextInput extends StatelessWidget {
  /// Creates a labeled text input.
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

  /// Label displayed above the field.
  final String label;

  /// Text controller.
  final TextEditingController? controller;

  /// Placeholder text.
  final String? hintText;

  /// Inline error displayed below the field.
  final String? errorText;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Keyboard action.
  final TextInputAction? textInputAction;

  /// Change listener.
  final ValueChanged<String>? onChanged;

  /// Submit listener.
  final ValueChanged<String>? onSubmitted;

  /// Optional trailing action inside the field.
  final Widget? suffixIcon;

  /// Whether to focus on mount.
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

/// 46 dp search bar with leading search icon and optional clear button.
class TindaSearchField extends StatelessWidget {
  /// Creates a search field.
  const TindaSearchField({
    required this.hintText,
    required this.onChanged,
    super.key,
    this.controller,
  });

  /// Placeholder hint.
  final String hintText;

  /// Change callback.
  final ValueChanged<String> onChanged;

  /// Optional controller.
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

/// Filter chip (40 dp height, 20 dp radius).
class TindaFilterChip extends StatelessWidget {
  /// Creates a filter chip.
  const TindaFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// Chip text.
  final String label;

  /// Whether the chip is selected.
  final bool selected;

  /// Tap callback.
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

/// 2-3 equal segments (44-48 dp height).
class TindaSegmentedControl<T> extends StatelessWidget {
  /// Creates a segmented control.
  const TindaSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// Map of value -> display label.
  final Map<T, String> segments;

  /// Currently selected value.
  final T selected;

  /// Selection callback.
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
              child: Text(
                label,
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
    );
  }
}

/// Outlined pill stepper with 44x44 minus/plus buttons.
class TindaStepper extends StatelessWidget {
  /// Creates a stepper.
  const TindaStepper({
    required this.valueLabel,
    required this.onDecrement,
    required this.decrementTooltip,
    this.onIncrement,
    required this.incrementTooltip,
    super.key,
    this.onValueTap,
  });

  /// Formatted current value.
  final String valueLabel;

  /// Decrement handler; null disables minus.
  final VoidCallback? onDecrement;

  /// Increment handler.
  final VoidCallback? onIncrement;

  /// Accessibility label for decrement.
  final String decrementTooltip;

  /// Accessibility label for increment.
  final String incrementTooltip;

  /// Optional tap handler for the value label (e.g. open numeric entry).
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
          Padding(
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
                child: Text(
                  valueLabel,
                  style: AppTypography.bodyStrong(
                    palette.text,
                    size: 18,
                    weight: FontWeight.w700,
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

/// Accessible toggle switch (44 dp min tap area).
class TindaToggleSwitch extends StatelessWidget {
  /// Creates a toggle switch.
  const TindaToggleSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Current state.
  final bool value;

  /// Change handler.
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
