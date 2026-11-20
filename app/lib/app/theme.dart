import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Colour system. Every colour has one job:
///   gold   – primary actions, coins, rewards
///   gem    – gems and premium items
///   lava   – danger, hazards, destructive actions
///   leaf   – success, online, health OK
///   sky    – information, secondary accent, team B
///   violet – brand surfaces and highlights
abstract final class MMColors {
  // Surfaces (deep cave).
  static const bg = Color(0xFF120E1F);
  static const bgTop = Color(0xFF2A1D45);
  static const surface = Color(0xFF1E1832);
  static const surfaceHi = Color(0xFF2B2246);
  static const surfaceLow = Color(0xFF17122A);
  static const glass = Color(0x12FFFFFF);
  static const glassStrong = Color(0x1FFFFFFF);
  static const hairline = Color(0x17FFFFFF);

  // Roles.
  static const gold = Color(0xFFFFC233);
  static const goldLight = Color(0xFFFFDE73);
  static const goldDeep = Color(0xFFC27A00);
  static const gem = Color(0xFF2FE0C8);
  static const gemDeep = Color(0xFF0E9C8A);
  static const lava = Color(0xFFFF6A3D);
  static const leaf = Color(0xFF3DDC97);
  static const sky = Color(0xFF4DA3FF);
  static const violet = Color(0xFF9B6BFF);

  // Text.
  static const text = Color(0xFFF6F2FF);
  static const muted = Color(0xFFA59CC2);
  static const faint = Color(0xFF6E6590);
  static const onGold = Color(0xFF3B2300);

  // Back-compat aliases used across the game HUD.
  static const amber = gold;
  static const ember = lava;
  static const blue = sky;
  static const health = Color(0xFFFF4D6A);
  static const stamina = leaf;
  static const teams = [Color(0xFFFF9F1C), sky];

  static const accentGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, gold, Color(0xFFFFAA12)],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF262040), Color(0xFF1C1630)],
  );
}

abstract final class MMFonts {
  static const display = 'Lilita';
  static const body = 'Nunito';
}

abstract final class MMText {
  static const largeTitle = TextStyle(fontFamily: MMFonts.display, fontSize: 34, letterSpacing: 0.3, color: MMColors.text, height: 1.1);
  static const title = TextStyle(fontFamily: MMFonts.display, fontSize: 24, letterSpacing: 0.3, color: MMColors.text, height: 1.15);
  static const headline = TextStyle(fontFamily: MMFonts.body, fontSize: 16, fontWeight: FontWeight.w800, color: MMColors.text);
  static const body = TextStyle(fontFamily: MMFonts.body, fontSize: 15, fontWeight: FontWeight.w600, color: MMColors.text);
  static const callout = TextStyle(fontFamily: MMFonts.body, fontSize: 15, fontWeight: FontWeight.w600, color: MMColors.muted);
  static const footnote = TextStyle(fontFamily: MMFonts.body, fontSize: 13, fontWeight: FontWeight.w600, color: MMColors.muted);
  static const caption = TextStyle(fontFamily: MMFonts.body, fontSize: 12, fontWeight: FontWeight.w700, color: MMColors.muted);
  static const section = TextStyle(fontFamily: MMFonts.display, fontSize: 15, letterSpacing: 1.2, color: MMColors.muted);
  static const number = TextStyle(fontFamily: MMFonts.display, fontFeatures: [FontFeature.tabularFigures()]);
  static const button = TextStyle(fontFamily: MMFonts.display, fontSize: 19, letterSpacing: 0.8);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MMColors.gold,
    brightness: Brightness.dark,
    surface: MMColors.surface,
    primary: MMColors.gold,
    secondary: MMColors.gem,
    error: MMColors.lava,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: MMFonts.body,
    // iOS behaviour everywhere: swipe-back transitions, bouncing scroll.
    platform: TargetPlatform.iOS,
    scaffoldBackgroundColor: MMColors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: const CupertinoPageTransitionsBuilder()},
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: MMColors.gold,
      scaffoldBackgroundColor: MMColors.bg,
      barBackgroundColor: Color(0xE6120E1F),
      textTheme: CupertinoTextThemeData(
        primaryColor: MMColors.gold,
        textStyle: TextStyle(fontFamily: MMFonts.body, fontSize: 16, fontWeight: FontWeight.w600, color: MMColors.text),
        navLargeTitleTextStyle: TextStyle(fontFamily: MMFonts.display, fontSize: 34, letterSpacing: 0.4, color: MMColors.text),
        navTitleTextStyle: TextStyle(fontFamily: MMFonts.display, fontSize: 19, letterSpacing: 0.4, color: MMColors.text),
        actionTextStyle: TextStyle(fontFamily: MMFonts.body, fontSize: 16, fontWeight: FontWeight.w700, color: MMColors.gold),
      ),
    ),
  );
}
