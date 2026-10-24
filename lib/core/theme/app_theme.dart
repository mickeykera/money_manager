import 'package:flutter/material.dart';

class AppColors {
  // Reference UI: Dark Forest Green Palette
  static const Color forestGreen = Color(0xFF1B3B2B);
  static const Color forestGreenLight = Color(0xFF2B533E);
  static const Color forestGreenHero = Color(0xFF1A382A);
  static const Color forestGreenContainer = Color(0xFF264C39);
  static const Color forestGreenSubtext = Color(0xFFA2C2B0);
  static const Color greenAccentPill = Color(0xFFE8F3EC);
  static const Color greenAccentText = Color(0xFF235839);

  // Income & Expense Accents
  static const Color incomeGreen = Color(0xFF2E6B45);
  static const Color expenseClay = Color(0xFFBA4A38);

  // Reference UI: Warm Off-White Surfaces
  static const Color offWhiteBg = Color(0xFFF8F7F2);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFE8E6DE);
  static const Color textPrimary = Color(0xFF191A18);
  static const Color textSecondary = Color(0xFF75736B);
  static const Color textMuted = Color(0xFF9E9C94);

  // Backward-compatibility aliases
  static const Color lightBg = offWhiteBg;
  static const Color lightCard = cardWhite;
  static const Color lightSurface = cardWhite;
  static const Color lightBorder = borderSubtle;
  static const Color lightTextPrimary = textPrimary;
  static const Color lightTextSecondary = textSecondary;
  static const Color lightTextMuted = textMuted;
  static const Color sagePrimary = forestGreen;
  static const Color sageLight = greenAccentPill;
  static const Color sageContainer = greenAccentPill;
  static const Color sageDark = forestGreen;
  static const Color clayPrimary = expenseClay;
  static const Color clayLight = Color(0xFFFDECE9);
  static const Color clayContainer = Color(0xFFFDECE9);
  static const Color clayDark = expenseClay;

  // Dark Mode equivalents
  static const Color darkBg = Color(0xFF121413);
  static const Color darkSurface = Color(0xFF1A1C1A);
  static const Color darkCard = Color(0xFF222522);
  static const Color darkBorder = Color(0xFF333733);
  static const Color darkTextPrimary = Color(0xFFECEAE2);
  static const Color darkTextSecondary = Color(0xFFA2A096);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.offWhiteBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.forestGreen,
        onPrimary: Colors.white,
        primaryContainer: AppColors.greenAccentPill,
        onPrimaryContainer: AppColors.greenAccentText,
        secondary: AppColors.forestGreenLight,
        onSecondary: Colors.white,
        surface: AppColors.cardWhite,
        onSurface: AppColors.textPrimary,
        error: AppColors.expenseClay,
        onError: Colors.white,
        outline: AppColors.borderSubtle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.offWhiteBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forestGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.offWhiteBg,
        selectedItemColor: AppColors.forestGreen,
        unselectedItemColor: AppColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
        primary: Color(0xFF4C8564),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF1E3527),
        onPrimaryContainer: Color(0xFFD6E8D8),
        secondary: Color(0xFF3E6F52),
        onSecondary: Colors.white,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkTextPrimary,
        error: Color(0xFFD96350),
        onError: Colors.white,
        outline: AppColors.darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
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
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4C8564), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF4C8564),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBg,
        selectedItemColor: Color(0xFF75B58F),
        unselectedItemColor: AppColors.darkTextSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
