import 'package:material_ui/material_ui.dart';

enum AppPalette {
  light._(
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
  ),
  dark._(
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

  new _({
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

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  final Color background;

  final Color surface;

  final Color surfaceMuted;

  final Color border;

  final Color borderStrong;

  final Color text;

  final Color textMuted;

  final Color primary;

  final Color onPrimary;

  final Color header;

  final Color onHeader;

  final Color accent;

  final Color onAccent;

  final Color accentSoft;

  final Color onAccentSoft;

  final Color danger;

  final Color dangerSoft;

  final Color success;

  final Color scrim;
}
