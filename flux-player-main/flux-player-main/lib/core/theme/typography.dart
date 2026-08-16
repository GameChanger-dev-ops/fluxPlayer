import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Inter for UI, Playfair Display for titles.
abstract final class FluxTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    return GoogleFonts.interTextTheme()
        .copyWith(
          displayLarge: GoogleFonts.playfairDisplay(
              fontSize: 40, fontWeight: FontWeight.w700, color: primary),
          displayMedium: GoogleFonts.playfairDisplay(
              fontSize: 32, fontWeight: FontWeight.w700, color: primary),
          headlineMedium: GoogleFonts.playfairDisplay(
              fontSize: 24, fontWeight: FontWeight.w600, color: primary),
          titleLarge: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w600, color: primary),
          titleMedium: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: primary),
          bodyLarge: GoogleFonts.inter(fontSize: 16, color: primary),
          bodyMedium: GoogleFonts.inter(fontSize: 14, color: secondary),
          labelSmall: GoogleFonts.inter(
              fontSize: 11, letterSpacing: 0.4, color: secondary),
        )
        .apply(bodyColor: primary, displayColor: primary);
  }
}
