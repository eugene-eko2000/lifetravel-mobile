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

  /// Displayed prompt above itinerary (matches web `bg-user-bubble/80`, `border-border/80`).
  static const double userPromptDisplayOpacity = 0.8;
  static Color get userBubbleDisplay => userBubble.withValues(alpha: userPromptDisplayOpacity);
  static Color get borderPromptDisplay => border.withValues(alpha: userPromptDisplayOpacity);

  /// Matches web `shadow-[0_10px_40px_-10px_rgba(0,0,0,0.55),0_4px_14px_-4px_rgba(0,0,0,0.35)]`.
  static List<BoxShadow> get userPromptBubbleShadows => const [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.55),
          blurRadius: 40,
          spreadRadius: -10,
          offset: Offset(0, 10),
        ),
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.35),
          blurRadius: 14,
          spreadRadius: -4,
          offset: Offset(0, 4),
        ),
      ];

  static const sendButton = Color(0xFF2563EB); // blue-600
  static const sendButtonHover = Color(0xFF1D4ED8); // blue-700

  /// Matches web travel UI (`bg-*/70`, `border-*/70`).
  static const double travelLayerOpacity = 0.7;

  static Color travel(Color base) => base.withValues(alpha: travelLayerOpacity);

  static Color get travelSurface => travel(surface);
  static Color get travelBackground => travel(background);
  static Color get travelBorder => travel(border);

  static const Color _emerald500 = Color(0xFF10B981);
  static const Color _emerald950 = Color(0xFF022C22);
  static Color get travelEmeraldBorder => travel(_emerald500);
  static Color get travelEmeraldBg => travel(_emerald950);
  static const debugColor = Color(0xFF9CA3AF);
  static const warningColor = Color(0xFFFACC15);
  static const errorColor = Color(0xFFEF4444);
}

/// Chat list uses translucent [AppColors.travel*] layers; full-screen trip modal uses 100% opacity.
class TripLayers {
  final bool opaque;
  const TripLayers._(this.opaque);

  factory TripLayers.of(bool opaque) => TripLayers._(opaque);

  Color get background => opaque ? AppColors.background : AppColors.travelBackground;
  Color get surface => opaque ? AppColors.surface : AppColors.travelSurface;
  Color get border => opaque ? AppColors.border : AppColors.travelBorder;

  Color get mutedBand =>
      opaque ? AppColors.muted.withValues(alpha: 0.28) : AppColors.travel(AppColors.muted);

  static const Color _emeraldBorderSolid = Color(0xFF10B981);
  static const Color _emeraldFillSolid = Color(0xFF022C22);

  Color emeraldOptionBorder(bool isTop) =>
      isTop ? (opaque ? _emeraldBorderSolid : AppColors.travelEmeraldBorder) : border;

  Color emeraldOptionFill(bool isTop) =>
      isTop ? (opaque ? _emeraldFillSolid : AppColors.travelEmeraldBg) : background;
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
