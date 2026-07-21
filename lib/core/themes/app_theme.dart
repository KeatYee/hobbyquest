import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/color_constants.dart';
import '../constants/font_constants.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      background: AppColors.background,
    ),

    textTheme: TextTheme(
      displayLarge: GoogleFonts.fredoka(
        fontSize: AppFonts.logo,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
        letterSpacing: 2.0,
      ),
      
      headlineLarge: GoogleFonts.openSans(
        fontSize: AppFonts.titlePage,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      
      bodyLarge: GoogleFonts.openSans(
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.openSans(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      
      labelLarge: GoogleFonts.openSans(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.openSans(
          fontSize: AppFonts.title, 
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.openSans(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.all(20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: GoogleFonts.openSans(color: AppColors.textSecondary),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: GoogleFonts.openSans(
        color: AppColors.textPrimary,
        fontSize: AppFonts.titleLg,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}