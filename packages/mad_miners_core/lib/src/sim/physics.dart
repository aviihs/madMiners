import 'dart:math';

import '../config/balance.dart';
import '../world/game_map.dart';

/// Shared movement + reach rules. Used by the server simulation and by the
/// client for local prediction, so both agree on collisions.
abstract final class Physics {
  static const double _r = Balance.playerRadius;
  static const double _eps = 0.001;

  static bool collides(GameMap map, double x, double y) {
    final x0 = (x - _r).floor(), x1 = (x + _r).floor();
    final y0 = (y - _r).floor(), y1 = (y + _r).floor();
    for (var ty = y0; ty <= y1; ty++) {
      for (var tx = x0; tx <= x1; tx++) {
        if (map.isSolid(tx, ty)) return true;
      }
    }
    return false;
  }

  /// Moves a miner with axis-separated collision. Returns the new position.
  static (double, double) step(GameMap map, double x, double y, double vx, double vy, double dt) {
    var nx = x + vx * dt;
    if (collides(map, nx, y)) {
      nx = vx > 0 ? (nx + _r).floor() - _r - _eps : (nx - _r).floor() + 1 + _r + _eps;
      if (collides(map, nx, y)) nx = x;
    }
    var ny = y + vy * dt;
    if (collides(map, nx, ny)) {
      ny = vy > 0 ? (ny + _r).floor() - _r - _eps : (ny - _r).floor() + 1 + _r + _eps;
      if (collides(map, nx, ny)) ny = y;
    }

    // Corner assist: pushing into a 1-tile-wide opening that you're slightly
    // misaligned with slides you toward its centre, so shafts and tunnels
    // are easy to enter with a joystick.
    const blockedEps = 0.0005;
    if (vy.abs() > vx.abs() && (ny - y).abs() < blockedEps) {
      final ahead = (y + vy.sign * (_r + 0.1)).floor();
      final col = nx.floor();
      if (!map.isSolid(col, ahead)) {
        final step = ((col + 0.5) - nx).clamp(-vy.abs() * dt, vy.abs() * dt);
        if (!collides(map, nx + step, ny)) nx += step;
      }
    } else if (vx.abs() > vy.abs() && (nx - x).abs() < blockedEps) {
      final ahead = (x + vx.sign * (_r + 0.1)).floor();
      final row = ny.floor();
      if (!map.isSolid(ahead, row)) {
        final step = ((row + 0.5) - ny).clamp(-vx.abs() * dt, vx.abs() * dt);
        if (!collides(map, nx, ny + step)) ny += step;
      }
    }
    return (nx, ny);
  }

  static double speedFor(double stamina, {double boots = 1}) =>
      Balance.moveSpeed * boots * (stamina < Balance.staminaPerHit ? Balance.tiredSpeedFactor : 1);

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
