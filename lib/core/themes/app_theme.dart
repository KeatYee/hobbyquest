import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/color_constants.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // 🎨 Global Colors
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    
    // 🌈 Color Scheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
      background: AppColors.background,
    ),

    // 🔤 GLOBAL TEXT THEME
    textTheme: TextTheme(
      // ✅ ONLY FOR LOGO: "HOBBY QUEST" (Fredoka)
      displayLarge: GoogleFonts.fredoka(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
        letterSpacing: 2.0,
      ),
      
      // All other headers: Open Sans (Clean & Modern)
      headlineLarge: GoogleFonts.openSans(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      
      // Body Text: Open Sans
      bodyLarge: GoogleFonts.openSans(
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.openSans(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      
      // Button Text: Open Sans (Readable)
      labelLarge: GoogleFonts.openSans(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),

    // 🔘 Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 4,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // Use Open Sans for Buttons
        textStyle: GoogleFonts.openSans(
          fontSize: 18, 
          fontWeight: FontWeight.w800, // Extra Bold
        ),
      ),
    ),

    // ⭕ Outline Buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // Use Open Sans for Buttons
        textStyle: GoogleFonts.openSans(
          fontSize: 16,
          fontWeight: FontWeight.w800, // Extra Bold
        ),
      ),
    ),

    // ⬜ Input Fields
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
      // Use Open Sans for labels
      labelStyle: GoogleFonts.openSans(color: AppColors.textSecondary),
    ),

    // 🧊 AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      // Use Open Sans for page titles (Navigation)
      titleTextStyle: GoogleFonts.openSans(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}