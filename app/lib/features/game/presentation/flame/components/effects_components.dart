import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show TextStyle, Shadow;
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../controller/game_controller.dart';
import '../mad_miners_game.dart';

/// Rising "+30 Gold" labels.
class FloatingText extends Component {
  FloatingText(FxRequest r)
    : _pos = Vector2(r.x * MadMinersGame.tileSize, r.y * MadMinersGame.tileSize),
      _text = r.text,
      _paint = TextPaint(
        style: TextStyle(
          fontFamily: 'Lilita',
          fontSize: 16,
          letterSpacing: 0.5,
          color: Color(r.color),
          shadows: const [Shadow(blurRadius: 4, color: Color(0xCC000000))],
        ),
      ),
      super(priority: 40);

  final Vector2 _pos;
  final String _text;
  final TextPaint _paint;
  double _age = 0;
  static const _life = 1.3;

  @override
  void update(double dt) {
    _age += dt;
    _pos.y -= dt * (40 - _age * 20);
    if (_age > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final scale = _age < 0.15 ? 0.6 + _age / 0.15 * 0.4 : 1.0;
    canvas.save();
    canvas.translate(_pos.x, _pos.y);
    canvas.scale(scale);
    _paint.render(canvas, _text, Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }
}

/// Lightweight particle system for rock chips and loot sparkles.
class ParticlesComponent extends Component {
  ParticlesComponent({this.highQuality = true}) : super(priority: 15);

  /// Phones get fewer particles (and a lower cap) to keep frames smooth.
  final bool highQuality;
  int get _cap => highQuality ? 700 : 260;
  int _n(int n) => highQuality ? n : (n / 2).ceil();

  final _rng = Random();
  final List<_Particle> _ps = [];
  final _paint = Paint();
  static const double ts = MadMinersGame.tileSize;

  void _trim() {
    if (_ps.length > _cap) _ps.removeRange(0, _ps.length - _cap);
  }

  void chips(double x, double y, Color c, int n) {
    n = _n(n);
    _trim();
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = 40 + _rng.nextDouble() * 110;
      _ps.add(_Particle(x * ts, y * ts, cos(a) * sp, sin(a) * sp - 60, 0.45 + _rng.nextDouble() * 0.4, 2 + _rng.nextDouble() * 3, c, gravity: 420));
    }
  }

  void burst(double x, double y, Color c) {
    _trim();
    for (var i = 0; i < _n(18); i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = 30 + _rng.nextDouble() * 90;
      _ps.add(_Particle(x * ts, y * ts, cos(a) * sp, sin(a) * sp, 0.6 + _rng.nextDouble() * 0.5, 1.5 + _rng.nextDouble() * 2, c, gravity: -20, glow: true));
    }
  }

  /// Jetpack exhaust: a couple of hot sparks and smoke each frame.
  void jet(double x, double y) {
    for (var i = 0; i < 2; i++) {
      _ps.add(_Particle(x * ts + (_rng.nextDouble() - 0.5) * 4, y * ts, (_rng.nextDouble() - 0.5) * 30, 90 + _rng.nextDouble() * 60,
          0.25 + _rng.nextDouble() * 0.2, 2 + _rng.nextDouble() * 2, i == 0 ? const Color(0xFFFFB13B) : const Color(0xFF9A8F88),
          gravity: -40, glow: i == 0, soft: i == 1));
    }
    _trim();
  }

  /// Puff of dust kicked up by a hard landing.
  void dust(double x, double y, int n) {
    n = _n(n);
    for (var i = 0; i < n; i++) {
      final side = _rng.nextBool() ? 1 : -1;
      _ps.add(_Particle(
        x * ts + side * _rng.nextDouble() * 6,
        y * ts,
        side * (30 + _rng.nextDouble() * 60),
        -10 - _rng.nextDouble() * 30,
        0.4 + _rng.nextDouble() * 0.35,
        3 + _rng.nextDouble() * 3,
        const Color(0xFFB8A48C),
        gravity: 60,
        soft: true,
      ));
    }
  }

  @override
  void update(double dt) {
    for (final p in _ps) {
      p
        ..vy += p.gravity * dt
        ..x += p.vx * dt
        ..y += p.vy * dt
        ..age += dt;
    }
    _ps.removeWhere((p) => p.age >= p.life);
  }

  @override
  void render(Canvas canvas) {
    for (final p in _ps) {
      final a = (1 - p.age / p.life).clamp(0.0, 1.0);
      if (p.glow) {
        _paint.color = p.color.withValues(alpha: a * 0.35);
        canvas.drawCircle(Offset(p.x, p.y), p.size * 2.5, _paint);
      }
      if (p.soft) {
        _paint.color = p.color.withValues(alpha: a * 0.55);
        canvas.drawCircle(Offset(p.x, p.y), p.size * (1.6 - a * 0.6), _paint);
        continue;
      }
      _paint.color = p.color.withValues(alpha: a);
      canvas.drawRect(Rect.fromCenter(center: Offset(p.x, p.y), width: p.size, height: p.size), _paint);
    }
  }
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, {required this.gravity, this.glow = false, this.soft = false});
  double x, y, vx, vy;
  final double life, size, gravity;
  final Color color;
  final bool glow;
  final bool soft;
  double age = 0;
}

