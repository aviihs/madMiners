import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../controller/game_controller.dart';
import '../mad_miners_game.dart';
import '../palette.dart';

/// Draws the visible part of the mine every frame: sky + camp, layered rock
/// with edge shading, ores, hazards and the shop hut.
class TileMapComponent extends Component with HasGameReference<MadMinersGame> {
  TileMapComponent(this.controller) : super(priority: 0);

  final GameController controller;
  double _t = 0;
  static const double ts = MadMinersGame.tileSize;

  final _p = Paint();
  final _shadow = Paint()..color = const Color(0x59000000);
  final _light = Paint()..color = const Color(0x1FFFFFFF);
  final _crack = Paint()
    ..color = const Color(0xCC140E0B)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final _aim = Paint()
    ..color = const Color(0xE6FFFFFF)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
  final _signText = TextPaint(style: const TextStyle(fontFamily: 'Lilita', fontSize: 14, color: Color(0xFF3A2414), letterSpacing: 1.2));

  @override
  void update(double dt) => _t += dt;

  static int _hash(int x, int y) => ((x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995) & 0x7fffffff;

  @override
  void render(Canvas canvas) {
    final map = controller.map;
    if (map == null) return;
    final view = game.camera.visibleWorldRect;
    final x0 = max(0, (view.left / ts).floor() - 1), x1 = min(map.width - 1, (view.right / ts).ceil() + 1);
    final y0 = max(0, (view.top / ts).floor() - 1), y1 = min(map.height - 1, (view.bottom / ts).ceil() + 1);
    final lavaTop = map.height - 1 - controller.settings.mapId.def.lavaRows;
    const surface = MapGenerator.surfaceRows;

    if (y0 < surface) _drawSky(canvas, map, view);

    for (var y = max(y0, surface - 1); y <= y1; y++) {
      final d = ((y - surface) / max(1, lavaTop - surface)).clamp(0.0, 1.0);
      for (var x = x0; x <= x1; x++) {
        final t = map.tileAt(x, y);
        if (y < surface && t != TileType.depot) continue;
        final r = Rect.fromLTWH(x * ts, y * ts, ts, ts);
        final h = _hash(x, y);
        switch (t) {
          case TileType.empty:
            _drawBackWall(canvas, map, r, x, y, h, d);
          case TileType.spikes:
            _drawBackWall(canvas, map, r, x, y, h, d);
            _drawSpikes(canvas, r, h);
          case TileType.boulder:
            _drawBackWall(canvas, map, r, x, y, h, d);
            _drawBoulder(canvas, map, r, x, y, h, d);
          case TileType.depot:
            _drawDepotFloor(canvas, r, h);
          case TileType.lava:
            _drawLava(canvas, r, h, map.tileAt(x, y - 1) != TileType.lava);
          case TileType.gas:
            _drawBackWall(canvas, map, r, x, y, h, d);
            _drawGas(canvas, r, h);
          case TileType.bedrock:
            _p.color = const Color(0xFF0F0C0B);
            canvas.drawRect(r, _p);
          default:
            _drawSolid(canvas, map, r, x, y, t, h, d);
        }
      }
    }

    if (y0 <= surface) _drawShopHut(canvas, map);

    final aim = controller.aimTile;
    if (aim != null) {
      final pulse = 0.6 + 0.4 * sin(_t * 8);
      _aim.color = Color.fromRGBO(255, 255, 255, 0.5 + 0.4 * pulse);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(aim.x * ts + 1.5, aim.y * ts + 1.5, ts - 3, ts - 3), const Radius.circular(6)), _aim);
    }
  }

  // ---- pieces ---------------------------------------------------------------

  /// Dug-out space: the darker rock face behind the tunnel, with ambient
  /// occlusion where it meets solid rock.
  void _drawBackWall(Canvas canvas, GameMap map, Rect r, int x, int y, int h, double d) {
    final base = MinePalette.tinted(MinePalette.shade(MinePalette.tunnel(d), ((h % 9) - 4) / 110), d);
    _p.color = base;
    canvas.drawRect(r, _p);
    // Faint stones in the back wall.
    _p.color = MinePalette.shade(base, 0.06);
    canvas.drawOval(Rect.fromLTWH(r.left + (h % 17) + 2, r.top + (h >> 5) % 18 + 3, 10, 6), _p);
    _p.color = MinePalette.shade(base, -0.18);
    canvas.drawOval(Rect.fromLTWH(r.left + (h >> 9) % 18 + 6, r.top + (h >> 2) % 16 + 12, 7, 4), _p);
    if (h % 7 == 0) {
      _crack.color = MinePalette.shade(base, -0.3);
      canvas.drawLine(Offset(r.left + 6 + h % 12, r.top + 4), Offset(r.left + 12 + h % 9, r.top + 16), _crack);
      _crack.color = const Color(0xCC140E0B);
    }
    // Ambient occlusion from neighbouring rock.
    if (map.isSolid(x, y - 1)) canvas.drawRect(Rect.fromLTWH(r.left, r.top, ts, 8), _shadow);
    if (map.isSolid(x, y - 1)) canvas.drawRect(Rect.fromLTWH(r.left, r.top, ts, 3), _shadow);
    if (map.isSolid(x - 1, y)) canvas.drawRect(Rect.fromLTWH(r.left, r.top, 5, ts), _shadow);
    if (map.isSolid(x + 1, y)) canvas.drawRect(Rect.fromLTWH(r.right - 5, r.top, 5, ts), _shadow);
    // Rubble on the floor.
    if (map.isSolid(x, y + 1)) {
      _p.color = MinePalette.shade(MinePalette.rock(d, hard: d > 0.5), -0.1);
      canvas.drawOval(Rect.fromLTWH(r.left + (h % 14) + 2, r.bottom - 4, 6, 4), _p);
      canvas.drawOval(Rect.fromLTWH(r.left + (h >> 4) % 12 + 16, r.bottom - 3, 4, 3), _p);
    }
  }

  /// Mystery Bomb: metal shell, pulsing violet core, strange glyphs. Every
  /// rarity looks the same until it's opened.
  void _drawMystery(Canvas canvas, Rect r, int h) {
    final pulse = 0.5 + 0.5 * sin(_t * 3.2 + h % 7);
    final c = r.center;
    _p.shader = Gradient.radial(c, ts * 0.9, [Color.fromRGBO(176, 107, 255, 0.55 * pulse + 0.2), const Color(0x00B06BFF)]);
    canvas.drawCircle(c, ts * 0.9, _p);
    _p.shader = null;
    _p.color = const Color(0xFF3A3F4A);
    canvas.drawCircle(c, ts * 0.36, _p);
    _p.color = const Color(0xFF6B7280);
    canvas.drawCircle(c + const Offset(-3, -3), ts * 0.14, _p);
    _p.color = Color.lerp(const Color(0xFF7B4FD6), const Color(0xFFE0B3FF), pulse)!;
    canvas.drawCircle(c, ts * 0.17, _p);
    // Glowing cracks / glyphs around the shell.
    _crack.color = Color.fromRGBO(224, 179, 255, 0.5 + 0.5 * pulse);
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2 + _t * 0.8;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * ts * 0.2, c + Offset(cos(a + 0.3), sin(a + 0.3)) * ts * 0.34, _crack);
    }
    _crack.color = const Color(0xCC140E0B);
    _signText.render(canvas, '?', Vector2(c.dx, c.dy - ts * 0.62), anchor: Anchor.center);
  }

  /// Rusty floor spikes.
  void _drawSpikes(Canvas canvas, Rect r, int h) {
    _p.color = const Color(0xFF3A3530);
    canvas.drawRect(Rect.fromLTWH(r.left + 1, r.bottom - 4, ts - 2, 4), _p);
    for (var i = 0; i < 4; i++) {
      final x = r.left + 4 + i * 8.0;
      final tall = 12.0 + (h >> i) % 5;
      final spike = Path()
        ..moveTo(x - 3.5, r.bottom - 3)
        ..lineTo(x, r.bottom - 3 - tall)
        ..lineTo(x + 3.5, r.bottom - 3)
        ..close();
      _p.color = const Color(0xFF9AA3AD);
      canvas.drawPath(spike, _p);
      _p.color = const Color(0xFF5E6670);
      canvas.drawPath(Path()..moveTo(x, r.bottom - 3 - tall)..lineTo(x + 3.5, r.bottom - 3)..lineTo(x, r.bottom - 3)..close(), _p);
      _p.color = const Color(0x99A0522D); // rust / old blood
      canvas.drawCircle(Offset(x, r.bottom - 3 - tall + 3), 1.2, _p);
    }
  }

  /// Wooden TNT crate with a hazard stripe.
  void _drawCrate(Canvas canvas, Rect r) {
    final box = r.deflate(2);
    _p.color = const Color(0xFF9C2A1E);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(3)), _p);
    _p.color = const Color(0xFF6E1A12);
    canvas.drawRect(Rect.fromLTWH(box.left, box.top, box.width, 3), _p);
    canvas.drawRect(Rect.fromLTWH(box.left, box.bottom - 3, box.width, 3), _p);
    _p.color = const Color(0xFFFFC233);
    canvas.drawRect(Rect.fromLTWH(box.left, box.center.dy - 4, box.width, 8), _p);
    _p.color = const Color(0xFF1E1E22);
    for (var i = 0; i < 4; i++) {
      final x = box.left + i * 7.0;
      canvas.drawPath(Path()..moveTo(x, box.center.dy + 4)..lineTo(x + 4, box.center.dy - 4)..lineTo(x + 7, box.center.dy - 4)..lineTo(x + 3, box.center.dy + 4)..close(), _p);
    }
    final blink = sin(_t * 5) > 0.7;
    _p.color = blink ? const Color(0xFFFF453A) : const Color(0x88FF453A);
    canvas.drawCircle(Offset(box.right - 4, box.top + 6), 1.8, _p);
  }

  /// A loose boulder: round, heavy, and wobbling when nothing holds it up.
  void _drawBoulder(Canvas canvas, GameMap map, Rect r, int x, int y, int h, double d) {
    final loose = !map.isSolid(x, y + 1);
    final wob = loose ? sin(_t * 28) * 1.2 : 0.0;
    final c = r.center + Offset(wob, 1);
    const rad = ts * 0.47;
    _p.color = const Color(0x66000000);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, r.bottom - 2), width: ts * 0.9, height: 6), _p);
    final base = MinePalette.shade(const Color(0xFF9A8A78), d * -0.2);
    _p.shader = Gradient.radial(c + const Offset(-5, -6), rad * 1.4, [
      MinePalette.shade(base, 0.28),
      base,
      MinePalette.shade(base, -0.45),
    ], const [0, 0.5, 1]);
    canvas.drawCircle(c, rad, _p);
    _p.shader = null;
    _p.color = MinePalette.shade(base, -0.25);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(4.0 + h % 3, 3), width: 7, height: 5), _p);
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(-4, 5), width: 4, height: 3), _p);
    _crack.color = MinePalette.shade(base, -0.5);
    canvas.drawLine(c + const Offset(-6, -2), c + const Offset(0, 1), _crack);
    _crack.color = const Color(0xCC140E0B);
    final hp = map.hpAt(x, y), maxHp = TileType.boulder.maxHp;
    if (hp < maxHp) _drawCracks(canvas, r, 1 - hp / maxHp, h);
  }

  void _drawSky(Canvas canvas, GameMap map, Rect view) {
    final top = min(0.0, view.top - ts);
    final sky = Rect.fromLTRB(view.left - ts, top, view.right + ts, MapGenerator.surfaceRows * ts);
    _p.shader = Gradient.linear(
      Offset(0, -6 * ts),
      Offset(0, MapGenerator.surfaceRows * ts),
      const [Color(0xFF1E2A4F), Color(0xFF2B3A67), Color(0xFFB8664A), Color(0xFFF2A65A)],
      const [0, 0.35, 0.78, 1],
    );
    canvas.drawRect(sky, _p);
    _p.shader = null;
    // Sun.
    _p.color = const Color(0x55FFE3A3);
    canvas.drawCircle(Offset(map.width * ts * 0.78, ts * 3.2), ts * 1.6, _p);
    _p.color = const Color(0xFFFFE3A3);
    canvas.drawCircle(Offset(map.width * ts * 0.78, ts * 3.2), ts * 0.9, _p);
    // Far mountains (slow parallax), drifting clouds.
    final camX = game.camera.viewfinder.position.x;
    final far = Path()..moveTo(view.left - ts, MapGenerator.surfaceRows * ts);
    for (var sx = view.left - ts; sx <= view.right + ts; sx += ts) {
      final wx = sx + camX * -0.6;
      far.lineTo(sx, MapGenerator.surfaceRows * ts - ts * (2.6 + 1.2 * sin(wx / (ts * 7)) + 0.6 * sin(wx / (ts * 2.3))));
    }
    far
      ..lineTo(view.right + ts, MapGenerator.surfaceRows * ts)
      ..close();
    _p.color = const Color(0xFF7A5568);
    canvas.drawPath(far, _p);
    for (var i = 0; i < 5; i++) {
      final cx = ((i * 9.7 + _t * (0.25 + i * 0.05)) % (map.width + 12) - 6) * ts;
      final cy = ts * (0.6 + (i * 37 % 5) * 0.35);
      _p.color = const Color(0x55FFF1E0);
      for (final (ox, oy, rr) in const [(0.0, 0.0, 0.55), (0.6, -0.2, 0.7), (1.3, 0.05, 0.5)]) {
        canvas.drawCircle(Offset(cx + ox * ts, cy + oy * ts), rr * ts, _p);
      }
    }
    // Distant hills.
    final hills = Path()..moveTo(0, MapGenerator.surfaceRows * ts);
    for (var x = 0.0; x <= map.width * ts; x += ts * 2) {
      hills.lineTo(x, MapGenerator.surfaceRows * ts - ts * (1.2 + 0.9 * sin(x / (ts * 5)) + 0.4 * sin(x / (ts * 1.7))));
    }
    hills
      ..lineTo(map.width * ts, MapGenerator.surfaceRows * ts)
      ..close();
    _p.color = const Color(0xFF5B3A2E);
    canvas.drawPath(hills, _p);
    // Pine trees along the surface, away from the camp.
    final depots = controller.depotXs;
    for (var x = 2; x < map.width - 2; x += 3) {
      final h = _hash(x, 99);
      if (h % 3 == 0) continue;
      if (depots.isNotEmpty && x >= depots.first - 3 && x <= depots.last + 3) continue;
      _drawPine(canvas, (x + 0.5 + (h % 10) / 20) * ts, MapGenerator.surfaceRows * ts, 1.6 + (h % 7) / 6);
    }
  }

  void _drawPine(Canvas canvas, double x, double ground, double size) {
    _p.color = const Color(0xFF4A2F1E);
    canvas.drawRect(Rect.fromLTWH(x - 2.5, ground - ts * 0.5 * size, 5, ts * 0.5 * size), _p);
    for (var i = 0; i < 3; i++) {
      final w = ts * (0.9 - i * 0.22) * size;
      final top = ground - ts * (0.55 + i * 0.42 + 0.7) * size;
      _p.color = i.isEven ? const Color(0xFF2F5A2C) : const Color(0xFF3B6E35);
      canvas.drawPath(
        Path()
          ..moveTo(x, top)
          ..lineTo(x + w / 2, top + ts * 0.75 * size)
          ..lineTo(x - w / 2, top + ts * 0.75 * size)
          ..close(),
        _p,
      );
    }
  }

  void _drawSolid(Canvas canvas, GameMap map, Rect r, int x, int y, TileType t, int h, double d) {
    final hard = t == TileType.hardRock || t == TileType.diamond || t == TileType.treasure || (d > 0.5 && t.ore != null);
    final base = t == TileType.dirt
        ? MinePalette.shade(MinePalette.dirt, ((h % 11) - 5) / 70)
        : t == TileType.obsidian
        ? MinePalette.shade(const Color(0xFF221A2E), ((h % 11) - 5) / 120)
        : MinePalette.tinted(MinePalette.shade(MinePalette.rock(d, hard: hard), ((h % 11) - 5) / 90), d);
    _p.color = base;
    canvas.drawRect(r, _p);

    // Rock strata: faint horizontal bands that continue across tiles.
    if (y % 3 == 0) {
      _p.color = MinePalette.shade(base, -0.07);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top + 9 + (x * 3 + y) % 5, ts, 3), _p);
    }
    // Pebbles for texture.
    _p.color = MinePalette.shade(base, 0.08);
    canvas.drawOval(Rect.fromLTWH(r.left + (h % 13) + 3, r.top + (h >> 4) % 12 + 4, 9, 6), _p);
    _p.color = MinePalette.shade(base, -0.12);
    canvas.drawOval(Rect.fromLTWH(r.left + (h >> 7) % 14 + 12, r.top + (h >> 3) % 10 + 16, 7, 5), _p);

    if (t == TileType.dirt) {
      // Loose soil: grainy specks and the odd root.
      for (var i = 0; i < 6; i++) {
        _p.color = MinePalette.shade(base, i.isEven ? -0.18 : 0.12);
        canvas.drawCircle(Offset(r.left + 3 + (h >> (i * 2)) % 26, r.top + 3 + (h >> (i * 3 + 1)) % 26), 1.3, _p);
      }
      if (h % 5 == 0) {
        _crack.color = const Color(0xFF5A3A22);
        canvas.drawLine(Offset(r.left + 4, r.top + 6 + h % 10), Offset(r.left + 18, r.top + 12 + h % 12), _crack);
        _crack.color = const Color(0xCC140E0B);
      }
    }

    // Edge lighting against open space.
    final openAbove = !map.isSolid(x, y - 1) && map.tileAt(x, y - 1) != TileType.bedrock;
    final openBelow = !map.isSolid(x, y + 1);
    if (openAbove) {
      if (y == MapGenerator.surfaceRows) {
        _p.color = const Color(0xFF5E8F3A); // grass at the surface
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, ts, 5), _p);
        _p.color = const Color(0xFF7CB24C);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, ts, 2), _p);
      } else {
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, ts, 3), _light);
      }
    }
    if (openBelow) canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 4, ts, 4), _shadow);
    if (!map.isSolid(x - 1, y)) canvas.drawRect(Rect.fromLTWH(r.left, r.top, 2, ts), _light);
    if (!map.isSolid(x + 1, y)) canvas.drawRect(Rect.fromLTWH(r.right - 3, r.top, 3, ts), _shadow);

    switch (t) {
      case TileType.copper || TileType.iron || TileType.gold || TileType.coal || TileType.silver:
        _drawNuggets(canvas, r, h, MinePalette.ore[t]!, sparkle: t == TileType.gold || t == TileType.silver);
      case TileType.diamond:
        _drawGems(canvas, r, h);
      case TileType.emerald || TileType.ruby:
        _drawGems(canvas, r, h, color: MinePalette.ore[t]!);
      case TileType.obsidian:
        _p.color = const Color(0x55B06BFF);
        canvas.drawPath(Path()..moveTo(r.left + 6, r.top + 4)..lineTo(r.left + 14, r.top + 4)..lineTo(r.left + 8, r.top + 16)..close(), _p);
        _p.color = const Color(0x33FFFFFF);
        canvas.drawLine(Offset(r.left + 18, r.top + 8), Offset(r.left + 26, r.top + 22), _p..strokeWidth = 1.5);
      case TileType.mystery:
        _drawMystery(canvas, r, h);
      case TileType.moneyBag:
        _drawCoins(canvas, r);
      case TileType.treasure:
        _drawChest(canvas, r);
      case TileType.explosive:
        _drawCrate(canvas, r);
      default:
        break;
    }

    final maxHp = t.maxHp;
    final hp = map.hpAt(x, y);
    if (maxHp > 0 && hp < maxHp) _drawCracks(canvas, r, 1 - hp / maxHp, h);
  }

  void _drawNuggets(Canvas canvas, Rect r, int h, Color c, {bool sparkle = false}) {
    for (var i = 0; i < 4; i++) {
      final ox = r.left + 5 + ((h >> (i * 3)) % 20);
      final oy = r.top + 5 + ((h >> (i * 3 + 5)) % 20);
      final s = 3.0 + (h >> i) % 3;
      _p.color = MinePalette.shade(c, -0.35);
      canvas.drawCircle(Offset(ox + 1, oy + 1.2), s, _p);
      _p.color = c;
      canvas.drawCircle(Offset(ox, oy), s, _p);
      _p.color = MinePalette.shade(c, 0.5);
      canvas.drawCircle(Offset(ox - s * 0.35, oy - s * 0.35), s * 0.35, _p);
    }
    if (sparkle) _twinkle(canvas, r, h, const Color(0xFFFFF6C8));
  }

  void _drawGems(Canvas canvas, Rect r, int h, {Color color = const Color(0xFF8AF0FF)}) {
    final c = color;
    for (var i = 0; i < 3; i++) {
      final ox = r.left + 7 + ((h >> (i * 4)) % 17);
      final oy = r.top + 7 + ((h >> (i * 4 + 2)) % 17);
      final s = 4.5 + (h >> i) % 2;
      final gem = Path()
        ..moveTo(ox, oy - s)
        ..lineTo(ox + s, oy)
        ..lineTo(ox, oy + s * 1.2)
        ..lineTo(ox - s, oy)
        ..close();
      _p.color = MinePalette.shade(c, -0.3);
      canvas.drawPath(gem, _p);
      _p.color = c;
      canvas.drawPath(Path()..moveTo(ox, oy - s)..lineTo(ox + s, oy)..lineTo(ox, oy)..close(), _p);
    }
    _twinkle(canvas, r, h, const Color(0xFFFFFFFF));
  }

  void _twinkle(Canvas canvas, Rect r, int h, Color c) {
    final phase = (sin(_t * 3 + h % 17) + 1) / 2;
    if (phase < 0.75) return;
    final a = (phase - 0.75) * 4;
    final o = Offset(r.left + 6 + h % 20, r.top + 6 + (h >> 5) % 20);
    final s = 5 * a;
    _p.color = c.withValues(alpha: a);
    canvas.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - s)
        ..lineTo(o.dx + s * 0.25, o.dy - s * 0.25)
        ..lineTo(o.dx + s, o.dy)
        ..lineTo(o.dx + s * 0.25, o.dy + s * 0.25)
        ..lineTo(o.dx, o.dy + s)
        ..lineTo(o.dx - s * 0.25, o.dy + s * 0.25)
        ..lineTo(o.dx - s, o.dy)
        ..lineTo(o.dx - s * 0.25, o.dy - s * 0.25)
        ..close(),
      _p,
    );
  }

  void _drawCoins(Canvas canvas, Rect r) {
    for (final (dx, dy) in const [(10.0, 21.0), (21.0, 22.0), (15.5, 14.0), (9.0, 11.0)]) {
      _p.color = const Color(0xFF8C5E10);
      canvas.drawCircle(Offset(r.left + dx, r.top + dy + 1), 5.5, _p);
      _p.color = const Color(0xFFFFCF3F);
      canvas.drawCircle(Offset(r.left + dx, r.top + dy), 5, _p);
      _p.color = const Color(0xFFFFF1A8);
      canvas.drawCircle(Offset(r.left + dx - 1.5, r.top + dy - 1.5), 1.6, _p);
    }
  }

  void _drawChest(Canvas canvas, Rect r) {
    final pulse = 0.5 + 0.5 * sin(_t * 4);
    _p.color = Color.fromRGBO(255, 211, 77, 0.18 + 0.22 * pulse);
    canvas.drawCircle(r.center, ts * (0.85 + 0.15 * pulse), _p);
    final body = Rect.fromCenter(center: r.center + const Offset(0, 3), width: ts * 0.8, height: ts * 0.5);
    final lid = Rect.fromLTWH(body.left, body.top - ts * 0.2, body.width, ts * 0.24);
    _p.color = const Color(0xFF7A4A1E);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)), _p);
    _p.color = const Color(0xFF9C6230);
    canvas.drawRRect(RRect.fromRectAndCorners(lid, topLeft: const Radius.circular(8), topRight: const Radius.circular(8)), _p);
    _p.color = const Color(0xFFFFCF3F);
    canvas.drawRect(Rect.fromLTWH(body.left, body.top - 1, body.width, 3), _p);
    canvas.drawRect(Rect.fromLTWH(body.center.dx - 2, lid.top, 4, body.bottom - lid.top), _p);
    canvas.drawCircle(body.center + const Offset(0, -2), 3.2, _p);
    _twinkle(canvas, r, 7, const Color(0xFFFFFFFF));
  }

  void _drawCracks(Canvas canvas, Rect r, double dmg, int h) {
    final c = r.center + Offset(((h % 7) - 3).toDouble(), ((h >> 3) % 7 - 3).toDouble());
    canvas.drawLine(c, c + Offset(-11 * dmg - 2, -9 * dmg), _crack);
    canvas.drawLine(c, c + Offset(12 * dmg + 2, -5 * dmg), _crack);
    if (dmg > 0.35) canvas.drawLine(c, c + Offset(5 * dmg, 13 * dmg), _crack);
    if (dmg > 0.65) {
      canvas.drawLine(c, c + Offset(-13 * dmg, 9 * dmg), _crack);
      canvas.drawLine(c + Offset(-6 * dmg, -5 * dmg), c + Offset(-6 * dmg, -14 * dmg), _crack);
    }
  }

  void _drawLava(Canvas canvas, Rect r, int h, bool surfaceRow) {
    final flow = sin(_t * 1.6 + (h % 31) * 0.3);
    _p.color = Color.lerp(const Color(0xFFD9381E), const Color(0xFFFF7A1F), 0.5 + 0.5 * flow)!;
    canvas.drawRect(r, _p);
    _p.color = Color.lerp(const Color(0xFFFFB13B), const Color(0xFFFFE680), 0.5 + 0.5 * sin(_t * 2.3 + h % 13))!.withValues(alpha: 0.75);
    canvas.drawOval(Rect.fromLTWH(r.left + (h % 16) + 2, r.top + (h >> 4) % 18 + 4, 12, 6), _p);
    if (surfaceRow) {
      // Bubbling top edge.
      final bubble = (_t * 0.8 + (h % 100) / 100) % 1;
      _p.color = const Color(0xFFFFE07A).withValues(alpha: 1 - bubble);
      canvas.drawCircle(Offset(r.left + (h % 22) + 5, r.top + 4 - bubble * 8), 2 + bubble * 3, _p);
      _p.color = const Color(0x66FFE07A);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, ts, 3), _p);
    }
  }

  void _drawGas(Canvas canvas, Rect r, int h) {
    for (var i = 0; i < 3; i++) {
      final ph = _t * 0.9 + i * 2.1 + (h % 10);
      _p.color = Color.fromRGBO(140, 220, 90, 0.16 + 0.06 * sin(ph));
      canvas.drawCircle(Offset(r.left + ts * (0.3 + 0.2 * i) + 4 * sin(ph), r.top + ts * 0.5 + 5 * cos(ph * 0.8)), ts * 0.42, _p);
    }
  }

  void _drawDepotFloor(Canvas canvas, Rect r, int h) {
    _p.color = MinePalette.shade(const Color(0xFF8A5A33), ((h % 7) - 3) / 60);
    canvas.drawRect(r, _p);
    _p.color = const Color(0x40000000);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, 1.5, ts), _p);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 3, ts, 3), _p);
  }

  void _drawShopHut(Canvas canvas, GameMap map) {
    final depots = controller.depotXs;
    if (depots.isEmpty) return;
    const y = MapGenerator.surfaceRows - 1;
    final left = depots.first * ts, right = (depots.last + 1) * ts;
    final cx = (left + right) / 2;
    // Posts + awning.
    _p.color = const Color(0xFF5A3A22);
    canvas.drawRect(Rect.fromLTWH(left + 4, (y - 2.2) * ts, 6, ts * 2.2), _p);
    canvas.drawRect(Rect.fromLTWH(right - 10, (y - 2.2) * ts, 6, ts * 2.2), _p);
    final awning = Rect.fromLTWH(left - 6, (y - 2.6) * ts, right - left + 12, ts * 0.6);
    for (var i = 0; i * 18.0 < awning.width; i++) {
      _p.color = i.isEven ? const Color(0xFFE5482E) : const Color(0xFFF7EBD9);
      canvas.drawRect(Rect.fromLTWH(awning.left + i * 18, awning.top, min(18, awning.right - (awning.left + i * 18)), awning.height), _p);
    }
    _p.color = const Color(0x33000000);
    canvas.drawRect(Rect.fromLTWH(awning.left, awning.bottom, awning.width, 4), _p);
    // Sign.
    final sign = Rect.fromCenter(center: Offset(cx, (y - 3.2) * ts), width: 74, height: 22);
    _p.color = const Color(0xFFF2D49B);
    canvas.drawRRect(RRect.fromRectAndRadius(sign, const Radius.circular(5)), _p);
    _signText.render(canvas, 'SHOP', Vector2(sign.center.dx, sign.center.dy), anchor: Anchor.center);
  }
}
