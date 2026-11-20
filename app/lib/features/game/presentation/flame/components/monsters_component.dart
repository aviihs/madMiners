import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../controller/game_controller.dart';
import '../mad_miners_game.dart';

/// Cave spiders and stone golems, smoothed between snapshots.
class MonstersComponent extends Component {
  MonstersComponent(this.controller) : super(priority: 11);
  final GameController controller;
  static const double ts = MadMinersGame.tileSize;

  final _p = Paint()..isAntiAlias = true;
  final _leg = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Map<int, _Smooth> _pos = {};
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    final k = min(1.0, dt * 12);
    final seen = <int>{};
    for (final m in controller.monsters) {
      seen.add(m.id);
      final s = _pos.putIfAbsent(m.id, () => _Smooth(m.x, m.y));
      final dx = m.x - s.x;
      s
        ..x += dx * k
        ..y += (m.y - s.y) * k
        ..walk += dx.abs() * 30;
    }
    _pos.removeWhere((id, _) => !seen.contains(id));
  }

  @override
  void render(Canvas canvas) {
    for (final m in controller.monsters) {
      final s = _pos[m.id];
      if (s == null) continue;
      canvas.save();
      canvas.translate(s.x * ts, s.y * ts);
      if (m.left) canvas.scale(-1, 1);
      if (m.kind == MonsterKind.spider) {
        _spider(canvas, s.walk, m.attacking);
      } else {
        _golem(canvas, s.walk, m.attacking);
      }
      canvas.restore();
      if (m.hp < 1) {
        final w = m.kind == MonsterKind.golem ? 30.0 : 22.0;
        final top = s.y * ts - (m.kind == MonsterKind.golem ? 26 : 16);
        _p.color = const Color(0x99000000);
        canvas.drawRect(Rect.fromLTWH(s.x * ts - w / 2, top, w, 3.5), _p);
        _p.color = const Color(0xFFFF4D6A);
        canvas.drawRect(Rect.fromLTWH(s.x * ts - w / 2, top, w * m.hp, 3.5), _p);
      }
    }
  }

  void _spider(Canvas canvas, double walk, bool biting) {
    _p.color = const Color(0x55000000);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 10), width: 24, height: 4), _p);
    _leg
      ..color = const Color(0xFF2A1F35)
      ..strokeWidth = 1.8;
    for (var i = 0; i < 4; i++) {
      final ph = walk * 0.4 + i * 1.3;
      for (final side in const [-1.0, 1.0]) {
        final knee = Offset(side * (7 + i * 2.2), -4 + sin(ph * side) * 2);
        final foot = Offset(side * (10 + i * 2.6), 10 + cos(ph) * 1.2);
        canvas.drawPath(Path()..moveTo(side * 3, 1)..lineTo(knee.dx, knee.dy)..lineTo(foot.dx, foot.dy), _leg);
      }
    }
    _p.shader = Gradient.radial(const Offset(-2, -1), 11, [const Color(0xFF5A4470), const Color(0xFF1E1528)]);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-3, 1), width: 15, height: 12), _p);
    _p.shader = null;
    _p.color = const Color(0xFF2A1F35);
    canvas.drawCircle(const Offset(6, 2), 4.6, _p);
    // Markings + eyes.
    _p.color = const Color(0xFFB0303A);
    canvas.drawPath(Path()..moveTo(-5, -2)..lineTo(-2, 1)..lineTo(-5, 4)..lineTo(-8, 1)..close(), _p);
    final glow = biting ? 1.0 : 0.6 + 0.4 * sin(_t * 5);
    _p.color = Color.fromRGBO(255, 60, 60, glow);
    canvas.drawCircle(const Offset(8, 0.5), 1.1, _p);
    canvas.drawCircle(const Offset(6.4, -0.5), 0.9, _p);
    if (biting) {
      _leg
        ..color = const Color(0xFFEDE6D6)
        ..strokeWidth = 1.2;
      canvas.drawLine(const Offset(9.5, 4), const Offset(12, 7), _leg);
      canvas.drawLine(const Offset(8.5, 5), const Offset(10.5, 8.5), _leg);
    }
  }

  void _golem(Canvas canvas, double walk, bool smashing) {
    final step = sin(walk * 0.25) * 2;
    _p.color = const Color(0x66000000);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 11), width: 30, height: 6), _p);
    _p.color = const Color(0xFF5E5650);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-9 + step, 2, 7, 10), const Radius.circular(2)), _p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(2 - step, 2, 7, 10), const Radius.circular(2)), _p);
    _p.shader = Gradient.linear(const Offset(-12, -20), const Offset(12, 6), [const Color(0xFF9A918A), const Color(0xFF4E4741)]);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -18, 24, 22), const Radius.circular(6)), _p);
    _p.shader = null;
    // Moss and cracks.
    _p.color = const Color(0xFF4F7A3A);
    canvas.drawOval(const Rect.fromLTWH(-11, -19, 10, 5), _p);
    _leg
      ..color = const Color(0xFF2E2925)
      ..strokeWidth = 1.2;
    canvas.drawPath(Path()..moveTo(-4, -12)..lineTo(-1, -7)..lineTo(-4, -2), _leg);
    // Arms: one raised to smash when attacking.
    _p.color = const Color(0xFF7A716A);
    final armAngle = smashing ? -2.2 : 0.4 + sin(walk * 0.25) * 0.2;
    canvas.save();
    canvas.translate(10, -12);
    canvas.rotate(armAngle);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3, 0, 7, 15), const Radius.circular(3)), _p);
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-15, -12, 6, 14), const Radius.circular(3)), _p);
    // Glowing eyes.
    final glow = 0.6 + 0.4 * sin(_t * 2.4);
    _p.color = Color.fromRGBO(255, 160, 40, glow);
    canvas.drawRect(const Rect.fromLTWH(1, -12, 4, 2.2), _p);
    canvas.drawRect(const Rect.fromLTWH(7, -12, 3, 2.2), _p);
  }
}

