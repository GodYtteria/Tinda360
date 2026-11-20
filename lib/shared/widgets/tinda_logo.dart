import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/theme/app_palette.dart';

class TindaLogoMark extends StatelessWidget {
  const new({
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
  const new({
    super.key,
    this.fontSize = 20,
    this.onDarkHeader = true,
  });

  static const FontWeight _weight = FontWeight.w800;
  static const double _letterSpacingPerPoint = -0.02;

  final double fontSize;

  final bool onDarkHeader;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final title = AppLocalizations.of(context).appTitle;
    final splitAt = title.lastIndexOf(' ');
    final name = splitAt < 0 ? title : title.substring(0, splitAt + 1);
    final number = splitAt < 0 ? '' : title.substring(splitAt + 1);
    return Text.rich(
      TextSpan(
        text: name,
        children: [
          TextSpan(
            text: number,
            style: TextStyle(color: palette.accent),
          ),
        ],
      ),
      maxLines: 1,
      semanticsLabel: title,
      style: TextStyle(
        color: onDarkHeader ? palette.onHeader : palette.text,
        fontSize: fontSize,
        fontWeight: _weight,
        letterSpacing: fontSize * _letterSpacingPerPoint,
      ),
    );
  }
}
