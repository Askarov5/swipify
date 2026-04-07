import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App themes: use [lightTheme] / [darkTheme] on [MaterialApp] and read colors via
/// `Theme.of(context).colorScheme` in widgets.
class SwipifyTheme {
  SwipifyTheme._();

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF45D8ED),
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF131313),
    onSurface: const Color(0xFFE5E2E1),
    surfaceContainerLow: const Color(0xFF1C1B1B),
    surfaceContainerHigh: const Color(0xFF2A2A2A),
    surfaceContainerHighest: const Color(0xFF353534),
    onSurfaceVariant: const Color(0xFFBDC9C8),
    primary: const Color(0xFF45D8ED),
    onPrimary: const Color(0xFF00363D),
    primaryContainer: const Color(0xFF007F8C),
    onPrimaryContainer: const Color(0xFFB2EBF2),
    secondary: const Color(0xFFFFB59F),
    onSecondary: const Color(0xFF3E0800),
    secondaryContainer: const Color(0xFF9E2B00),
    onSecondaryContainer: const Color(0xFFFFDAD4),
  );

  /// Light surfaces with the same brand teal/coral family.
  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF007F8C),
    brightness: Brightness.light,
  ).copyWith(
    surface: const Color(0xFFFCFCFC),
    onSurface: const Color(0xFF1C1B1B),
    surfaceContainerLow: const Color(0xFFF4F4F4),
    surfaceContainerHigh: const Color(0xFFEBEBEB),
    surfaceContainerHighest: const Color(0xFFE0E0E0),
    onSurfaceVariant: const Color(0xFF4A5F5E),
    primary: const Color(0xFF006B77),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFB2EBF2),
    onPrimaryContainer: const Color(0xFF00363D),
    secondary: const Color(0xFFB84D36),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFFFDAD4),
    onSecondaryContainer: const Color(0xFF5C1600),
  );

  static TextTheme _textThemeFor(ColorScheme scheme) {
    return TextTheme(
      displayLarge: GoogleFonts.manrope(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.manrope(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      headlineSmall: GoogleFonts.manrope(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleLarge: GoogleFonts.manrope(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.manrope(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: GoogleFonts.inter(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyMedium: GoogleFonts.inter(
        color: scheme.onSurfaceVariant,
        fontSize: 14,
        height: 1.4,
      ),
      bodyLarge: GoogleFonts.inter(
        color: scheme.onSurfaceVariant,
        fontSize: 16,
        height: 1.4,
      ),
    );
  }

  static ThemeData _themeData(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.surface,
      colorScheme: scheme,
      textTheme: _textThemeFor(scheme),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  static ThemeData get lightTheme => _themeData(_lightScheme);

  static ThemeData get darkTheme => _themeData(_darkScheme);
}
