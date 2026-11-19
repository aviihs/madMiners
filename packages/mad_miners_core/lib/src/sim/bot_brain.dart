import 'dart:math';

import '../config/balance.dart';
import '../model/snapshot.dart';
import '../world/game_map.dart';
import '../world/tile.dart';
import 'pathfinding.dart';
import 'sim_player.dart';

enum BotGoal { seekOre, returnToDepot, wander }

/// What a bot wants to do this tick.
class BotDecision {
  const BotDecision(this.input, {this.upgrade});
  final PlayerInput input;
  final UpgradeKind? upgrade;
}

/// Simple utility AI: dig toward the most valuable reachable ore, go home when
/// the backpack is full / air is low / health is low, buy upgrades at depot.
///
/// Bots play by exactly the same rules as humans — they only produce
/// [PlayerInput]s, which the simulation validates like any other input.
class BotBrain {
  BotBrain(this.botId, {required int seed, double? skill})
    : _rng = Random(seed),
      skill = skill ?? 0.6 + Random(seed).nextDouble() * 0.4;

  final String botId;
  final Random _rng;

  /// 0..1 — higher plans more often and picks better targets.
  final double skill;

  BotGoal goal = BotGoal.seekOre;
  List<TilePos> _path = const [];
  TilePos? target;
  double _replanIn = 0;
  double _stuckFor = 0;
  double _lastX = 0, _lastY = 0;

  static const _upgradePriority = [
    UpgradeKind.pickaxe,
    UpgradeKind.backpack,
    UpgradeKind.oxygenTank,
    UpgradeKind.pickaxe,
    UpgradeKind.helmet,
  ];

  BotDecision think(GameMap map, SimPlayer me, double dt, Set<TilePos> claimed, double oxygenDepth) {
    if (!me.alive) {
      _path = const [];
      return const BotDecision(PlayerInput.idle);
    }

    // Shopping.
    UpgradeKind? buy;
    if (me.inDepot && me.carried == 0) {
      for (final k in _upgradePriority) {
        final lvl = me.upgrades[k.index];
        if (lvl < k.maxLevel && me.coins >= k.levels[lvl + 1].cost) {
          buy = k;
          break;
        }
      }
    }

    // Decide goal.
    final needsAir = me.y > oxygenDepth && me.oxygen < me.maxOxygen * 0.35;
    final wantHome = me.carried >= me.capacity || needsAir || me.hp < 40;
    final newGoal = wantHome ? BotGoal.returnToDepot : BotGoal.seekOre;
    if (newGoal != goal) {
      goal = newGoal;
      _replanIn = 0;
    }
    if (goal == BotGoal.returnToDepot && me.inDepot && !wantHome) _replanIn = 0;

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
      goal = BotGoal.wander;
    }

    _replanIn -= dt;
    if (_replanIn <= 0 || _path.isEmpty) {
      _plan(map, me, claimed);
      _replanIn = 1.2 + (1 - skill) * 2 + _rng.nextDouble();
    }

    return BotDecision(_follow(map, me), upgrade: buy);
  }

  void _plan(GameMap map, SimPlayer me, Set<TilePos> claimed) {
    final here = TilePos(me.x.floor(), me.y.floor());
    final damage = me.gear(UpgradeKind.pickaxe).stat.toInt();
    final pf = DigPathfinder(map)..run(here, damage);
    target = null;

    if (goal == BotGoal.returnToDepot) {
      TilePos? best;
      var bestCost = double.infinity;
      for (final d in map.depotTiles) {
        final c = pf.cost[map.indexOf(d.x, d.y)];
        if (c < bestCost) {
          bestCost = c;
          best = d;
        }
      }
      _path = best == null ? const [] : pf.pathTo(best);
      target = best;
      return;
    }

    if (goal == BotGoal.wander) {
      final candidates = <TilePos>[];
      for (var i = 0; i < 30; i++) {
        final t = TilePos(here.x + _rng.nextInt(9) - 4, here.y + _rng.nextInt(9) - 4);
        if (map.inBounds(t.x, t.y) && pf.cost[map.indexOf(t.x, t.y)].isFinite) candidates.add(t);
      }
      goal = BotGoal.seekOre;
      if (candidates.isNotEmpty) {
        target = candidates[_rng.nextInt(candidates.length)];
        _path = pf.pathTo(target!);
      }
      return;
    }

    // Best ore by value per effort, ignoring ores other bots already chase.
    var bestScore = 0.0;
    TilePos? best;
    for (var i = 0; i < pf.cost.length; i++) {
      final c = pf.cost[i];
      if (!c.isFinite) continue;
      final ore = map.tileAtIndex(i).ore;
      if (ore == null) continue;
      final pos = TilePos(i % map.width, i ~/ map.width);
      if (claimed.contains(pos)) continue;
      final value = oreDefs[ore]!.value.toDouble();
      final noise = 1 + (_rng.nextDouble() - 0.5) * (1 - skill);
      final score = value * noise / (c + 4);
      if (score > bestScore) {
        bestScore = score;
        best = pos;
      }
    }
    if (best != null) {
      target = best;
      _path = pf.pathTo(best);
    } else {
      goal = BotGoal.wander;
      _path = const [];
    }
  }

  PlayerInput _follow(GameMap map, SimPlayer me) {
    // Drop waypoints we've reached.
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
    var dx = w.cx - me.x, dy = w.cy - me.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len > 0.001) {
      dx /= len;
      dy /= len;
    }
    final tile = map.tileAt(w.x, w.y);
    if (tile.isMinable) {
      // Dig toward the waypoint. Keep nudging so the hitbox lines up.
      return PlayerInput(dx: dx * 0.35, dy: dy * 0.35, fx: dx, fy: dy, mine: true);
    }
    if (tile == TileType.bedrock) {
      _path = const [];
      return const PlayerInput();
    }
    return PlayerInput(dx: dx, dy: dy, fx: dx, fy: dy);
  }
}
