import 'dart:math';

import '../config/balance.dart';
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
          map.setTile(x, y, d > 0.45 ? TileType.hardRock : (d < 0.18 ? TileType.dirt : TileType.rock));
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

    // 3b. Loose boulders sitting in the rock: dig under one and it drops.
    for (var y = surfaceRows + 3; y < lavaTop - 4; y++) {
      for (var x = 2; x < width - 2; x++) {
        final t = map.tileAt(x, y);
        if ((t == TileType.rock || t == TileType.hardRock) && rng.nextDouble() < def.boulders) {
          map.setTile(x, y, TileType.boulder);
        }
      }
    }

    // 3c. Traps: spikes on cave floors, explosive crates in the rock.
    for (var y = surfaceRows + 4; y < lavaTop - 3; y++) {
      final d = (y - surfaceRows) / (lavaTop - surfaceRows);
      for (var x = 2; x < width - 2; x++) {
        final t = map.tileAt(x, y);
        if (t == TileType.empty && map.isSolid(x, y + 1) && map.tileAt(x, y + 1) != TileType.boulder && rng.nextDouble() < 0.05 + d * 0.08) {
          map.setTile(x, y, TileType.spikes);
        } else if (t == TileType.empty && map.isSolid(x, y + 1) && map.tileAt(x, y + 1) != TileType.boulder && rng.nextDouble() < 0.04) {
          // Only where there's room to fly: a launcher under a low ceiling
          // would just be a death trap.
          final pad = _pickLauncher(rng);
          if (_hasRoom(map, x, y, pad.launch!)) map.setTile(x, y, pad);
        } else if (t == TileType.empty && map.isSolid(x, y + 1) && map.tileAt(x, y + 1) != TileType.boulder && rng.nextDouble() < 0.015) {
          map.setTile(x, y, TileType.plate);
        } else if ((t == TileType.rock || t == TileType.hardRock) && rng.nextDouble() < 0.006 + d * 0.005) {
          map.setTile(x, y, TileType.forTnt(_pickTnt(rng)));
        }
      }
    }

    // 3d. Mystery Bombs, more of them deeper down.
    var mysteries = 0, mtries = 0;
    while (mysteries < def.mysteryBombs && mtries++ < 3000) {
      final x = 2 + rng.nextInt(width - 4);
      final f = sqrt(rng.nextDouble()); // skew deeper
      final y = surfaceRows + 4 + ((lavaTop - surfaceRows - 8) * f).floor();
      final t = map.tileAt(x, y);
      if (t != TileType.rock && t != TileType.hardRock && t != TileType.dirt) continue;
      map.setTile(x, y, TileType.mystery);
      mysteries++;
    }

    // 3f. Water pockets in the middle layers.
    _scatter(map, rng, TileType.water, 3 + rng.nextInt(3),
        fromY: surfaceRows + (lavaTop - surfaceRows) ~/ 6, toY: surfaceRows + (lavaTop - surfaceRows) * 3 ~/ 5, radius: 1);

    // 3g. Lava rivers: long channels deep down, with obsidian banks.
    for (var n = 0; n < 1 + rng.nextInt(2); n++) {
      final y = surfaceRows + ((lavaTop - surfaceRows) * (0.66 + rng.nextDouble() * 0.2)).floor();
      final len = 8 + rng.nextInt(9);
      final x0 = 2 + rng.nextInt(max(1, width - 4 - len));
      for (var x = x0; x < x0 + len; x++) {
        for (var dy = 0; dy < 2; dy++) {
          if (map.tileAt(x, y + dy) != TileType.bedrock) map.setTile(x, y + dy, TileType.lava);
        }
        for (final by in [y - 1, y + 2]) {
          if (map.tileAt(x, by).isMinable && rng.nextDouble() < 0.6) map.setTile(x, by, TileType.obsidian);
        }
      }
    }

    // 3h. Hidden obsidian streaks in the deep half.
    for (var n = 0; n < 6; n++) {
      final y = surfaceRows + ((lavaTop - surfaceRows) * (0.5 + rng.nextDouble() * 0.45)).floor();
      final x0 = 2 + rng.nextInt(width - 10);
      for (var x = x0; x < x0 + 3 + rng.nextInt(5); x++) {
        if (map.tileAt(x, y) == TileType.hardRock) map.setTile(x, y, TileType.obsidian);
      }
    }

    // 3i. Trap chambers: a small room with a pressure plate, TNT in the
    //     walls and a chest at the far end.
    for (var n = 0; n < 2; n++) {
      final cy = surfaceRows + ((lavaTop - surfaceRows) * (0.3 + rng.nextDouble() * 0.45)).floor();
      final cx = 4 + rng.nextInt(width - 12);
      for (var x = cx; x < cx + 5; x++) {
        for (var y = cy - 1; y <= cy; y++) {
          map.setTile(x, y, TileType.empty);
        }
        map.setTile(x, cy + 1, TileType.hardRock);
      }
      map.setTile(cx + 2, cy, TileType.plate);
      map.setTile(cx + 4, cy, TileType.chest);
      map.setTile(cx - 1, cy - 1, TileType.forTnt(TntKind.basic));
      map.setTile(cx + 5, cy - 1, TileType.forTnt(TntKind.chain));
    }

    // 3e. Obsidian crust just above the lava.
    for (var y = lavaTop - (lavaTop - surfaceRows) ~/ 8; y < lavaTop; y++) {
      for (var x = 1; x < width - 1; x++) {
        if (map.tileAt(x, y) == TileType.hardRock && rng.nextDouble() < 0.10) map.setTile(x, y, TileType.obsidian);
      }
    }

    // 4. Hazards.
    _scatter(map, rng, TileType.gas, def.gasPockets, fromY: surfaceRows + (lavaTop - surfaceRows) ~/ 4, toY: lavaTop - 3, radius: 1);
    _scatter(map, rng, TileType.lava, def.lavaPockets, fromY: lavaTop - (lavaTop - surfaceRows) ~/ 4, toY: lavaTop - 2, radius: 1);

    // 5. The treasure, sealed in a hidden chamber a few rows above the lava:
    //
    //     ##  D  ##      # obsidian walls (with rare ore), D ancient door
    //     #  ....  #     . open room
    //     #  ....  #
    //     ##C##T##C##    T treasure, C chests
    final tx = 6 + rng.nextInt(width - 12);
    final ty = lavaTop - 2 - rng.nextInt(2);
    for (var y = ty - 3; y <= ty; y++) {
      for (var x = tx - 4; x <= tx + 4; x++) {
        final edge = y == ty - 3 || y == ty || x == tx - 4 || x == tx + 4;
        map.setTile(x, y, edge ? TileType.obsidian : TileType.empty);
      }
    }
    for (final x in [tx - 3, tx - 1, tx + 1, tx + 3]) {
      if (rng.nextDouble() < 0.5) map.setTile(x, ty - 3, rng.nextBool() ? TileType.diamond : TileType.ruby);
    }
    map.setTile(tx, ty - 3, TileType.ancientDoor);
    map.setTile(tx, ty, TileType.treasure);
    map.setTile(tx - 2, ty, TileType.chest);
    map.setTile(tx + 2, ty, TileType.chest);
    final chamber = <int>[
      for (var y = ty - 3; y <= ty; y++)
        for (var x = tx - 4; x <= tx + 4; x++) map.indexOf(x, y),
    ];

    // 6. Hidden volcanoes, only in the hard-rock half (they look identical).
    var placed = 0, tries = 0;
    while (placed < def.volcanoes && tries++ < 2000) {
      final x = 1 + rng.nextInt(width - 2);
      final y = surfaceRows + ((lavaTop - surfaceRows) * (0.5 + rng.nextDouble() * 0.48)).floor();
      if (map.tileAt(x, y) != TileType.hardRock) continue;
      if ((x - tx).abs() <= 6 && (y - ty).abs() <= 5) continue; // keep the treasure fair
      map.setTile(x, y, TileType.volcano);
      placed++;
    }
    _hideHazards(map, lavaTop, chamber.toSet());
    return map;
  }

  /// Hides hazards and the treasure chamber from clients. Anything already
  /// touching an open cave is visible from the start; floor traps in caves
  /// look like empty floor until someone walks close.
  void _hideHazards(GameMap map, int lavaTop, Set<int> chamber) {
    TileType rockLike(int y) {
      final d = (y - surfaceRows) / (lavaTop - surfaceRows);
      return d > 0.45 ? TileType.hardRock : (d < 0.18 ? TileType.dirt : TileType.rock);
    }

    for (var y = surfaceRows + 1; y < lavaTop; y++) {
      for (var x = 1; x < width - 1; x++) {
        final i = map.indexOf(x, y);
        final t = map.tileAtIndex(i);
        final hideable = chamber.contains(i) ||
            t == TileType.lava ||
            t == TileType.water ||
            t == TileType.gas ||
            t == TileType.obsidian ||
            t.tnt != null ||
            t.isFloorDevice;
        if (!hideable) continue;
        final inCave = t.isFloorDevice && !map.isSolid(x, y - 1) && !chamber.contains(i);
        map.hide(i, inCave ? TileType.empty : rockLike(y));
      }
    }
    // Reveal whatever already borders open space.
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < width; x++) {
        final i = map.indexOf(x, y);
        if (!map.isHidden(i) && !map.tileAtIndex(i).isSolid) map.exposeAround(x, y);
      }
    }
  }

  /// Open space along the launch path (at least 4 tiles).
  static bool _hasRoom(GameMap map, int x, int y, LaunchKind k) {
    final (dx, dy) = switch (k) {
      LaunchKind.left => (-1, 0),
      LaunchKind.right => (1, 0),
      LaunchKind.upLeft => (-1, -1),
      LaunchKind.upRight => (1, -1),
      _ => (0, -1),
    };
    for (var s = 1; s <= 4; s++) {
      if (map.isSolid(x + dx * s, y + dy * s)) return false;
    }
    return true;
  }

  static LaunchKind _pickLaunchKind(Random rng) => LaunchKind.values[rng.nextInt(LaunchKind.values.length)];

  static TileType _pickLauncher(Random rng) => switch (_pickLaunchKind(rng)) {
    LaunchKind.up => TileType.launcherUp,
    LaunchKind.left => TileType.launcherLeft,
    LaunchKind.right => TileType.launcherRight,
    LaunchKind.upLeft => TileType.launcherUpLeft,
    LaunchKind.upRight => TileType.launcherUpRight,
    LaunchKind.heavy => TileType.launcherHeavy,
    LaunchKind.random => TileType.launcherRandom,
  };

  static TntKind _pickTnt(Random rng) {
    final r = rng.nextDouble();
    if (r < 0.40) return TntKind.basic;
    if (r < 0.55) return TntKind.powerful;
    if (r < 0.70) return TntKind.mining;
    if (r < 0.82) return TntKind.chain;
    if (r < 0.92) return TntKind.treasure;
    return TntKind.unstable;
  }

  TileType? _pickLoot(double roll, double d, double boost) {
    final moneyBag = d < 0.4 ? 0.0 : 0.010 * d * boost;
    final diamond = d < 0.3 ? 0.0 : 0.018 * d * d * boost;
    final ruby = d < 0.6 ? 0.0 : 0.010 * d * boost;
    final emerald = d < 0.5 ? 0.0 : 0.010 * d * boost;
    final silver = d < 0.15 ? 0.0 : 0.022 * (1 - (d - 0.45).abs());
    final gold = 0.028 * d * boost;
    final iron = 0.040 * (0.3 + d * 0.7);
    final copper = 0.050 * (1.1 - d);
    final coal = d > 0.5 ? 0.0 : 0.045 * (1 - d * 2);
    var acc = moneyBag;
    if (roll < acc) return TileType.moneyBag;
    if (roll < (acc += ruby)) return TileType.ruby;
    if (roll < (acc += emerald)) return TileType.emerald;
    if (roll < (acc += silver)) return TileType.silver;
    if (roll < (acc += coal)) return TileType.coal;
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
