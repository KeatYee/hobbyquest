import 'package:flutter/material.dart';

class AppColors {
  // 🦊 BRAND COLORS (Warm & Energetic)
  // The main Fox color. High energy.
  static const Color primary = Color(0xFFF9862D); 
  // A darker shade for gradients/shadows to give depth (3D effect)
  static const Color primaryDark = Color(0xFFE65100); 
  // A lighter tint for subtle highlights
  static const Color primaryLight = Color(0xFFFFCC80);

  // ⚡ ACCENT COLORS (Complementary)
  // Electric Blue: Opposite of Orange. Used for XP bars and "Tech" elements.
  static const Color accent = Color(0xFF2979FF); 
  // Gold: For Rewards, Coins, and Achievements.
  static const Color gold = Color(0xFFFFD600);
  // Success Green: Vibrant, not dull.
  static const Color success = Color(0xFF00C853);
  // Error Red: For alerts and validation errors.
  static const Color error = Color(0xFFE53935);

  // 🌫️ NEUTRALS (The Canvas)
  // Cool Grey Background: Makes the Orange pop more than pure white.
  static const Color background = Color(0xFFF4F5F9); 
  // Pure White: For Cards to create depth against the background.
  static const Color surface = Color(0xFFFFFFFF);
  
  // 🖊️ TEXT COLORS
  // Dark Navy: Softer on the eyes than pure black (#000000).
  static const Color textPrimary = Color(0xFF2D3142); 
  // Medium Grey: For subtitles.
  static const Color textSecondary = Color(0xFF9094A6);
  // White text for buttons.
  static const Color textOnPrimary = Colors.white;
  // Shadow for text depth (approx 25% opacity black)
  static const Color textShadow = Color(0x26000000); 
}