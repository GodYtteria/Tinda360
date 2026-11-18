import 'package:flutter/painting.dart';

abstract final class AppSpacing {
  static const double s4 = 4;

  static const double s8 = 8;

  static const double s10 = 10;

  static const double s12 = 12;

  static const double s14 = 14;

  static const double s16 = 16;

  static const double s18 = 18;

  static const double s20 = 20;

  static const double s24 = 24;

  static const double screenHorizontal = 20;

  static const double sheetPadding = 16;
}

abstract final class AppRadii {
  static const double smallButton = 10;

  static const double button = 12;

  static const double input = 14;

  static const double mainButton = 14;

  static const double card = 16;

  static const double chip = 20;

  static const double sheetTop = 24;
}

abstract final class AppSizes {
  static const double touchTargetMin = 44;

  static const double mainButtonHeight = 56;

  static const double secondaryButtonHeight = 52;

  static const double accentButtonHeight = 46;

  static const double inputHeight = 52;

  static const double searchHeight = 46;

  static const double chipHeight = 40;

  static const double bottomNavHeight = 72;

  static const double bottomNavLargeHeight = 84;

  static const double aiFab = 60;
}

abstract final class AppTypography {
  static TextStyle display(Color color, {double size = 30}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.15,
  );

  static TextStyle title(Color color) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.2,
  );

  static TextStyle section(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.78,
    color: color,
  );

  static TextStyle bodyStrong(
    Color color, {
    double size = 15,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.3);

  static TextStyle body(Color color, {double size = 14}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.4,
  );

  static TextStyle meta(
    Color color, {
    double size = 12,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.3);

  static TextStyle navLabel(Color color, {required bool active}) => TextStyle(
    fontSize: 11,
    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
    color: color,
  );
}
