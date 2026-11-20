import 'dart:math';

import '../config/balance.dart';
import '../model/snapshot.dart';
import '../world/game_map.dart';
import '../world/tile.dart';
import 'pathfinding.dart';
import 'sim_player.dart';

enum BotGoal { digDown, grabLoot, treasure }

/// What a bot wants to do this tick.
class BotDecision {
  const BotDecision(this.input, {this.upgrade, this.buyItem, this.useItem});
  final PlayerInput input;
  final UpgradeKind? upgrade;
  final ItemKind? buyItem;
  final ItemKind? useItem;
}

/// Treasure-race AI. Bots know only what a player could see:
/// - they dig downward along their own "lane", never into lava,
/// - they grab loot inside their helmet light,
/// - they go for the treasure only once it's revealed AND close,
/// - near the bottom they sweep sideways to search for it.
///
/// Bots only produce [PlayerInput]s, which the simulation validates like
/// any human's input.
class BotBrain {
  BotBrain(this.botId, {required int seed, double? skill})
    : _rng = Random(seed),
      skill = skill ?? 0.4 + Random(seed).nextDouble() * 0.55;

  final String botId;
  final Random _rng;

  /// 0..1 — higher plans more often and digs straighter.
  final double skill;

  BotGoal goal = BotGoal.digDown;
  List<TilePos> _path = const [];
  TilePos? target;
  double _replanIn = 0;
  double _stuckFor = 0;
  double _lastX = 0, _lastY = 0;
  int? _lane;
  double _pause = 0;
  double _retreat = 0;
  double _rx = 0;
  int _tileKey = -1;
  double _tileStay = 0;

  BotDecision think(GameMap map, SimPlayer me, double dt, Set<TilePos> claimed, TilePos? revealedTreasure) {
    if (!me.alive) {
      _path = const [];
      _lane = null;
      return const BotDecision(PlayerInput.idle);
    }
    _lane ??= 2 + _rng.nextInt(map.width - 4);

    // Shopping on the surface (after spawning / respawning).
    UpgradeKind? buy;
    ItemKind? buyItem;
    if (me.inDepot) {
      for (final k in const [UpgradeKind.pickaxe, UpgradeKind.boots, UpgradeKind.helmet, UpgradeKind.armor, UpgradeKind.pickaxe]) {
        final lvl = me.upgrades[k.index];
        if (lvl < k.maxLevel && me.coins >= k.levels[lvl + 1].cost) {
          buy = k;
          break;
        }
      }
      if (buy == null && me.items[ItemKind.bomb.index] < 2 && me.coins >= itemDefs[ItemKind.bomb]!.cost && _rng.nextDouble() < 0.5) {
        buyItem = ItemKind.bomb;
      }
    }

    // Running from our own bomb (jumping over bumps on the way).
    if (_retreat > 0) {
      _retreat -= dt;
      return BotDecision(PlayerInput(dx: _rx, fx: _rx, fy: 0, jump: true), upgrade: buy, buyItem: buyItem);
    }

    // Treasure in sight? Drop everything.
    if (revealedTreasure != null && goal != BotGoal.treasure) {
      final dx = revealedTreasure.cx - me.x, dy = revealedTreasure.cy - me.y;
      if (dx * dx + dy * dy < pow(me.vision + 4, 2)) {
        goal = BotGoal.treasure;
        _replanIn = 0;
      }
    }

    // Stuck detection.
    final moved = (me.x - _lastX).abs() + (me.y - _lastY).abs();
    _lastX = me.x;
    _lastY = me.y;
    if (moved < 0.002 && me.mineCooldown <= 0) {
      _stuckFor += dt;
    } else {
      _stuckFor = 0;
    }
    // With gravity a bot can bounce (jump, fall back) without progress:
    // also count time spent in one tile without digging.
    final key = map.indexOf(me.x.floor(), me.y.floor());
    if (key != _tileKey || me.miningFlash > 0) {
      _tileKey = key;
      _tileStay = 0;
    } else {
      _tileStay += dt;
    }
    if (_stuckFor > 1.5 || _tileStay > 2.5) {
      _stuckFor = 0;
      _tileStay = 0;
      _path = const [];
      _replanIn = 0;
      _lane = 2 + _rng.nextInt(map.width - 4);
      if (goal == BotGoal.grabLoot) goal = BotGoal.digDown;
    }

    // People hesitate, look around, check their phone…
    if (_pause > 0) {
      _pause -= dt;
      return BotDecision(const PlayerInput(), upgrade: buy, buyItem: buyItem);
    }

    // Sometimes drop a bomb to blast through hard rock below, then run
    // sideways along open floor.
    if (me.items[ItemKind.bomb.index] > 0 && _path.length > 3 && goal == BotGoal.digDown && me.onGround && _rng.nextDouble() < dt * 0.08) {
      final solidAhead = _path.take(3).where((w) => map.tileAt(w.x, w.y).isMinable).length;
      final tx = me.x.floor(), ty = me.y.floor();
      bool runway(int dir) =>
          !map.isSolid(tx + dir, ty) && !map.isSolid(tx + dir * 2, ty) && map.isSolid(tx + dir, ty + 1) && map.isSolid(tx + dir * 2, ty + 1);
      final dir = runway(1) ? 1 : (runway(-1) ? -1 : 0);
      if (solidAhead >= 2 && dir != 0) {
        _rx = dir.toDouble();
        _retreat = itemDefs[ItemKind.bomb]!.fuse + 0.5;
        _path = const [];
        _replanIn = _retreat + 0.2;
        // Facing down drops the bomb at our feet.
        return BotDecision(const PlayerInput(fx: 0, fy: 1), upgrade: buy, useItem: ItemKind.bomb);
      }
    }

    _replanIn -= dt;
    if (_replanIn <= 0 || _path.isEmpty) {
      if (goal != BotGoal.treasure && _rng.nextDouble() < 0.06 + (1 - skill) * 0.12) {
        _pause = 0.3 + _rng.nextDouble() * 1.4;
      }
      _plan(map, me, claimed, revealedTreasure);
      _replanIn = 1.0 + (1 - skill) * 1.5 + _rng.nextDouble() * 0.5;
    }
    return BotDecision(_follow(map, me), upgrade: buy, buyItem: buyItem);
  }

