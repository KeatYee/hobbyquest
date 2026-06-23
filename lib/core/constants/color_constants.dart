import 'package:flutter/material.dart';

class AppColors {
  // BRAND COLORS (Warm & Earthy)
  // 主品牌色保留橙色，但调整为更柔和、自然的大地锈橙色
  static const Color primary = Color(0xFFD46A36); // Earthy Rust Orange
  // 深色状态调整为深焦橙色
  static const Color primaryDark = Color(0xFFA34D24); // Deep Burnt Orange
  // 浅色高光调整为柔和的肉粉/水蜜桃色光晕
  static const Color primaryLight = Color(0xFFF7E1D7); // Soft Peachy Glow

  // ACCENT & SEMANTIC COLORS
  // Secondary: 从刺眼的电光黄调整为柔和的芥末黄
  static const Color secondary = Color(0xFFDBA850); // Muted Mustard
  // Accent: 从霓虹珊瑚色调整为柔和的陶土色
  static const Color accent = Color(0xFFCD7D60); // Soft Clay
  // Success Green: 保留认可的自然叶绿色
  static const Color success = Color(0xFF5A8B5C); // Natural Leaf Green
  // Warning: 泥土质感的琥珀色
  static const Color warning = Color(0xFFC2883A); // Earthy Amber
  // Error Red: 柔和的大地红
  static const Color error = Color(0xFFB85450); // Muted Earthy Red
  // Info: 匹配参考图中天空和河流的柔和灰蓝色
  static const Color info = Color(0xFF6A9BB8); // Soft Slate Blue

  // NEUTRALS (The Canvas)
  // 暖霜色背景：模仿参考图中的纸张纹理和雪地质感
  static const Color background = Color(0xFFFAF6F0); 
  // 纯白：用于卡片表面，与背景形成层次
  static const Color surface = Color(0xFFFFFFFF);
  // 边框颜色：柔和的米色分割线
  static const Color border = Color(0xFFE6E2DB);
  
  // TEXT COLORS
  // 深石板灰/海军蓝：取代纯黑，与深色冷杉林色调一致，视觉更舒适
  static const Color textPrimary = Color(0xFF232D33); 
  // 中灰蓝色：用于副标题
  static const Color textSecondary = Color(0xFF7A8B94);
  // 按钮白色文本
  static const Color textOnPrimary = Colors.white;
  // 文本阴影 (25% 透明度黑色)
  static const Color textShadow = Color(0x26000000); 

  // Backwards-compatible alias: keep `gold` for places using it
  static const Color gold = secondary;
}