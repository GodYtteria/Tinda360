import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class TindaCard extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.s16),
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

  final Color? backgroundColor;

  final Color? borderColor;

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

class TindaListRow extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;

  final String? subtitle;

  final Widget? leading;

  final Widget? trailing;

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

class TindaHeaderBar extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.leading,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.belowSubtitle,
  });

  final Widget title;

  final Widget? leading;

  final String? subtitle;

  final Widget? belowSubtitle;

  final List<Widget> actions;

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
                        ?belowSubtitle,
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

class TindaBadge extends StatelessWidget {
  const new({
    required this.label,
    super.key,
    this.isWarning = false,
    this.isDanger = false,
  });

  final String label;

  final bool isWarning;

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

class TindaEmptyState extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.action,
  });

  final IconData icon;

  final String title;

  final String body;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final content = Center(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return content;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}

class TindaBanner extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.trailing,
  });

  final IconData icon;

  final String title;

  final String body;

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
          ?trailing,
        ],
      ),
    );
  }
}

class TindaCartBar extends StatelessWidget {
  const new({
    required this.itemsLabel,
    required this.totalLabel,
    required this.payLabel,
    required this.onPay,
    super.key,
  });

  final String itemsLabel;

  final String totalLabel;

  final String payLabel;

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
                    child: SizedBox(
                      key: ValueKey(totalLabel),
                      width: double.infinity,
                      child: MoneyText.text(
                        totalLabel,
                        style: AppTypography.title(foreground),
                      ),
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

class TindaGroupedCard extends StatelessWidget {
  const new({required this.children, super.key});

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
            if (index > 0)
              Divider(height: 1, thickness: 1, color: palette.surfaceMuted),
            children[index],
          ],
        ],
      ),
    );
  }
}

class TindaBottomSheet extends StatelessWidget {
  const new({
    required this.title,
    required this.closeTooltip,
    required this.child,
    super.key,
    this.footer,
  });

  final String title;

  final String closeTooltip;

  final Widget child;

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
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title(palette.text),
                    ),
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.sizeOf(context).height *
                        _sheetFooterMaxHeightFraction,
                  ),
                  child: SingleChildScrollView(child: footer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const double _sheetFooterMaxHeightFraction = 0.4;

class TindaSkeleton extends StatefulWidget {
  const new({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;

  final double height;

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
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppRadii.smallButton);

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

class TindaListSkeleton extends StatelessWidget {
  const new({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
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
      ),
    );
  }
}