  void _plan(GameMap map, SimPlayer me, Set<TilePos> claimed, TilePos? revealedTreasure) {
    final here = TilePos(me.x.floor(), me.y.floor());
    final damage = me.gear(UpgradeKind.pickaxe).stat.toInt();
    final pf = DigPathfinder(map)..run(here, damage, budget: 2500);

    if (goal == BotGoal.treasure && revealedTreasure != null) {
      target = revealedTreasure;
      _path = pf.pathTo(revealedTreasure);
      if (_path.isNotEmpty) return;
      goal = BotGoal.digDown;
    }

    // Loot inside the helmet light, if it's cheap to reach.
    final v = me.vision;
    TilePos? bestLoot;
    var bestScore = 0.0;
    for (var y = (me.y - v).floor(); y <= (me.y + v).ceil(); y++) {
      for (var x = (me.x - v).floor(); x <= (me.x + v).ceil(); x++) {
        if (!map.inBounds(x, y)) continue;
        final ore = map.tileAt(x, y).ore;
        if (ore == null) continue;
        final pos = TilePos(x, y);
        if (claimed.contains(pos)) continue;
        final c = pf.cost[map.indexOf(x, y)];
        if (!c.isFinite) continue;
        final s = oreDefs[ore]!.value / (c + 3);
        if (s > bestScore) {
          bestScore = s;
          bestLoot = pos;
        }
      }
    }
    // Greedier bots detour for less; everyone detours for diamonds and money.
    if (bestLoot != null && bestScore > 1.2 - skill * 0.6) {
      goal = BotGoal.grabLoot;
      target = bestLoot;
      _path = pf.pathTo(bestLoot);
      return;
    }

    // Dig down along our lane: deepest reachable tile, close to the lane.
    goal = BotGoal.digDown;
    final lane = _lane!;
    TilePos? best;
    var bestVal = -double.infinity;
    for (var i = 0; i < pf.cost.length; i++) {
      final c = pf.cost[i];
      if (!c.isFinite) continue;
      final x = i % map.width, y = i ~/ map.width;
      if (y > here.y + 12) continue; // plan in short hops
      final val = y * 3.0 - c * 0.6 - (x - lane).abs() * 1.2;
      if (val > bestVal) {
        bestVal = val;
        best = TilePos(x, y);
      }
    }
    if (best == null || best.y <= here.y) {
      // Can't go deeper here (lava below?) — sweep sideways to search.
      _lane = (lane + (_rng.nextBool() ? 6 : -6)).clamp(2, map.width - 3);
    }
    target = best;
    _path = best == null ? const [] : pf.pathTo(best);
  }

  /// Turns the next waypoint into stick/jump/dig input, respecting gravity.
  PlayerInput _follow(GameMap map, SimPlayer me) {
    final cx = me.x.floor(), cy = me.y.floor();
    // Falling can skip several waypoints at once.
    final at = _path.indexWhere((w) => w.x == cx && w.y == cy);
    if (at >= 0) _path = _path.sublist(at + 1);
    if (_path.isEmpty) return const PlayerInput();

    final w = _path.first;
    final dirX = w.x - cx, dirY = w.y - cy;
    if (dirX.abs() + dirY.abs() != 1) {
      // Knocked or fell off the route: plan again from here.
      _path = const [];
      _replanIn = 0;
      return const PlayerInput();
    }
    final tile = map.tileAt(w.x, w.y);
    if (tile == TileType.lava || tile == TileType.bedrock) {
      _path = const [];
      return const PlayerInput();
    }
    // Stay centred in the column when moving vertically.
    final centre = ((w.cx - me.x) * 3).clamp(-1.0, 1.0);
    final steer = centre.abs() < 0.12 ? 0.0 : centre;

    if (tile.isMinable) {
      if (dirY != 0) return PlayerInput(dx: steer * 0.5, fx: 0, fy: dirY.toDouble(), mine: true);
      return PlayerInput(dx: dirX * 0.2, fx: dirX.toDouble(), fy: 0, mine: true);
    }
    if (dirY < 0) {
      // Up into open space: jump (or climb a shaft).
      // Up into open space: jump, then jetpack the rest of the way.
      return PlayerInput(dx: steer, dy: -1, fx: 0, fy: -1, jump: me.onGround, jet: !me.onGround && me.fuel > 15 && me.vy > -2);
    }
    if (dirY > 0) return PlayerInput(dx: steer, fx: 0, fy: 1);
    // Sideways: walk, hop up if there's a lip in the way.
    final blocked = map.isSolid(w.x, cy) || (me.onGround && me.vx.abs() < 0.2 && map.isSolid(cx + dirX, cy));
    return PlayerInput(dx: dirX.toDouble(), fx: dirX.toDouble(), fy: 0, jump: blocked);
  }
}
