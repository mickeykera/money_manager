import 'package:flutter/material.dart';

class AppColors {
  // Sage green palette (Income, positive cash flow, success)
  static const Color sagePrimary = Color(0xFF3F6647);
  static const Color sageLight = Color(0xFF5B8263);
  static const Color sageContainer = Color(0xFFD6E8D8);
  static const Color onSageContainer = Color(0xFF0F3218);

  // Terracotta & Clay palette (Expenses, alerts)
  static const Color clayPrimary = Color(0xFFB4533C);
  static const Color clayLight = Color(0xFFCC6E57);
  static const Color clayContainer = Color(0xFFF9DCD5);
  static const Color onClayContainer = Color(0xFF3F130B);

  // Warm Neutral Light Surfaces
  static const Color lightBg = Color(0xFFF7F5EE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF0ECE1);
  static const Color lightBorder = Color(0xFFE2DDD1);
  static const Color lightTextPrimary = Color(0xFF1E1D19);
  static const Color lightTextSecondary = Color(0xFF6B685E);
  static const Color lightMuted = Color(0xFF999589);

  // Warm Neutral Dark Surfaces
  static const Color darkBg = Color(0xFF141512);
  static const Color darkSurface = Color(0xFF1E1F1A);
  static const Color darkCard = Color(0xFF282A24);
  static const Color darkBorder = Color(0xFF383B32);
  static const Color darkTextPrimary = Color(0xFFEDE9DF);
  static const Color darkTextSecondary = Color(0xFFA5A297);
  static const Color darkMuted = Color(0xFF737166);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.sagePrimary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.sageContainer,
        onPrimaryContainer: AppColors.onSageContainer,
        secondary: AppColors.clayPrimary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.clayContainer,
        onSecondaryContainer: AppColors.onClayContainer,
        error: AppColors.clayPrimary,
        onError: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        outline: AppColors.lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sagePrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sagePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.sageLight,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF26402B),
        onPrimaryContainer: Color(0xFFD6E8D8),
        secondary: AppColors.clayLight,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF4C2117),
        onSecondaryContainer: Color(0xFFF9DCD5),
        error: AppColors.clayLight,
        onError: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        outline: AppColors.darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sageLight, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sageLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }
}
