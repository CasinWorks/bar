import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static TextStyle get _display => GoogleFonts.raleway(
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.textLight,
      );

  static TextStyle get _body => GoogleFonts.montserrat(
        color: AppColors.textLight,
      );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.matteBlack,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.tigerRed,
        secondary: AppColors.antiqueGold,
        surface: AppColors.charcoal,
        onPrimary: AppColors.offWhite,
        onSecondary: AppColors.matteBlack,
        onSurface: AppColors.offWhite,
        error: AppColors.dangerRed,
      ),
      textTheme: TextTheme(
        displayLarge: _display.copyWith(fontSize: 52, fontWeight: FontWeight.w800),
        displayMedium: _display.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
        headlineLarge: _display.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
        headlineMedium: _display.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        titleLarge: _body.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: _body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: _body.copyWith(fontSize: 14),
        bodyMedium: _body.copyWith(fontSize: 12, color: AppColors.textMuted),
        labelLarge: _display.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.tigerRed,
          letterSpacing: 1.8,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.matteBlack,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _display.copyWith(fontSize: 16, letterSpacing: 1.5),
        iconTheme: const IconThemeData(color: AppColors.tigerRed),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.charcoal,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkSteel),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkSteel),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.tigerRed, width: 1.5),
        ),
        hintStyle: _body.copyWith(color: AppColors.neutral500),
        labelStyle: _body.copyWith(color: AppColors.textMuted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.charcoal,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkSteel),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.charcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
