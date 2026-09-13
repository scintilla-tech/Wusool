import 'package:flutter/material.dart';

class WaslColors {
  static const navy = Color(0xFF0B2545);
  static const navyDark = Color(0xFF071A33);
  static const emerald = Color(0xFF0FA3A3);
  static const teal = Color(0xFF2CB1BC);
  static const offWhite = Color(0xFFF5F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A2433);
  static const textSecondary = Color(0xFF5B6B7F);
  static const success = Color(0xFF1FA971);
  static const warning = Color(0xFFE0A03A);
  static const danger = Color(0xFFD9534F);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: WaslColors.navy,
      secondary: WaslColors.emerald,
      surface: WaslColors.surface,
      error: WaslColors.danger,
    ),
    scaffoldBackgroundColor: WaslColors.offWhite,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: WaslColors.textPrimary,
      displayColor: WaslColors.navy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: WaslColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: WaslColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WaslColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7DEE6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7DEE6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: WaslColors.emerald, width: 2),
      ),
    ),
  );
}
