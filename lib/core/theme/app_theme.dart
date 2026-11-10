import 'package:flutter/material.dart';

/// LedgerLeaf visual language: dark graphite and warm stone, with antique
/// brass used sparingly in menus and small accents. Surfaces are layered like
/// physical objects — a soft top highlight, a darker lower edge, and a quiet
/// drop shadow — so the ledger feels engraved rather than painted.
class AppColors {
  // ---------------------------------------------------------------------------
  // Light: warm stone paper, charcoal ink, oxidized brass.
  // ---------------------------------------------------------------------------
  static const Color offWhiteBg = Color(0xFFE7E3DA);
  static const Color cardWhite = Color(0xFFF5F2EA);
  static const Color borderSubtle = Color(0xFFCFC9BC);
  static const Color textPrimary = Color(0xFF1B1A17);
  static const Color textSecondary = Color(0xFF5C584F);
  static const Color textMuted = Color(0xFF8C867A);

  static const Color forestGreen = Color(0xFF7E6638);
  static const Color forestGreenLight = Color(0xFF9A814F);
  static const Color forestGreenHero = Color(0xFF24272A);
  static const Color forestGreenContainer = Color(0xFFDED6C4);
  static const Color forestGreenSubtext = Color(0xFFBBB3A4);
  static const Color greenAccentPill = Color(0xFFE9E1CF);
  static const Color greenAccentText = Color(0xFF5F4D2A);

  static const Color incomeGreen = Color(0xFF4E6B4D);
  static const Color expenseClay = Color(0xFF9C5347);
  static const Color clayLight = Color(0xFFEFDCD6);
  static const Color clayContainer = Color(0xFFEFDCD6);
  static const Color clayDark = Color(0xFF7F4238);

  // Backward-compatibility aliases used across the presentation layer.
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

  // ---------------------------------------------------------------------------
  // Dark: charcoal leather, ivory type, brushed-steel edges.
  // ---------------------------------------------------------------------------
  static const Color darkBg = Color(0xFF0C0D0E);
  static const Color darkSurface = Color(0xFF121415);
  static const Color darkCard = Color(0xFF191C1E);
  static const Color darkBorder = Color(0xFF303539);
  static const Color darkTextPrimary = Color(0xFFECE8DF);
  static const Color darkTextSecondary = Color(0xFFA6A199);
  static const Color darkTextMuted = Color(0xFF706C65);
  static const Color darkBrass = Color(0xFFC9AD72);
  static const Color darkBrassDeep = Color(0xFF8C7444);
  static const Color darkIncome = Color(0xFF8FA98B);
  static const Color darkExpense = Color(0xFFC47E6E);

  // ---------------------------------------------------------------------------
  // Adaptive helpers for new widgets. Existing screens can keep the constants
  // above; these make it easy to stay legible in both themes.
  // ---------------------------------------------------------------------------
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? darkBg : offWhiteBg;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkCard : cardWhite;

  static Color raisedOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E2124) : const Color(0xFFF9F6EF);

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : borderSubtle;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color accentOf(BuildContext context) =>
      isDark(context) ? darkBrass : forestGreen;

  static Color accentDeepOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFE0C892) : greenAccentText;

  static Color incomeOf(BuildContext context) =>
      isDark(context) ? darkIncome : incomeGreen;

  static Color expenseOf(BuildContext context) =>
      isDark(context) ? darkExpense : expenseClay;

  static Color highlightOf(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.075)
          : Colors.white.withValues(alpha: 0.75);

  static Color shadowLineOf(BuildContext context) =>
      isDark(context)
          ? Colors.black.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.10);

  static Color iconWellOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF111314) : const Color(0xFFE4DED2);

  static Color brassBorderOf(BuildContext context) => isDark(context)
      ? const Color(0x66C9AD72)
      : const Color(0x558A6F3F);
}

class AppTheme {
  static const String fontFamily = 'PlayfairDisplay';

