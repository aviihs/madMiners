import 'dart:math';

import '../model/match_settings.dart';
import 'game_map.dart';
import 'tile.dart';

/// Deterministic, seeded vertical mine.
///
/// ```
///  surface camp + depot (spawn)
///  ── rock ──────────────── loot gets richer with depth
///  ── hard rock ───────────  diamonds, money bags, gas, lava pockets
///  ── 💎 hidden treasure ── (random column, just above the lava)
///  ── LAVA SEA ────────────  instant death
///  ── bedrock ─────────────
/// ```
class MapGenerator {
  const MapGenerator({this.width = 40});

  final int width;

  static const int surfaceRows = 6;

  GameMap generate(MapId id, int seed) {
    final def = id.def;
    final height = def.height;
    final rng = Random(seed);
    final cx = width ~/ 2;
    final map = GameMap(width, height, spawn: TilePos(cx, 3));
    final lavaTop = height - 1 - def.lavaRows;

    // 1. Small air pockets via cellular automata (sparse: mostly solid rock).
    var open = List.generate(height, (y) => List.generate(width, (x) => rng.nextDouble() < 0.36));
    for (var iter = 0; iter < 3; iter++) {
      final next = List.generate(height, (_) => List.filled(width, false));
      for (var y = 1; y < height - 1; y++) {
        for (var x = 1; x < width - 1; x++) {
          var walls = 0;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if ((dx != 0 || dy != 0) && !open[y + dy][x + dx]) walls++;
            }
          }
          next[y][x] = walls < 4;
        }
      }
      open = next;
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final border = x == 0 || y == 0 || x == width - 1 || y == height - 1;
        if (border) {
          map.setTile(x, y, TileType.bedrock);
        } else if (y < surfaceRows) {
          map.setTile(x, y, TileType.empty);
        } else if (y >= lavaTop) {
          map.setTile(x, y, TileType.lava);
        } else if (y > surfaceRows + 1 && open[y][x]) {
          map.setTile(x, y, TileType.empty);
        } else {
          final d = (y - surfaceRows) / (lavaTop - surfaceRows);
          map.setTile(x, y, d > 0.45 ? TileType.hardRock : TileType.rock);
        }
      }
    }

    // 2. Depot pad at the surface.
    for (var x = cx - 3; x <= cx + 3; x++) {
      map.setTile(x, surfaceRows - 1, TileType.depot);
    }

    // 3. Loot, richer with depth.
    for (var y = surfaceRows; y < lavaTop; y++) {
      final d = (y - surfaceRows) / (lavaTop - surfaceRows); // 0 top .. 1 bottom
      for (var x = 1; x < width - 1; x++) {
        if (!map.tileAt(x, y).isMinable) continue;
        final loot = _pickLoot(rng.nextDouble(), d, def.lootBoost);
        if (loot != null) map.setTile(x, y, loot);
      }
    }

    // 4. Hazards.
    _scatter(map, rng, TileType.gas, def.gasPockets, fromY: surfaceRows + (lavaTop - surfaceRows) ~/ 4, toY: lavaTop - 3, radius: 1);
    _scatter(map, rng, TileType.lava, def.lavaPockets, fromY: lavaTop - (lavaTop - surfaceRows) ~/ 4, toY: lavaTop - 2, radius: 1);

    // 5. The treasure: random column, a few rows above the lava sea.
    final tx = 2 + rng.nextInt(width - 4);
    final ty = lavaTop - 3 - rng.nextInt(5);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (map.tileAt(tx + dx, ty + dy) != TileType.bedrock) map.setTile(tx + dx, ty + dy, TileType.hardRock);
      }
    }
    map.setTile(tx, ty, TileType.treasure);
    return map;
  }

  TileType? _pickLoot(double roll, double d, double boost) {
    final moneyBag = d < 0.4 ? 0.0 : 0.010 * d * boost;
    final diamond = d < 0.3 ? 0.0 : 0.018 * d * d * boost;
    final gold = 0.028 * d * boost;
    final iron = 0.040 * (0.3 + d * 0.7);
    final copper = 0.050 * (1.1 - d);
    var acc = moneyBag;
    if (roll < acc) return TileType.moneyBag;
    if (roll < (acc += diamond)) return TileType.diamond;
    if (roll < (acc += gold)) return TileType.gold;
    if (roll < (acc += iron)) return TileType.iron;
    if (roll < (acc += copper)) return TileType.copper;
    return null;
  }

  void _scatter(GameMap map, Random rng, TileType type, int count, {required int fromY, required int toY, required int radius}) {
    if (toY <= fromY) return;
    for (var n = 0; n < count; n++) {
      final x = 2 + rng.nextInt(width - 4);
      final y = fromY + rng.nextInt(toY - fromY);
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius - 1; dx <= radius + 1; dx++) {
          final t = map.tileAt(x + dx, y + dy);
          if (t != TileType.bedrock && t != TileType.treasure && rng.nextDouble() < 0.75) {
            map.setTile(x + dx, y + dy, type);
          }
        }
      }
    }
  }
}
