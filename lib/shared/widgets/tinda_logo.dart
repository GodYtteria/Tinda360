import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the Tinda 360 storefront-in-ring SVG logo mark from `assets/logo/`.
class TindaLogoMark extends StatelessWidget {
  /// Creates the logo mark.
  const TindaLogoMark({
    super.key,
    this.size = 40,
    this.onDarkHeader = false,
  });

  /// Square dimension of the mark.
  final double size;

  /// Whether the mark sits on the dark green header/splash background.
  final bool onDarkHeader;

  @override
  Widget build(BuildContext context) {
    final asset = onDarkHeader
        ? 'assets/logo/logo_mark_on_green.svg'
        : 'assets/logo/logo_mark.svg';
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
    );
  }
}

/// Renders the "Tinda 360" SVG wordmark from `assets/logo/`.
class TindaWordmark extends StatelessWidget {
  /// Creates the wordmark.
  const TindaWordmark({
    super.key,
    this.fontSize = 20,
    this.onDarkHeader = true,
  });

  /// Reference height scale for the wordmark.
  final double fontSize;

  /// Whether the wordmark sits on the dark green header.
  final bool onDarkHeader;

  @override
  Widget build(BuildContext context) {
    final asset = onDarkHeader
        ? 'assets/logo/wordmark_on_green.svg'
        : 'assets/logo/wordmark.svg';
    return SvgPicture.asset(
      asset,
      height: fontSize * 1.15,
      fit: BoxFit.contain,
    );
  }
}
