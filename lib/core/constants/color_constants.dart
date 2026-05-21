import 'package:flutter/material.dart';

class AppColors {
  // BRAND COLORS (Warm & Energetic)
  // The main Fox color. High energy.
  static const Color primary = Color(0xFFFF6B00); // Vibrant Orange
  // A darker shade for hover/pressed states
  static const Color primaryDark = Color(0xFFE85F00); // Deep Orange
  // A lighter tint for subtle highlights / glows
  static const Color primaryLight = Color(0xFFFFF0E5); // Soft Orange Glow

  // ACCENT & SEMANTIC COLORS
  // Secondary: Electric Yellow
  static const Color secondary = Color(0xFFFFC83D);
  // Accent: Neon Coral
  static const Color accent = Color(0xFFFF8A4C);
  // Success Green: Quest Green
  static const Color success = Color(0xFF22C55E);
  // Warning: Golden Amber
  static const Color warning = Color(0xFFF59E0B);
  // Error Red: Arcade Red
  static const Color error = Color(0xFFEF4444);
  // Info / Cyan energy
  static const Color info = Color(0xFF06B6D4);

  // NEUTRALS (The Canvas)
  // Cool Grey Background: Makes the Orange pop more than pure white.
  static const Color background = Color(0xFFF4F5F9); 
  // Pure White: For Cards to create depth against the background.
  static const Color surface = Color(0xFFFFFFFF);
  
  // TEXT COLORS
  // Dark Navy: Softer on the eyes than pure black (#000000).
  static const Color textPrimary = Color(0xFF2D3142); 
  // Medium Grey: For subtitles.
  static const Color textSecondary = Color(0xFF9094A6);
  // White text for buttons.
  static const Color textOnPrimary = Colors.white;
  // Shadow for text depth (approx 25% opacity black)
  static const Color textShadow = Color(0x26000000); 

  // Backwards-compatible alias: keep `gold` for places using it
  static const Color gold = secondary;
}