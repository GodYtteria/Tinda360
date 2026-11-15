import 'package:flutter/painting.dart';

/// Spacing scale from design-tokens.json.
abstract final class AppSpacing {
  /// 4 dp.
  static const double s4 = 4;

  /// 8 dp.
  static const double s8 = 8;

  /// 10 dp.
  static const double s10 = 10;

  /// 12 dp.
  static const double s12 = 12;

  /// 14 dp.
  static const double s14 = 14;

  /// 16 dp.
  static const double s16 = 16;

  /// 18 dp.
  static const double s18 = 18;

  /// 20 dp.
  static const double s20 = 20;

  /// 24 dp.
  static const double s24 = 24;

  /// Standard horizontal screen padding.
  static const double screenHorizontal = 20;

  /// Standard padding inside bottom sheets.
  static const double sheetPadding = 16;
}

/// Border radii from design-tokens.json.
abstract final class AppRadii {
  /// 10 dp.
  static const double smallButton = 10;

  /// 12 dp.
  static const double button = 12;

  /// 14 dp.
  static const double input = 14;

  /// 14 dp.
  static const double mainButton = 14;

  /// 16 dp.
  static const double card = 16;

  /// 20 dp.
  static const double chip = 20;

  /// 24 dp.
  static const double sheetTop = 24;
}

/// Component dimensions from design-tokens.json.
abstract final class AppSizes {
  /// Minimum accessible touch target.
  static const double touchTargetMin = 44;

  /// Primary action button height.
  static const double mainButtonHeight = 56;

  /// Secondary action button height.
  static const double secondaryButtonHeight = 52;

  /// Accent button height.
  static const double accentButtonHeight = 46;

  /// Standard text input height.
  static const double inputHeight = 52;

  /// Search field height.
  static const double searchHeight = 46;

  /// Filter chip height.
  static const double chipHeight = 40;

  /// Standard bottom navigation height.
  static const double bottomNavHeight = 72;

  /// Bottom navigation height when text scale is large.
  static const double bottomNavLargeHeight = 84;

  /// Tinda AI floating action button diameter.
  static const double aiFab = 60;
}

/// Typography helpers matching the design handoff.
abstract final class AppTypography {
  /// Display style (26-34 / 800).
  static TextStyle display(Color color, {double size = 30}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.15,
  );

  /// Screen and sheet title (20 / 800).
  static TextStyle title(Color color) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.2,
  );

  /// Settings section header (13 / 700, uppercase, +0.06em).
  static TextStyle section(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.78,
    color: color,
  );

  /// Product names and button labels (15-16 / 600-700).
  static TextStyle bodyStrong(
    Color color, {
    double size = 15,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.3);

  /// Body copy and chat messages (14-15 / 400).
  static TextStyle body(Color color, {double size = 14}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.4,
  );

  /// Captions, price/unit/stock meta (12-13 / 500-600).
  static TextStyle meta(
    Color color, {
    double size = 12,
    FontWeight weight = FontWeight.w500,
  }) => TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.3);

  /// Bottom navigation label (11 / 600 or 700).
  static TextStyle navLabel(Color color, {required bool active}) => TextStyle(
    fontSize: 11,
    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
    color: color,
  );
}
