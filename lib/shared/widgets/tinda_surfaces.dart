import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Standard card (`surface`, 1 px `border`, 16 dp radius).
class TindaCard extends StatelessWidget {
  /// Creates a card.
  const TindaCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.s16),
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  /// Card content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Optional background override (e.g. `dangerSoft`).
  final Color? backgroundColor;

  /// Optional border override.
  final Color? borderColor;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: BorderSide(color: borderColor ?? palette.border),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: isDark ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: backgroundColor ?? palette.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  unawaited(HapticFeedback.selectionClick());
                  onTap!();
                },
          customBorder: shape,
          splashColor: palette.primary.withValues(alpha: 0.14),
          highlightColor: palette.primary.withValues(alpha: 0.08),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// List row (min 64 dp height) with title, meta, and trailing widget.
class TindaListRow extends StatelessWidget {
  /// Creates a list row.
  const TindaListRow({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  /// Primary label.
  final String title;

  /// Secondary meta text.
  final String? subtitle;

  /// Optional leading widget.
  final Widget? leading;

  /// Optional trailing action or badge.
  final Widget? trailing;

  /// Optional row tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return TindaCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyStrong(palette.text),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      subtitle!,
                      style: AppTypography.meta(palette.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.s12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Top header bar for tabs (`header` fill, title 20/800, action icons).
class TindaHeaderBar extends StatelessWidget {
  /// Creates a header bar.
  const TindaHeaderBar({
    required this.title,
    super.key,
    this.leading,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  });

  /// Screen title.
  final Widget title;

  /// Optional leading widget (e.g. logo mark).
  final Widget? leading;

  /// Optional subtitle (e.g. store name).
  final String? subtitle;

  /// Trailing icon buttons.
  final List<Widget> actions;

  /// Optional extra widget below the title row (e.g. segmented control).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: palette.header,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenHorizontal,
            AppSpacing.s12,
            AppSpacing.screenHorizontal,
            AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.s10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle(
                          style: AppTypography.title(palette.onHeader),
                          child: title,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            style: AppTypography.meta(
                              palette.onHeader.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final action in actions) ...[
                    const SizedBox(width: AppSpacing.s8),
                    action,
                  ],
                ],
              ),
              if (bottom != null) ...[
                const SizedBox(height: AppSpacing.s12),
                bottom!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Status badge (normal = `surfaceMuted`, low = `accentSoft`, danger = `dangerSoft`).
class TindaBadge extends StatelessWidget {
  /// Creates a badge.
  const TindaBadge({
    required this.label,
    super.key,
    this.isWarning = false,
    this.isDanger = false,
  });

  /// Badge text.
  final String label;

  /// Uses `accentSoft` / `onAccentSoft`.
  final bool isWarning;

  /// Uses `dangerSoft` / `danger`.
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final background = isDanger
        ? palette.dangerSoft
        : isWarning
            ? palette.accentSoft
            : palette.surfaceMuted;
    final foreground = isDanger
        ? palette.danger
        : isWarning
            ? palette.onAccentSoft
            : palette.textMuted;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.smallButton),
      ),
      child: Text(
        label,
        style: AppTypography.meta(
          foreground,
          size: 13,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Centered empty state with 72 dp icon circle, title, and muted explanation.
class TindaEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const TindaEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.action,
  });

  /// Center icon.
  final IconData icon;

  /// Headline.
  final String title;

  /// Supporting text.
  final String body;

  /// Optional CTA widget.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: palette.primary),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong(
                palette.text,
                size: 18,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.body(palette.textMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.s16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Warning banner (`accentSoft` fill, 14 dp radius).
class TindaBanner extends StatelessWidget {
  /// Creates a banner.
  const TindaBanner({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.trailing,
  });

  /// Leading icon.
  final IconData icon;

  /// Banner title.
  final String title;

  /// Banner explanation.
  final String body;

  /// Optional trailing action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.onAccentSoft, size: 20),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyStrong(
                    palette.onAccentSoft,
                    size: 14,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  body,
                  style: AppTypography.meta(palette.onAccentSoft, size: 13),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Floating dark cart bar on POS (`text` fill, 16 dp radius).
class TindaCartBar extends StatelessWidget {
  /// Creates a cart bar.
  const TindaCartBar({
    required this.itemsLabel,
    required this.totalLabel,
    required this.payLabel,
    required this.onPay,
    super.key,
  });

  /// e.g. "3 items".
  final String itemsLabel;

  /// Formatted total e.g. "₱125.00".
  final String totalLabel;

  /// Pay button label.
  final String payLabel;

  /// Pay tap handler.
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? palette.surfaceMuted : palette.text;
    final foreground = isDark ? palette.text : palette.surface;
    final subtitleColor = isDark
        ? palette.textMuted
        : palette.surface.withValues(alpha: 0.8);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: isDark ? BorderSide(color: palette.border) : BorderSide.none,
      ),
      elevation: 8,
      shadowColor: palette.primary.withValues(alpha: 0.32),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.s16,
          AppSpacing.s10,
          AppSpacing.s10,
          AppSpacing.s10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      itemsLabel,
                      key: ValueKey(itemsLabel),
                      style: AppTypography.meta(subtitleColor),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      totalLabel,
                      key: ValueKey(totalLabel),
                      style: AppTypography.title(foreground),
                    ),
                  ),
                ],
              ),
            ),
            TindaAccentButton(label: payLabel, onPressed: onPay),
          ],
        ),
      ),
    );
  }
}

