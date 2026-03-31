import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SwipifyTheme {
  // Brand Colors
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353534);

  static const Color primary = Color(0xFF45D8ED); // Teal Keep
  static const Color primaryContainer = Color(0xFF007F8C);
  static const Color onPrimary = Color(0xFF00363D);

  static const Color secondary = Color(0xFFFFB59F); // Coral Delete
  static const Color secondaryContainer = Color(0xFF9E2B00);

  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFBDC9C8);

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surface,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      primary: primary,
      secondary: secondary,
      onSurface: onSurface,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      titleMedium: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: GoogleFonts.inter(
        color: onSurfaceVariant,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1, // Technical specs feeling
      ),
      bodyMedium: GoogleFonts.inter(
        color: onSurfaceVariant,
        fontSize: 14,
        height: 1.4,
      ),
    ),
    // Kinetic Glass effect borders usually modeled via container not global theme,
    // but we can set up card theme for defaults without borders.
    cardTheme: const CardThemeData(
      color: surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24.0)), // xl
      ),
    ),
  );
}