/// Darkness hazard: the mine gets darker as you go down. Every miner's
/// helmet lamp and the lava cut light into it.
class DarknessComponent extends Component with HasGameReference<MadMinersGame> {
  DarknessComponent(this.controller, {this.highQuality = true}) : super(priority: 20);
  final GameController controller;
  final bool highQuality;
  final _dark = Paint();
  final _cut = Paint()..blendMode = BlendMode.dstOut;
  final _glow = Paint()..blendMode = BlendMode.plus;
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final me = controller.me;
    final map = controller.map;
    if (me == null || map == null) return;
    const ts = MadMinersGame.tileSize;
    final view = game.camera.visibleWorldRect.inflate(64);
    final depth = ((me.ry - MapGenerator.surfaceRows) / 5).clamp(0.0, 1.0);

    // Warm glow rising from lava (drawn even near the surface).
    final lavaTop = map.height - 1 - controller.settings.mapId.def.lavaRows;
    if (view.bottom > (lavaTop - 6) * ts) {
      final g = Rect.fromLTWH(view.left, (lavaTop - 6) * ts, view.width, 6 * ts);
      _glow.shader = Gradient.linear(g.topCenter, g.bottomCenter, const [Color(0x00FF5A1F), Color(0x55FF5A1F)]);
      canvas.drawRect(g, _glow);
      _glow.shader = null;
    }
    if (depth <= 0) return;

    canvas.saveLayer(view, Paint());
    _dark.color = Color.fromARGB((238 * depth).round(), 5, 3, 2);
    canvas.drawRect(view, _dark);

    void light(Offset c, double radius, double strength) {
      _cut.shader = Gradient.radial(c, max(radius, 1), [
        Color.fromRGBO(0, 0, 0, strength),
        Color.fromRGBO(0, 0, 0, strength * 0.85),
        const Color(0x00000000),
      ], const [0, 0.55, 1]);
      canvas.drawCircle(c, radius, _cut);
    }

    final flicker = 1 + sin(_t * 9) * 0.015;
    for (final m in controller.miners.values) {
      if (!m.snap.alive) continue;
      if (!view.inflate(m.snap.vision * ts).contains(Offset(m.rx * ts, m.ry * ts))) continue; // light can't reach the screen
      final isMe = m.snap.id == controller.youId;
      final r = m.snap.vision * ts * (isMe ? flicker : 0.75);
      light(Offset(m.rx * ts, m.ry * ts - 6), r, isMe ? 1 : 0.8);
    }

