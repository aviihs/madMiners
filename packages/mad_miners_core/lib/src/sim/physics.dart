import 'dart:math';

import '../config/balance.dart';
import '../world/game_map.dart';

/// Result of one [Physics.move] step.
class MoveResult {
  const MoveResult(this.x, this.y, this.vx, this.vy, {required this.onGround, required this.impact, required this.climbing});
  final double x;
  final double y;
  final double vx;
  final double vy;
  final bool onGround;

  /// Downward speed at the moment of landing this step (0 if no landing).
  final double impact;
  final bool climbing;
}

/// Shared side-view movement rules: gravity, running, jumping, climbing
/// 1-wide shafts, and tile collisions. Used by the server simulation and by
/// the client for local prediction, so both agree.
abstract final class Physics {
  static const double _r = Balance.playerRadius;
  static const double _eps = 0.001;

  static bool collides(GameMap map, double x, double y, [double r = _r]) {
    final x0 = (x - r).floor(), x1 = (x + r).floor();
    final y0 = (y - r).floor(), y1 = (y + r).floor();
    for (var ty = y0; ty <= y1; ty++) {
      for (var tx = x0; tx <= x1; tx++) {
        if (map.isSolid(tx, ty)) return true;
      }
    }
    return false;
  }

  static bool onGround(GameMap map, double x, double y, [double r = _r]) => collides(map, x, y + 0.04, r);

  /// Inside a 1-wide shaft: walls on both sides of the miner's tile.
  static bool inChimney(GameMap map, double x, double y) {
    final tx = x.floor(), ty = y.floor();
    return map.isSolid(tx - 1, ty) && map.isSolid(tx + 1, ty) && !map.isSolid(tx, ty);
  }

  static double _approach(double v, double target, double delta) =>
      v < target ? min(v + delta, target) : max(v - delta, target);

  /// Advances a miner by [dt].
  ///
  /// [moveX] is the stick (-1..1), [speed] the run speed, [jump] takes off
  /// when standing (or wedged in a shaft), [up] climbs a 1-wide shaft.
  static MoveResult move(
    GameMap map,
    double x,
    double y,
    double vx,
    double vy, {
    required double moveX,
    required double speed,
    required double dt,
    bool jump = false,
    bool up = false,
    bool jet = false,
    double jumpBoost = 1,
  }) {
    final grounded = onGround(map, x, y);
    vx = _approach(vx, moveX * speed, (grounded ? Balance.groundAccel : Balance.airAccel) * dt);

    // In a shaft you can kick off the walls, so jumping works there too.
    final chimney = inChimney(map, x, y);
    var climbing = false;
    if (jet) {
      // Jetpack: thrust beats gravity, up to a capped climb rate.
      vy = max(vy - (Balance.jetThrust - Balance.gravity) * dt, -Balance.jetMaxRise);
    } else if (jump && (grounded || chimney) && vy >= -0.01) {
      vy = -Balance.jumpSpeed * jumpBoost;
    } else if (chimney && up) {
      climbing = true;
      vy = -Balance.climbSpeed;
    } else {
      vy = min(vy + Balance.gravity * dt, Balance.maxFallSpeed);
    }

    // Sub-step so fast falls never tunnel through a tile.
    final dist = (vx.abs() + vy.abs()) * dt;
    final steps = max(1, (dist / 0.2).ceil());
    final h = dt / steps;
    var impact = 0.0;
    for (var i = 0; i < steps; i++) {
      final nx = x + vx * h;
      if (collides(map, nx, y)) {
        final snapped = vx > 0 ? (nx + _r).floor() - _r - _eps : (nx - _r).floor() + 1 + _r + _eps;
        x = collides(map, snapped, y) ? x : snapped;
        vx = 0;
      } else {
        x = nx;
      }
      final ny = y + vy * h;
      if (collides(map, x, ny)) {
        final snapped = vy > 0 ? (ny + _r).floor() - _r - _eps : (ny - _r).floor() + 1 + _r + _eps;
        if (vy > 0) impact = max(impact, vy);
        y = collides(map, x, snapped) ? y : snapped;
        vy = 0;
      } else {
        y = ny;
      }
    }

    // Hole assist: blocked vertically but the tile straight ahead (above
    // when jumping, below when standing) is open → slide toward its centre,
    // so dug shafts are easy to drop into and jump up through.
    final goingUp = jump || climbing || jet;
    if (vy.abs() < 0.01 && moveX.abs() < 0.35) {
      final col = x.floor();
      final row = goingUp ? (y - _r - 0.1).floor() : (y + _r + 0.1).floor();
      if (!map.isSolid(col, row)) {
        final off = (col + 0.5) - x;
        if (off.abs() > 0.01) {
          final step = off.clamp(-3.5 * dt, 3.5 * dt);
          if (!collides(map, x + step, y)) x += step;
        }
      }
    }

    return MoveResult(x, y, vx, vy, onGround: onGround(map, x, y), impact: impact, climbing: climbing);
  }

  static double speedFor(double stamina, {double boots = 1}) =>
      Balance.moveSpeed * boots * (stamina < Balance.staminaPerHit ? Balance.tiredSpeedFactor : 1);

  /// Better boots also jump a bit higher.
  static double jumpBoostFor(double boots) => sqrt(boots);

  /// Fall damage for a landing at [impact] tiles / second.
  static double fallDamage(double impact) =>
      impact <= Balance.safeFallSpeed ? 0 : (impact - Balance.safeFallSpeed) * Balance.fallDamagePerSpeed;

  /// The minable tile a miner at (x,y) facing (fx,fy) would hit, if any.
  static TilePos? mineTarget(GameMap map, double x, double y, double fx, double fy) {
    final len = sqrt(fx * fx + fy * fy);
    if (len < 0.01) return null;
    fx /= len;
    fy /= len;
    for (final reach in const [0.55, 0.95, 1.25]) {
      final tx = (x + fx * reach).floor();
      final ty = (y + fy * reach).floor();
      if (map.tileAt(tx, ty).isMinable) {
        return withinReach(x, y, TilePos(tx, ty)) ? TilePos(tx, ty) : null;
      }
    }
    return null;
  }

  static bool withinReach(double x, double y, TilePos t) {
    final dx = t.cx - x, dy = t.cy - y;
    return dx * dx + dy * dy <= Balance.mineReach * Balance.mineReach;
  }
}
