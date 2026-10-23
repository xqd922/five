/// Material 3 主题配置：统一的设计令牌。
///
/// 集中管理所有 M3 组件的自定义样式，确保全局一致性。
/// 基于 https://m3.material.io/ 的规范：
/// - 色彩：种子色派生 + 语义色角色
/// - 排版：M3 字号阶梯
/// - 形状：M3 圆角令牌
/// - 间距：4dp 基础网格
library;

import 'package:flutter/material.dart';

/// M3 设计令牌常量。
abstract final class M3Tokens {
  // ---- 间距（4dp 网格） ----
  static const double spaceXXS = 2;
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXL = 24;
  static const double spaceXXL = 32;
  static const double spaceXXXL = 48;

  // ---- 圆角（M3 Shape 令牌） ----
  static const double shapeXS = 4; // extraSmall
  static const double shapeS = 8; // small
  static const double shapeM = 12; // medium
  static const double shapeL = 16; // large
  static const double shapeXL = 28; // extraLarge
  static const double shapeFull = 999; // full (pill)

  // ---- 间距边缘 ----
  static const EdgeInsets paddingH = EdgeInsets.symmetric(horizontal: spaceL);
  static const EdgeInsets paddingV = EdgeInsets.symmetric(vertical: spaceL);
  static const EdgeInsets paddingAll = EdgeInsets.all(spaceL);
  static const EdgeInsets paddingCard = EdgeInsets.all(spaceL);
  static const EdgeInsets paddingScreen =
      EdgeInsets.symmetric(horizontal: spaceXL, vertical: spaceXXL);
}

/// 构建 M3 主题。
///
/// [seedColor] 是种子色，明暗两套方案全部由它派生。
ThemeData buildM3LightTheme(Color seedColor) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,

    // ---- 排版：M3 字号阶梯 ----
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),

    // ---- 形状：M3 圆角令牌 ----
    cardTheme: CardThemeData(
      elevation: 0, // M3: 用色调表面代替阴影
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3Tokens.shapeM),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: M3Tokens.spaceXL, vertical: M3Tokens.spaceM),
        minimumSize: const Size(0, 40),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: M3Tokens.spaceXL, vertical: M3Tokens.spaceM),
        minimumSize: const Size(0, 40),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: M3Tokens.spaceL, vertical: M3Tokens.spaceS),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
          ),
        ),
        visualDensity: VisualDensity.standard,
      ),
    ),

    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3Tokens.shapeXL),
      ),
      elevation: 3,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3Tokens.shapeS),
      ),
    ),

    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: true,
      shape: const RoundedRectangleBorder(), // M3: AppBar 无圆角
    ),

    // M3 NavigationBar
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 64,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, height: 1.33);
        }
        return const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, height: 1.33);
      }),
    ),

    // M3 Surface tint (色调表面)
    // Card 和其他组件会自动使用 surfaceTint 来创建色调层。
  );
}

/// 暗色主题。
ThemeData buildM3DarkTheme(Color seedColor) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,

    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3Tokens.shapeM),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: M3Tokens.spaceXL, vertical: M3Tokens.spaceM),
        minimumSize: const Size(0, 40),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: M3Tokens.spaceXL, vertical: M3Tokens.spaceM),
        minimumSize: const Size(0, 40),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: M3Tokens.spaceL, vertical: M3Tokens.spaceS),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
          ),
        ),
      ),
    ),

    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3Tokens.shapeXL),
      ),
      elevation: 3,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3Tokens.shapeS),
      ),
    ),

    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: true,
    ),

    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 64,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3Tokens.shapeFull),
      ),
    ),
  );
}