    // Lava lights its surroundings. Each light is a gradient draw, so only
    // the lava surface gets one, spaced out and capped.
    final x0 = max(0, (view.left / ts).floor()), x1 = min(map.width - 1, (view.right / ts).ceil());
    final y0 = max(0, (view.top / ts).floor()), y1 = min(map.height - 1, (view.bottom / ts).ceil());
    var budget = highQuality ? 24 : 10;
    for (var y = y0; y <= y1 && budget > 0; y++) {
      for (var x = x0; x <= x1 && budget > 0; x++) {
        if (map.tileAt(x, y) != TileType.lava || map.tileAt(x, y - 1) == TileType.lava) continue;
        if (x % 2 == 1) continue;
        light(Offset((x + 0.5) * ts, (y + 0.5) * ts), ts * 2.6, 0.9);
        budget--;
      }
    }
    _cut.shader = null;
    canvas.restore();
  }
}

/// Lit bombs and dynamite with blinking fuses; lit TNT with a 3-2-1.
class BombsComponent extends Component {
  BombsComponent(this.controller) : super(priority: 12);
  final GameController controller;
  final _p = Paint();
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  final _count = TextPaint(
    style: const TextStyle(fontFamily: 'Lilita', fontSize: 30, color: Color(0xFFFFFFFF), shadows: [Shadow(blurRadius: 6, color: Color(0xFFFF1F1F))]),
  );

  void _litTnt(Canvas canvas, BombSnapshot b) {
    const ts = MadMinersGame.tileSize;
    final c = Offset(b.x * ts, b.y * ts);
    final n = b.fuse.ceil().clamp(1, 3);
    final beat = (b.fuse % 1); // 1 → 0 within each second
    // Blast radius warning, pulsing harder as it gets closer.
    _p.color = Color.fromRGBO(255, 69, 58, 0.10 + 0.18 * (1 - b.fuse / 3));
    canvas.drawCircle(c, b.tnt!.blast.radius * ts, _p);
    final box = Rect.fromCenter(center: c, width: ts * 0.86, height: ts * 0.86);
    _p.color = sin(_t * (12 + 20 * (1 - b.fuse / 3))) > 0 ? const Color(0xFFFF2D2D) : const Color(0xFF9C2A1E);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), _p);
    _p.color = const Color(0xFFFFC233);
    canvas.drawRect(Rect.fromLTWH(box.left, c.dy - 3, box.width, 6), _p);
    canvas.save();
    canvas.translate(c.dx, c.dy - ts * 0.95);
    canvas.scale(1 + 0.35 * beat);
    _count.render(canvas, '$n', Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    const ts = MadMinersGame.tileSize;
    for (final b in controller.bombs) {
      if (b.tnt != null) {
        _litTnt(canvas, b);
        continue;
      }
      final c = Offset(b.x * ts, b.y * ts - 1);
      final urgent = b.fuse < 0.8;
      final blink = urgent ? (sin(_t * 30) > 0) : (sin(_t * 10) > 0.6);
      _p.color = const Color(0x55000000);
      canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 8), width: 18, height: 5), _p);
      if (b.kind == ItemKind.bomb) {
        _p.color = const Color(0xFF1E1E22);
        canvas.drawCircle(c, 8, _p);
        _p.color = const Color(0x55FFFFFF);
        canvas.drawCircle(c + const Offset(-3, -3), 2.2, _p);
        _p.color = const Color(0xFF8B5A2B);
        canvas.drawRect(Rect.fromLTWH(c.dx - 1, c.dy - 13, 2, 6), _p);
      } else {
        for (var i = -1; i <= 1; i++) {
          _p.color = const Color(0xFFC62828);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(i * 5.0, 0), width: 5, height: 15), const Radius.circular(2)), _p);
        }
        _p.color = const Color(0xFF3B2416);
        canvas.drawRect(Rect.fromLTWH(c.dx - 8, c.dy - 1, 16, 3), _p);
      }
      // Fuse spark.
      _p.color = blink ? const Color(0xFFFFE07A) : const Color(0xFFFF7A1F);
      canvas.drawCircle(c + const Offset(0, -14), blink ? 3 : 2, _p);
      if (urgent) {
        _p.color = const Color(0x33FF453A);
        canvas.drawCircle(c, itemDefs[b.kind]!.radius * ts, _p);
      }
    }
  }
}
