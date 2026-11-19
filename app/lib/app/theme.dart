import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Design tokens. iOS-style dark palette with warm "mine" accents.
abstract final class MMColors {
  static const bg = Color(0xFF0C0A09);
  static const bgTop = Color(0xFF241810);
  static const surface = Color(0xFF1C1917);
  static const surfaceHi = Color(0xFF2B2623);
  static const glass = Color(0x17FFFFFF);
  static const glassStrong = Color(0x26FFFFFF);
  static const hairline = Color(0x1FFFFFFF);

  static const amber = Color(0xFFFF9F0A); // iOS system orange
  static const gold = Color(0xFFFFD60A);
  static const ember = Color(0xFFFF6B2C);
  static const blue = Color(0xFF0A84FF);
  static const text = Color(0xFFF5F5F7);
  static const muted = Color(0xFF98989F);
  static const faint = Color(0xFF636366);
  static const health = Color(0xFFFF453A);
  static const stamina = Color(0xFF30D158);
  static const teams = [Color(0xFFFF9F0A), Color(0xFF0A84FF)];

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB340), Color(0xFFFF6B2C)],
  );
}

abstract final class MMText {
  static const largeTitle = TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: MMColors.text);
  static const title = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: MMColors.text);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: MMColors.text);
  static const body = TextStyle(fontSize: 16, letterSpacing: -0.2, color: MMColors.text);
  static const callout = TextStyle(fontSize: 15, letterSpacing: -0.2, color: MMColors.muted);
  static const footnote = TextStyle(fontSize: 13, letterSpacing: -0.1, color: MMColors.muted);
  static const caption = TextStyle(fontSize: 12, color: MMColors.muted);
  static const section = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: MMColors.muted);
  static const number = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
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
    brightness: Brightness.dark,
    useMaterial3: true,
    // iOS behaviour everywhere: swipe-back transitions, bouncing scroll.
    platform: TargetPlatform.iOS,
    scaffoldBackgroundColor: MMColors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: CupertinoPageTransitionsBuilder()},
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: MMColors.amber,
      scaffoldBackgroundColor: MMColors.bg,
      barBackgroundColor: Color(0xCC0C0A09),
      textTheme: CupertinoTextThemeData(primaryColor: MMColors.amber),
    ),
  );
}
