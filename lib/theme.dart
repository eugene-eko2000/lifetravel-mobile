import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF171717);
  static const foreground = Color(0xFFEDEDED);
  static const surface = Color(0xFF212121);
  static const surfaceHover = Color(0xFF2A2A2A);
  static const border = Color(0xFF333333);
  static const muted = Color(0xFF888888);
  static const accent = Color(0xFF10A37F);
  static const userBubble = Color(0xFF2F2F2F);
  static const sendButton = Color(0xFF2563EB); // blue-600
  static const sendButtonHover = Color(0xFF1D4ED8); // blue-700
  static const emeraldBorder = Color(0xB3059669); // emerald-600/70
  static const emeraldBg = Color(0x1710B981); // emerald-500/[0.09]
  static const debugColor = Color(0xFF9CA3AF);
  static const warningColor = Color(0xFFFACC15);
  static const errorColor = Color(0xFFEF4444);
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.accent,
      onSurface: AppColors.foreground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.foreground,
      elevation: 0,
      centerTitle: true,
    ),
    dividerColor: AppColors.border,
    cardColor: AppColors.surface,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.foreground),
      bodyMedium: TextStyle(color: AppColors.foreground),
      bodySmall: TextStyle(color: AppColors.muted),
      labelSmall: TextStyle(color: AppColors.muted, fontSize: 10),
    ),
  );
}