class _Smooth {
  _Smooth(this.x, this.y);
  double x;
  double y;
  double walk = 0;
}

/// Cracked Mystery Bombs shaking harder and glowing brighter until they burst.
class MysteryOpeningsComponent extends Component {
  MysteryOpeningsComponent(this.controller) : super(priority: 25);
  final GameController controller;
  final _p = Paint()..isAntiAlias = true;
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    const ts = MadMinersGame.tileSize;
    for (final o in controller.mysteries) {
      final k = (1 - o.t / Balance.mysteryOpenSeconds).clamp(0.0, 1.0); // 0 → 1 as it nears the reveal
      final shake = sin(_t * (30 + 40 * k)) * (1 + 4 * k);
      final c = Offset(o.x * ts + shake, o.y * ts);
      _p.shader = Gradient.radial(c, ts * (1 + 1.6 * k), [Color.fromRGBO(224, 179, 255, 0.4 + 0.5 * k), const Color(0x00B06BFF)]);
      canvas.drawCircle(c, ts * (1 + 1.6 * k), _p);
      _p.shader = null;
      _p.color = const Color(0xFF3A3F4A);
      canvas.drawCircle(c, ts * 0.38, _p);
      _p.color = Color.lerp(const Color(0xFF7B4FD6), const Color(0xFFFFFFFF), k)!;
      canvas.drawCircle(c, ts * (0.18 + 0.12 * k), _p);
      // Spinning glyphs.
      _p.color = Color.fromRGBO(255, 255, 255, 0.5 + 0.5 * k);
      for (var i = 0; i < 6; i++) {
        final a = _t * (2 + 6 * k) + i * pi / 3;
        canvas.drawCircle(c + Offset(cos(a), sin(a)) * ts * (0.7 + 0.3 * k), 2 + 2 * k, _p);
      }
    }
  }
}
