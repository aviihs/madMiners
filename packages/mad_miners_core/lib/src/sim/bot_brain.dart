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
  double _rx = 0, _ry = -1;

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

    // Running from our own bomb.
    if (_retreat > 0) {
      _retreat -= dt;
      return BotDecision(PlayerInput(dx: _rx, dy: _ry, fx: _rx, fy: _ry), upgrade: buy, buyItem: buyItem);
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
    if (_stuckFor > 1.5) {
      _stuckFor = 0;
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

    // Sometimes blast through a long stretch of hard rock, then back off.
    if (me.items[ItemKind.bomb.index] > 0 && _path.length > 3 && goal == BotGoal.digDown && _rng.nextDouble() < dt * 0.08) {
      final solidAhead = _path.take(3).where((w) => map.tileAt(w.x, w.y).isMinable).length;
      if (solidAhead >= 2 && map.tileAt(me.x.floor(), me.y.floor()) == TileType.empty) {
        final w = _path.first;
        final ax = w.cx - me.x, ay = w.cy - me.y;
        final len = sqrt(ax * ax + ay * ay).clamp(0.001, 99);
        _rx = -ax / len;
        _ry = -ay / len;
        _retreat = itemDefs[ItemKind.bomb]!.fuse + 0.6;
        _path = const [];
        _replanIn = _retreat + 0.2;
        return BotDecision(PlayerInput(dx: _rx, dy: _ry, fx: _rx, fy: _ry), upgrade: buy, useItem: ItemKind.bomb);
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

  PlayerInput _follow(GameMap map, SimPlayer me) {
    while (_path.isNotEmpty) {
      final w = _path.first;
      final reached = me.x.floor() == w.x &&
          me.y.floor() == w.y &&
          (me.x - w.cx).abs() < 0.3 &&
          (me.y - w.cy).abs() < 0.3;
      if (!reached) break;
      _path = _path.sublist(1);
    }
    if (_path.isEmpty) return const PlayerInput();

    final w = _path.first;
    final tile = map.tileAt(w.x, w.y);
    if (tile == TileType.lava || tile == TileType.bedrock) {
      _path = const [];
      return const PlayerInput();
    }
    var dx = w.cx - me.x, dy = w.cy - me.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len > 0.001) {
      dx /= len;
      dy /= len;
    }
    if (tile.isMinable) {
      return PlayerInput(dx: dx * 0.35, dy: dy * 0.35, fx: dx, fy: dy, mine: true);
    }
    return PlayerInput(dx: dx, dy: dy, fx: dx, fy: dy);
  }
}
