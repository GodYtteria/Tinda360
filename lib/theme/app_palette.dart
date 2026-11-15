import 'package:flutter/material.dart';

/// The color tokens from the design's "Mga kulay (light / dark)" board.
/// The only file in the app that holds raw color values.
final class AppPalette {
  const AppPalette._({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.header,
    required this.onHeader,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.scrim,
  });

  /// Resolves the active palette from [context] brightness.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Light mode tokens.
  static const AppPalette light = AppPalette._(
    background: Color(0xFFF6F8F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF3F1),
    border: Color(0xFFE3E9E6),
    borderStrong: Color(0xFFC9D3CF),
    text: Color(0xFF14201C),
    textMuted: Color(0xFF5B6B66),
    primary: Color(0xFF0F5C4A),
    onPrimary: Color(0xFFFFFFFF),
    header: Color(0xFF0F5C4A),
    onHeader: Color(0xFFFFFFFF),
    accent: Color(0xFFF2A23A),
    onAccent: Color(0xFF14201C),
    accentSoft: Color(0xFFFDEBD3),
    onAccentSoft: Color(0xFF6B3D06),
    danger: Color(0xFFA3341F),
    dangerSoft: Color(0xFFFBEAE6),
    success: Color(0xFF1E8A6E),
    scrim: Color(0x7314201C),
  );

  /// Dark mode tokens.
  static const AppPalette dark = AppPalette._(
    background: Color(0xFF131C19),
    surface: Color(0xFF1C2924),
    surfaceMuted: Color(0xFF24342E),
    border: Color(0xFF344941),
    borderStrong: Color(0xFF425C52),
    text: Color(0xFFEAF1EE),
    textMuted: Color(0xFFA7B8B2),
    primary: Color(0xFF44C79F),
    onPrimary: Color(0xFF0E1513),
    header: Color(0xFF153C33),
    onHeader: Color(0xFFEAF1EE),
    accent: Color(0xFFF2A23A),
    onAccent: Color(0xFF14201C),
    accentSoft: Color(0xFF3F3019),
    onAccentSoft: Color(0xFFF6C88A),
    danger: Color(0xFFF08A73),
    dangerSoft: Color(0xFF3E2019),
    success: Color(0xFF44C79F),
    scrim: Color(0x99000000),
  );

  /// Screen background.
  final Color background;

  /// Cards and sheets.
  final Color surface;

  /// Muted fills (chips, inputs).
  final Color surfaceMuted;

  /// Hairlines and outlines.
  final Color border;

  /// Input and secondary button outlines.
  final Color borderStrong;

  /// Main text.
  final Color text;

  /// Secondary text.
  final Color textMuted;

  /// Brand green; main buttons.
  final Color primary;

  /// Text and icons on [primary].
  final Color onPrimary;

  /// Top bar background.
  final Color header;

  /// Foreground text and icons on [header].
  final Color onHeader;

  /// Mango accent; the AI button and checkout.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Low-stock badge and warning banner background.
  final Color accentSoft;

  /// Text and icons on [accentSoft].
  final Color onAccentSoft;

  /// Debts and destructive actions.
  final Color danger;

  /// Utang balance card background.
  final Color dangerSoft;

  /// Positive states.
  final Color success;

  /// Modal barrier scrim behind sheets.
  final Color scrim;
}
