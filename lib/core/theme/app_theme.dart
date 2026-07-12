import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.crimson,
        secondary: AppColors.goldBrushed,
        surface: AppColors.cardSurface,
        onPrimary: AppColors.textLight,
        onSecondary: AppColors.darkBackground,
        onSurface: AppColors.textLight,
        error: AppColors.dangerRed,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.shareTechMono(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 2,
        ),
        displayMedium: GoogleFonts.cinzel(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.textLight,
          letterSpacing: 2,
        ),
        headlineLarge: GoogleFonts.cinzel(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
        ),
        headlineMedium: GoogleFonts.cinzel(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textLight,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
        labelLarge: GoogleFonts.shareTechMono(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.goldBright,
          letterSpacing: 1.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cinzel(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 1,
        ),
        iconTheme: const IconThemeData(color: AppColors.goldBrushed),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral950,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.goldBrushed.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.goldBrushed.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.goldBrushed, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.neutral500),
        labelStyle: GoogleFonts.inter(color: AppColors.textMuted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.goldBrushed.withValues(alpha: 0.2)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.neutral950,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
