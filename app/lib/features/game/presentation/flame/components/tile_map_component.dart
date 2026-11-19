import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../controller/game_controller.dart';
import '../mad_miners_game.dart';

/// Draws only the tiles inside the camera view, every frame.
class TileMapComponent extends Component with HasGameReference<MadMinersGame> {
  TileMapComponent(this.controller) : super(priority: 0);

  final GameController controller;
  double _t = 0;

  static const double ts = MadMinersGame.tileSize;

  static final _paints = <TileType, Paint>{
    TileType.empty: Paint()..color = const Color(0xFF2A211B),
    TileType.depot: Paint()..color = const Color(0xFF6B4A2B),
    TileType.rock: Paint()..color = const Color(0xFF6E5F52),
    TileType.hardRock: Paint()..color = const Color(0xFF4D443D),
    TileType.bedrock: Paint()..color = const Color(0xFF151210),
    TileType.copper: Paint()..color = const Color(0xFF6E5F52),
    TileType.iron: Paint()..color = const Color(0xFF6E5F52),
    TileType.gold: Paint()..color = const Color(0xFF5E5148),
    TileType.diamond: Paint()..color = const Color(0xFF4D443D),
    TileType.crystal: Paint()..color = const Color(0xFF4D443D),
    TileType.lava: Paint()..color = const Color(0xFFD9481C),
    TileType.gas: Paint()..color = const Color(0xFF2A211B),
  };

  static const _oreColors = <TileType, Color>{
    TileType.copper: Color(0xFFD27D45),
    TileType.iron: Color(0xFFC9C3BA),
    TileType.gold: Color(0xFFFFCF3F),
    TileType.diamond: Color(0xFF7FE7FF),
    TileType.crystal: Color(0xFFD27BFF),
  };

  final _shade = Paint()..color = const Color(0x33000000);
  final _light = Paint()..color = const Color(0x22FFFFFF);
  final _gem = Paint();
  final _crack = Paint()
    ..color = const Color(0xCC1A1410)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
  final _aim = Paint()
    ..color = const Color(0xCCF2A93B)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  final _gas = Paint();
  final _lavaGlow = Paint();
  final _sky = Paint()..color = const Color(0xFF3B2F27);

  @override
  void update(double dt) => _t += dt;

  static int _hash(int x, int y) => ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff;

  @override
  void render(Canvas canvas) {
    final map = controller.map;
    if (map == null) return;
    final view = game.camera.visibleWorldRect;
    final x0 = max(0, (view.left / ts).floor() - 1), x1 = min(map.width - 1, (view.right / ts).ceil() + 1);
    final y0 = max(0, (view.top / ts).floor() - 1), y1 = min(map.height - 1, (view.bottom / ts).ceil() + 1);

    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final t = map.tileAt(x, y);
        final r = Rect.fromLTWH(x * ts, y * ts, ts, ts);
        final h = _hash(x, y);
        if (y < MapGenerator.surfaceRows && t == TileType.empty) {
          canvas.drawRect(r, _sky);
          continue;
        }
        canvas.drawRect(r, _paints[t]!);

        switch (t) {
          case TileType.empty:
            if (h % 7 == 0) canvas.drawCircle(Offset(r.left + (h % 23) + 4, r.top + (h % 17) + 6), 1.5, _shade);
          case TileType.depot:
            for (var i = 1; i < 4; i++) {
              canvas.drawLine(Offset(r.left, r.top + i * ts / 4), Offset(r.right, r.top + i * ts / 4), _shade);
            }
          case TileType.lava:
            final pulse = 0.5 + 0.5 * sin(_t * 3 + h % 10);
            _lavaGlow.color = Color.lerp(const Color(0xFFFF9B3D), const Color(0xFFFFE07A), pulse)!.withValues(alpha: 0.6);
            canvas.drawCircle(Offset(r.left + (h % 20) + 6, r.top + (h % 14) + 9), 5 + pulse * 3, _lavaGlow);
          case TileType.gas:
            final drift = sin(_t * 1.5 + h % 13);
            _gas.color = const Color(0xFF7BD34A).withValues(alpha: 0.25 + drift * 0.08);
            canvas.drawRect(r, _gas);
            canvas.drawCircle(Offset(r.center.dx + drift * 6, r.center.dy - drift * 4), 6, _gas);
          default:
            if (t.isSolid) _drawRock(canvas, r, t, h, map.hpAt(x, y));
        }
      }
    }

    final aim = controller.aimTile;
    if (aim != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(aim.x * ts + 2, aim.y * ts + 2, ts - 4, ts - 4), const Radius.circular(4)),
        _aim,
      );
    }
  }

  void _drawRock(Canvas canvas, Rect r, TileType t, int h, int hp) {
    // Bevel.
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, ts, 3), _light);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 3, ts, 3), _shade);

    final oreColor = _oreColors[t];
    if (oreColor != null) {
      final glint = t == TileType.crystal || t == TileType.diamond ? 0.75 + 0.25 * sin(_t * 4 + h % 7) : 1.0;
      _gem.color = oreColor.withValues(alpha: glint);
      for (var i = 0; i < 3; i++) {
        final ox = r.left + 6 + ((h >> (i * 4)) % 18);
        final oy = r.top + 6 + ((h >> (i * 4 + 2)) % 18);
        final s = 3.0 + (h >> i) % 3;
        canvas.drawPath(
          Path()
            ..moveTo(ox, oy - s)
            ..lineTo(ox + s, oy)
            ..lineTo(ox, oy + s)
            ..lineTo(ox - s, oy)
            ..close(),
          _gem,
        );
      }
    }

    // Damage cracks.
    final maxHp = t.maxHp;
    if (maxHp > 0 && hp < maxHp) {
      final dmg = 1 - hp / maxHp;
      final c = r.center;
      canvas.drawLine(c, c + Offset(-10 * dmg - 3, -9 * dmg), _crack);
      canvas.drawLine(c, c + Offset(11 * dmg + 2, -4 * dmg), _crack);
      if (dmg > 0.4) canvas.drawLine(c, c + Offset(4 * dmg, 12 * dmg), _crack);
      if (dmg > 0.7) canvas.drawLine(c, c + Offset(-12 * dmg, 8 * dmg), _crack);
    }
  }
}
