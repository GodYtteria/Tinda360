import 'package:flutter/material.dart';
import 'package:tinda360/theme/app_palette.dart';

/// Builds the light and dark Material themes from [AppPalette].
///
/// No font is bundled: Roboto is Android's system font. The "Tinda 360"
/// wordmark ships as a vector asset, not as a font.
abstract final class AppTheme {
  /// The light theme.
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  /// The dark theme.
  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      error: palette.danger,
      onError: palette.onPrimary,
      surface: palette.surface,
      onSurface: palette.text,
      onSurfaceVariant: palette.textMuted,
      outline: palette.border,
      surfaceContainerHighest: palette.surfaceMuted,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.header,
        foregroundColor: palette.onHeader,
      ),
    );
  }
}
