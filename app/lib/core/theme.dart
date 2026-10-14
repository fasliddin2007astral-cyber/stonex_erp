import 'package:flutter/material.dart';

/// Vault / STONEX dizayn tizimi (zamonaviy quyuq grafit menyu + och kulrang panel + neon-laym urg‘ular).
class AppColors {
  static const sidebar = Color(0xFF131517);
  static const sidebarSelected = Color(0xFF1E2124);
  static const sidebarText = Color(0xFF8E959E);
  static const panel = Color(0xFFF5F6F8);
  static const darkCard = Color(0xFF131517);
  static const cardBg = Colors.white;

  // Vault dizaynidagi xos Neon-Laym (sariq-yashil) urg‘u
  static const neonLime = Color(0xFFD4F638);
  static const neonLimeSoft = Color(0xFFF4FCD3);
  static const neonLimeDark = Color(0xFF3C4800);

  // Standart yashil va ko‘rsatkichlar
  static const green = Color(0xFF10B981);
  static const greenBright = Color(0xFF22C55E);
  static const greenSoft = Color(0xFFDCFCE7);

  // Matn va chegaralar
  static const ink = Color(0xFF111417);
  static const muted = Color(0xFF71767B);
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFEEF0F3);

  // Holatlar
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFEE2E2);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3C7);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0xFFDBEAFE);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.neonLime,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.ink,
    secondary: AppColors.neonLime,
    surface: AppColors.cardBg,
    error: AppColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.panel,
    fontFamily: 'Inter',
  );

  final radius16 = BorderRadius.circular(16);
  final radius30 = BorderRadius.circular(30);

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius16,
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius30,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius30,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius30,
        borderSide: const BorderSide(color: AppColors.ink, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkCard,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius30),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius30),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkCard,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: radius30),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.borderLight, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius16),
    ),
  );
}