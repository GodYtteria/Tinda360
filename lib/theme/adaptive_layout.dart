import 'package:flutter/material.dart';

enum AdaptiveWidth {
  compact,
  regular,
  wide;

  static AdaptiveWidth ofWidth(double width) {
    if (width < AdaptiveLayout.compactMaxWidth) return AdaptiveWidth.compact;
    if (width < AdaptiveLayout.regularMaxWidth) return AdaptiveWidth.regular;
    return AdaptiveWidth.wide;
  }

  static AdaptiveWidth of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);
}

abstract final class AdaptiveLayout {
  static const double compactMaxWidth = 360;

  static const double regularMaxWidth = 600;

  static const double maxContentWidth = 720;

  static const double maxAppTextScale = 1.3;

  static const double minAppTextScale = 1.0;

  static const double maxChromeTextScale = 1.15;

  static const double largeTextThreshold = 1.2;

  static const double floatingButtonClearance = 96;

  static const double textScaleProbeSize = 10;

  static double textScaleOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(textScaleProbeSize) /
      textScaleProbeSize;

  static bool isTight(BuildContext context) =>
      AdaptiveWidth.of(context) == AdaptiveWidth.compact ||
      textScaleOf(context) > largeTextThreshold;

  static TextScaler clampedScaler(
    TextScaler source, {
    double maxScale = maxAppTextScale,
  }) => source.clamp(minScaleFactor: minAppTextScale, maxScaleFactor: maxScale);
}

class AdaptiveTextScale extends StatelessWidget {
  const AdaptiveTextScale({
    required this.child,
    super.key,
    this.maxScale = AdaptiveLayout.maxAppTextScale,
  });

  final Widget child;

  final double maxScale;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: AdaptiveLayout.clampedScaler(
          mediaQuery.textScaler,
          maxScale: maxScale,
        ),
      ),
      child: child,
    );
  }
}
