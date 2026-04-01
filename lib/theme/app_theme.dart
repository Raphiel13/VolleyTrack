import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── iOS system colour palette ────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Accent colours (identical in light and dark) ──
  static const Color blue   = Color(0xFF007AFF);
  static const Color teal   = Color(0xFF30B0C7);
  static const Color green  = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color red    = Color(0xFFFF3B30);
  static const Color purple = Color(0xFFAF52DE);
  static const Color indigo = Color(0xFF5856D6);
  static const Color pink   = Color(0xFFFF2D55);

  // ── Light mode backgrounds ──
  static const Color lightBg        = Color(0xFFF2F2F7);
  static const Color lightBg2       = Color(0xFFFFFFFF);
  static const Color lightBg3       = Color(0xFFEFEFF4);
  static const Color lightSeparator = Color(0x1F3C3C43);

  // ── Light mode labels ──
  static const Color lightLabel  = Color(0xE0000000);
  static const Color lightLabel2 = Color(0x993C3C43);
  static const Color lightLabel3 = Color(0x4D3C3C43);
  static const Color lightLabel4 = Color(0x2E3C3C43);

  // ── Dark mode backgrounds ──
  static const Color darkBg        = Color(0xFF000000);
  static const Color darkBg2       = Color(0xFF1C1C1E);
  static const Color darkBg3       = Color(0xFF2C2C2E);
  static const Color darkSeparator = Color(0xA6545458);

  // ── Dark mode labels ──
  static const Color darkLabel  = Color(0xEBFFFFFF);
  static const Color darkLabel2 = Color(0x99EBEBF5);
  static const Color darkLabel3 = Color(0x4DEBEBF5);
  static const Color darkLabel4 = Color(0x2EEBEBF5);

  // ── Player level colours (beginner → competitive) ──
  static const List<Color> levelColors = [
    blue,
    teal,
    green,
    orange,
    red,
  ];
}

// ─── Resolved tokens per brightness ──────────────────────────────────────────

class AppTokens {
  final Color bg;
  final Color bg2;
  final Color bg3;
  final Color separator;
  final Color label;
  final Color label2;
  final Color label3;
  final Color label4;
  final Color glassBg;

  const AppTokens({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.separator,
    required this.label,
    required this.label2,
    required this.label3,
    required this.label4,
    required this.glassBg,
  });

  static const light = AppTokens(
    bg:        AppColors.lightBg,
    bg2:       AppColors.lightBg2,
    bg3:       AppColors.lightBg3,
    separator: AppColors.lightSeparator,
    label:     AppColors.lightLabel,
    label2:    AppColors.lightLabel2,
    label3:    AppColors.lightLabel3,
    label4:    AppColors.lightLabel4,
    glassBg:   Color(0xB8FFFFFF),
  );

  static const dark = AppTokens(
    bg:        AppColors.darkBg,
    bg2:       AppColors.darkBg2,
    bg3:       AppColors.darkBg3,
    separator: AppColors.darkSeparator,
    label:     AppColors.darkLabel,
    label2:    AppColors.darkLabel2,
    label3:    AppColors.darkLabel3,
    label4:    AppColors.darkLabel4,
    glassBg:   Color(0xD11C1C1E),
  );

  static AppTokens of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppTokens.dark
        : AppTokens.light;
  }
}

// ─── ThemeData builder ────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData build(Brightness brightness) {
    final t = brightness == Brightness.dark
        ? AppTokens.dark
        : AppTokens.light;
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.blue,
        onPrimary: Colors.white,
        secondary: AppColors.teal,
        onSecondary: Colors.white,
        error: AppColors.red,
        onError: Colors.white,
        surface: t.bg2,
        onSurface: t.label,
        background: t.bg,
        onBackground: t.label,
      ),
      textTheme: _textTheme(t.label, t.label2),
      appBarTheme: AppBarTheme(
        backgroundColor: t.glassBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: t.label,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.blue),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: AppColors.blue,
        scaffoldBackgroundColor: t.bg,
        barBackgroundColor: t.glassBg,
      ),
      dividerTheme: DividerThemeData(
        color: t.separator,
        thickness: 0.5,
        space: 0,
      ),
      cardTheme: CardTheme(
        color: t.bg2,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0x1E767680),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.inter(color: t.label3, fontSize: 17),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.glassBg,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: t.label3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color label, Color label2) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 34, fontWeight: FontWeight.w700,
        color: label, letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: label, letterSpacing: -0.4,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 22, fontWeight: FontWeight.w700,
        color: label, letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: label, letterSpacing: -0.2,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w600,
        color: label, letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w600, color: label,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w500, color: label,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, color: label,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w400, color: label,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, color: label,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w400, color: label2,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600, color: label,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: label2, letterSpacing: 0.3,
      ),
    );
  }
}