  static TextTheme _textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 42,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 34,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: primary,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 19,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.05,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: muted,
      ),
    );
  }

  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = _textTheme(brightness);

    final primary = isDark ? AppColors.darkBrass : AppColors.forestGreen;
    final onPrimary =
        isDark ? const Color(0xFF15130D) : const Color(0xFFFFFBF2);
    final surface = isDark ? AppColors.darkCard : AppColors.cardWhite;
    final onSurface =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final outline = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    final error = isDark ? AppColors.darkExpense : AppColors.expenseClay;

    final buttonGradientBottom =
        isDark ? const Color(0xFF101214) : const Color(0xFF171A1C);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer:
            isDark ? const Color(0xFF2A2418) : AppColors.greenAccentPill,
        onPrimaryContainer:
            isDark ? const Color(0xFFE0C892) : AppColors.greenAccentText,
        secondary: isDark ? AppColors.darkBrassDeep : AppColors.forestGreenLight,
        onSecondary: isDark ? const Color(0xFF15130D) : Colors.white,
        surface: surface,
        onSurface: onSurface,
        error: error,
        onError: Colors.white,
        outline: outline,
        outlineVariant: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06),
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceContainerHighest:
            isDark ? const Color(0xFF23272A) : const Color(0xFFE9E3D7),
        surfaceContainerHigh:
            isDark ? const Color(0xFF1E2124) : const Color(0xFFEFEAE0),
        surfaceContainer:
            isDark ? const Color(0xFF191C1E) : const Color(0xFFF2EDE3),
        surfaceContainerLow:
            isDark ? const Color(0xFF141617) : const Color(0xFFF6F2E9),
        surfaceContainerLowest:
            isDark ? const Color(0xFF0C0D0E) : const Color(0xFFFAF7F0),
        onSurfaceVariant:
            isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: 25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? const Color(0xFF111314) : const Color(0xFFEDE8DD),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          fontSize: 13.5,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          fontSize: 13.5,
        ),
        prefixIconColor:
            isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
        suffixIconColor:
            isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBrass : AppColors.forestGreen,
            width: 1.4,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return buttonGradientBottom.withValues(alpha: 0.55);
            }
            return buttonGradientBottom;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return onPrimary.withValues(alpha: 0.45);
            }
            return onPrimary;
          }),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.06),
          ),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: isDark ? 0.55 : 0.32),
          ),
          elevation: const WidgetStatePropertyAll(4),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.4,
              color: onPrimary,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkBrass : AppColors.forestGreen,
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: outline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 14.5,
            letterSpacing: 0.3,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor:
            isDark ? const Color(0xFF22262A) : const Color(0xFF25282B),
        foregroundColor: isDark ? AppColors.darkBrass : const Color(0xFFE8D5A8),
        elevation: 8,
        focusElevation: 10,
        hoverElevation: 10,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? const Color(0xFF171A1C) : const Color(0xFFF1ECE1),
        selectedColor: isDark ? AppColors.darkBrass : AppColors.forestGreen,
        disabledColor:
            isDark ? const Color(0xFF141617) : const Color(0xFFE4DED2),
        side: BorderSide(color: outline),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? const Color(0xFF15130D) : Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1B1E20) : const Color(0xFFF6F2E9),
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isDark ? const Color(0xFF191C1E) : const Color(0xFFF5F1E8),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor:
            isDark ? const Color(0xFF191C1E) : const Color(0xFFF5F1E8),
        modalBarrierColor: Colors.black.withValues(alpha: 0.55),
        elevation: 20,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor:
            isDark ? AppColors.darkTextMuted : AppColors.textMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF262A2D) : const Color(0xFF26292C),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: const Color(0xFFF2EEE5),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        textColor: onSurface,
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          fontSize: 12.5,
          height: 1.35,
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? AppColors.darkBrass : const Color(0xFFE8D8B4);
          }
          return isDark ? const Color(0xFF9A958C) : const Color(0xFFF7F4EC);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? const Color(0xFF4A3D24) : AppColors.forestGreen;
          }
          return isDark ? const Color(0xFF23272A) : const Color(0xFFC8C2B5);
        }),
        trackOutlineColor: WidgetStatePropertyAll(outline),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF0F1112) : const Color(0xFFEFEAE0),
        selectedItemColor: isDark ? AppColors.darkBrass : AppColors.forestGreen,
        unselectedItemColor:
            isDark ? AppColors.darkTextMuted : AppColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.darkBrass : AppColors.forestGreen,
        linearTrackColor:
            isDark ? const Color(0xFF0E1011) : const Color(0xFFD9D3C6),
        circularTrackColor:
            isDark ? const Color(0xFF222629) : const Color(0xFFD9D3C6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark
                  ? const Color(0xFF2B2A22)
                  : const Color(0xFFDED6C4);
            }
            return isDark ? const Color(0xFF141617) : const Color(0xFFF1ECE1);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark ? AppColors.darkBrass : AppColors.greenAccentText;
            }
            return isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: outline)),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
