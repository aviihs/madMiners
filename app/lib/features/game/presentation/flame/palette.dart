import 'dart:ui';

import 'package:mad_miners_core/mad_miners_core.dart';

/// Colours for the mine, shifting with depth: brown topsoil → grey stone →
/// dark, reddish rock near the lava.
abstract final class MinePalette {
  static const _soil = Color(0xFF8C6A4B);
  static const _stone = Color(0xFF6E655E);
  static const _deep = Color(0xFF4A3F3A);
  static const _scorched = Color(0xFF4A2A22);

  static const _tunnelTop = Color(0xFF2E2219);
  static const _tunnelDeep = Color(0xFF1A1311);
  static const _tunnelHot = Color(0xFF2B130D);

  static const dirt = Color(0xFF9B6B43);

  static Color rock(double d, {required bool hard}) {
    if (!hard) return Color.lerp(_soil, _stone, (d * 2.2).clamp(0, 1))!;
    return Color.lerp(_deep, _scorched, ((d - 0.5) * 2).clamp(0, 1))!;
  }

  static Color tunnel(double d) => d < 0.75
      ? Color.lerp(_tunnelTop, _tunnelDeep, d / 0.75)!
      : Color.lerp(_tunnelDeep, _tunnelHot, (d - 0.75) / 0.25)!;

  static const ore = <TileType, Color>{
    TileType.copper: Color(0xFFE08A4E),
    TileType.iron: Color(0xFFD9D4CC),
    TileType.gold: Color(0xFFFFD03F),
    TileType.diamond: Color(0xFF8AF0FF),
    TileType.moneyBag: Color(0xFFFFCF3F),
    TileType.treasure: Color(0xFFFFD34D),
    TileType.coal: Color(0xFF2A2626),
    TileType.silver: Color(0xFFE3E8EE),
    TileType.emerald: Color(0xFF34D399),
    TileType.ruby: Color(0xFFE0115F),
    TileType.mystery: Color(0xFFB06BFF),
    TileType.obsidian: Color(0xFF2A1F3A),
    TileType.water: Color(0xFF4DA3FF),
    TileType.chest: Color(0xFFFFC233),
  };

  /// Each depth zone has its own mood: warm gold mine, blue diamond cave,
  /// purple crystal cavern, red lava underground.
  static const _zoneTint = <Zone, Color>{
    Zone.starterMine: Color(0x00000000),
    Zone.stoneCave: Color(0x14324050),
    Zone.goldMine: Color(0x22B8862A),
    Zone.diamondCave: Color(0x262E6FB0),
    Zone.crystalCavern: Color(0x2E8A3FD0),
    Zone.lavaUnderground: Color(0x2EC0301A),
  };

  static Color zoneTint(double d) => _zoneTint[Zone.at(d)]!;

  static Color tinted(Color c, double d) {
    final t = zoneTint(d);
    return t.a == 0 ? c : Color.lerp(c, t.withValues(alpha: 1), t.a)!;
  }

  /// Colour of chips flying off a tile.
  static Color chip(TileType t, double d) => switch (t) {
    TileType.dirt => dirt,
    TileType.explosive => const Color(0xFF9C2A1E),
    _ => ore[t] ?? (t == TileType.hardRock ? rock(d, hard: true) : rock(d, hard: false)),
  };

  static Color shade(Color c, double amount) =>
      amount >= 0 ? Color.lerp(c, const Color(0xFFFFFFFF), amount)! : Color.lerp(c, const Color(0xFF000000), -amount)!;
}
