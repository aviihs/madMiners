import 'package:flutter/material.dart';

abstract final class MMColors {
  static const bg = Color(0xFF14110F);
  static const surface = Color(0xFF221D19);
  static const surfaceHi = Color(0xFF2E2621);
  static const amber = Color(0xFFF2A93B);
  static const ember = Color(0xFFE5642E);
  static const text = Color(0xFFF3E9DC);
  static const muted = Color(0xFFA89A8A);
  static const health = Color(0xFFE5484D);
  static const stamina = Color(0xFF46A758);
  static const oxygen = Color(0xFF3E9BE0);
  static const teams = [Color(0xFFE5642E), Color(0xFF3E9BE0)];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MMColors.amber,
    brightness: Brightness.dark,
    surface: MMColors.surface,
    primary: MMColors.amber,
    secondary: MMColors.ember,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: MMColors.bg,
    useMaterial3: true,
    cardTheme: const CardThemeData(color: MMColors.surface, margin: EdgeInsets.zero),
    inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: MMColors.surfaceHi, border: OutlineInputBorder()),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: MMColors.bg,
        backgroundColor: MMColors.amber,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    ),
  );
}
