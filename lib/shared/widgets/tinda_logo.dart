import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TindaLogoMark extends StatelessWidget {
  const TindaLogoMark({
    super.key,
    this.size = 40,
    this.onDarkHeader = false,
  });

  final double size;

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

class TindaWordmark extends StatelessWidget {
  const TindaWordmark({
    super.key,
    this.fontSize = 20,
    this.onDarkHeader = true,
  });

  final double fontSize;

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