/// Single rounded card grouping list rows separated by hairline dividers.
class TindaGroupedCard extends StatelessWidget {
  /// Creates a grouped list card.
  const TindaGroupedCard({required this.children, super.key});

  /// Row widgets placed inside the card.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: isDark ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) Divider(height: 1, thickness: 1, color: palette.surfaceMuted),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet wrapper with handle, title, close button, and optional footer.
class TindaBottomSheet extends StatelessWidget {
  /// Creates a bottom sheet container.
  const TindaBottomSheet({
    required this.title,
    required this.closeTooltip,
    required this.child,
    super.key,
    this.footer,
  });

  /// Sheet title.
  final String title;

  /// Close button tooltip.
  final String closeTooltip;

  /// Scrollable body content.
  final Widget child;

  /// Pinned footer (typically `TindaPrimaryButton`).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheetTop),
        ),
      ),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.s10),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: palette.borderStrong,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.sheetPadding,
                AppSpacing.s12,
                AppSpacing.sheetPadding,
                AppSpacing.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppTypography.title(palette.text)),
                  ),
                  TindaIconButton(
                    icon: Icons.close,
                    tooltip: closeTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sheetPadding,
                  vertical: AppSpacing.s8,
                ),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsetsDirectional.all(
                  AppSpacing.sheetPadding,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}


/// Rounded skeleton placeholder block with subtle shimmer.
class TindaSkeleton extends StatefulWidget {
  /// Creates a skeleton block.
  const TindaSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  /// Optional fixed width.
  final double? width;

  /// Block height.
  final double height;

  /// Optional corner radius.
  final BorderRadius? borderRadius;

  @override
  State<TindaSkeleton> createState() => _TindaSkeletonState();
}

class _TindaSkeletonState extends State<TindaSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final base = palette.surfaceMuted;
    final highlight = palette.surface;
    final radius = widget.borderRadius ??
        BorderRadius.circular(AppRadii.smallButton);

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (2.0 * t), 0),
              end: Alignment(1.0 + (2.0 * t), 0),
              colors: [base, highlight, base],
              stops: const [0.2, 0.5, 0.8],
            ),
          ),
        );
      },
    );
  }
}

/// Simple list-loading skeleton for card/list screens.
class TindaListSkeleton extends StatelessWidget {
  /// Creates a list skeleton.
  const TindaListSkeleton({super.key, this.rows = 5});

  /// Number of placeholder rows.
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rows; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.s10),
          const TindaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TindaSkeleton(width: 180, height: 14),
                SizedBox(height: AppSpacing.s8),
                TindaSkeleton(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
