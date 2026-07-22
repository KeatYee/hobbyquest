import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFD46A36);
  static const Color primaryDark = Color(0xFFA34D24);
  static const Color primaryLight = Color(0xFFF7E1D7);

  static const Color secondary = Color(0xFFDBA850);
  static const Color accent = Color(0xFFCD7D60);
  static const Color success = Color(0xFF5A8B5C);
  static const Color warning = Color(0xFFC2883A);
  static const Color error = Color(0xFFB85450);
  static const Color info = Color(0xFF6A9BB8);

  static const Color background = Color(0xFFFAF6F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3EEE7);
  static const Color border = Color(0xFFE6E2DB);
  static const Color borderStrong = Color(0xFFD3C8BB);

  static const Color textPrimary = Color(0xFF232D33);
  static const Color textSecondary = Color(0xFF7A8B94);
  static const Color textDisabled = Color(0xFFABB5BA);
  static const Color textOnPrimary = Colors.white;
  static const Color textShadow = Color(0x26000000);
  static const Color softShadow = Color(0x0D000000);

  // Keeps celebratory and progress visuals inside the same warm palette.
  static const List<Color> celebration = <Color>[
    primary,
    secondary,
    accent,
    success,
    info,
  ];

  // Growth letters intentionally use a paper treatment, but remain tokens.
  static const Color letterPaper = Color(0xFFFFFBEE);
  static const Color letterPaperEdge = Color(0xFFE8D8B8);
  static const Color letterInk = Color(0xFF3B342D);
  static const Color letterRule = Color(0xFFEEDFC3);
  static const Color letterStampShadow = Color(0x1A6E4D2A);
}
