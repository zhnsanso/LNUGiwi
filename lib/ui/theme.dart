import 'package:flutter/material.dart';

import 'shape.dart';
import 'typography.dart';

/// 品牌主色（金黄，取自参考图标）
const Color kBrandPrimary = Color(0xFFF3D223);

/// 品牌辅色（琥珀），用于渐变
const Color kBrandAccent = Color(0xFFF59E0B);

/// 品牌深色前景（深藏青，用于黄色渐变上的文字/图标）
const Color kBrandInk = Color(0xFF192944);

/// 深藏青 72% 透明度（黄色渐变上的副标题）
const Color kBrandInkSoft = Color(0xB8192944);

/// 品牌渐变（金黄 → 琥珀，页头 / 主按钮）
const LinearGradient kBrandGradient = LinearGradient(
  colors: <Color>[kBrandPrimary, kBrandAccent],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// 全局主题（浅色 / 深色），卡片、输入框、按钮统一样式。
ThemeData buildGiWiFiTheme([Brightness brightness = Brightness.light]) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandPrimary,
    brightness: brightness,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: const BorderRadius.all(AppRadius.md),
    borderSide: BorderSide(
      color: isDark ? Colors.transparent : const Color(0xFFE3E8F2),
    ),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'MiSans',
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? null : const Color(0xFFF2F5FB),
    splashFactory: InkRipple.splashFactory,
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: AppShape.card,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? scheme.surfaceContainerHigh : const Color(0xFFF1F4FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: .55),
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: AppShape.md,
        textStyle: AppTextStyle.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: AppShape.md,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: AppTextStyle.button,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: AppShape.md,
    ),
  );
}
