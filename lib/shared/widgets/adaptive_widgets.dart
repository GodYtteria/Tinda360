import 'package:flutter/material.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/theme/adaptive_layout.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class MoneyText extends StatelessWidget {
  MoneyText(
    Money money, {
    required this.style,
    super.key,
    this.alignment = AlignmentDirectional.centerStart,
  }) : text = formatMoney(money);

  const MoneyText.text(
    this.text, {
    required this.style,
    super.key,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final String text;

  final TextStyle style;

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: style.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class AdaptiveBadges extends StatelessWidget {
  const AdaptiveBadges({
    required this.content,
    required this.badges,
    super.key,
  });

  final Widget content;

  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return content;
    if (AdaptiveLayout.isTight(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: AppSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s4,
              children: badges,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: content),
        const SizedBox(width: AppSpacing.s12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < badges.length; index++) ...[
                if (index > 0) const SizedBox(height: AppSpacing.s4),
                badges[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class TindaScreenBody extends StatelessWidget {
  const TindaScreenBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AdaptiveLayout.maxContentWidth,
      ),
      child: child,
    ),
  );

  static double floatingBottomPadding(BuildContext context) =>
      AdaptiveLayout.floatingButtonClearance *
      AdaptiveLayout.textScaleOf(context).clamp(1.0, 1.5);
}

class ResponsiveSheetBody extends StatelessWidget {
  const ResponsiveSheetBody({
    required this.child,
    super.key,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.s24),
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

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
        child: SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AdaptiveLayout.maxContentWidth,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
