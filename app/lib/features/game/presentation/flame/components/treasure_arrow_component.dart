import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle, Shadow;

import '../../controller/game_controller.dart';
import '../mad_miners_game.dart';

/// Once you're close to the treasure (warm or hot), a gold arrow circles
/// your miner and points at it, with the distance under it. It eases to new
/// directions instead of snapping, and pulses faster when you're hot.
///
/// Drawn in the world, above the darkness, so it sits right on the miner.
/// One path, a few paints, no allocations per frame.
class TreasureArrowComponent extends Component with HasGameReference<MadMinersGame> {
  TreasureArrowComponent(this.controller) : super(priority: 30);

  final GameController controller;

  double _angle = 0;
  double _shown = 0; // 0..1 fade
  double _t = 0;
  bool _hasAngle = false;

  static const _radius = 44.0; // px from the miner's centre (tile = 32)
  final _path = Path()
    ..moveTo(14, 0)
    ..lineTo(-6, -11)
    ..lineTo(-2, 0)
    ..lineTo(-6, 11)
    ..close();
  final _fill = Paint()..color = const Color(0xFFFFC233);
  final _edge = Paint()
    ..color = const Color(0xFF5A3500)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round;
  final _glow = Paint();
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  int _lastDistance = -1;
  int _lastLevel = -1;
  TextPaint? _label;
  String _labelText = '';

  @override
  void update(double dt) {
    _t += dt;
    final hint = controller.hud.value.hint;
    final me = controller.me;
    final visible = hint.level >= 2 && me != null && me.snap.alive && controller.hud.value.warmup <= 0;
    _shown = (_shown + (visible ? dt * 4 : -dt * 4)).clamp(0.0, 1.0);
    if (!visible) {
      if (_shown == 0) _hasAngle = false;
      return;
    }
    final target = hint.angle * pi / 180;
    if (!_hasAngle) {
      _angle = target;
      _hasAngle = true;
    } else {
      // Shortest way round, eased.
      var d = (target - _angle) % (2 * pi);
      if (d > pi) d -= 2 * pi;
      _angle += d * min(1.0, dt * 8);
    }
    if (hint.distance != _lastDistance || hint.level != _lastLevel) {
      _lastDistance = hint.distance;
      _lastLevel = hint.level;
      _labelText = hint.level >= 3 ? 'HERE!' : '${hint.distance} m';
      _label = TextPaint(
        style: TextStyle(
          fontFamily: 'Lilita',
          fontSize: 13,
          color: hint.level >= 3 ? const Color(0xFFFFE08A) : const Color(0xFFFFC233),
          shadows: const [Shadow(blurRadius: 3, color: Color(0xE6000000))],
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    if (_shown <= 0) return;
    final me = controller.me;
    if (me == null) return;
    final ts = MadMinersGame.tileSize;
    final hot = _lastLevel >= 3;
    final pulse = 0.5 + 0.5 * sin(_t * (hot ? 9 : 5));
    final cx = me.rx * ts, cy = me.ry * ts - 2;
    final r = _radius + pulse * 4;
    final ax = cx + cos(_angle) * r, ay = cy + sin(_angle) * r;
    final a = _shown;

    // Faint ring so the arrow reads as "pointing from you".
    _ring.color = Color.fromRGBO(255, 194, 51, 0.18 * a);
    canvas.drawCircle(Offset(cx, cy), _radius, _ring);

    canvas.save();
    canvas.translate(ax, ay);
    canvas.rotate(_angle);
    final s = hot ? 1.15 + pulse * 0.1 : 1.0;
    canvas.scale(s, s);
    _glow.color = Color.fromRGBO(255, 160, 40, (0.25 + 0.25 * pulse) * a);
    canvas.drawCircle(const Offset(2, 0), 15, _glow);
    _fill.color = Color.fromRGBO(255, 194, 51, a);
    _edge.color = Color.fromRGBO(90, 53, 0, a);
    canvas.drawPath(_path, _edge);
    canvas.drawPath(_path, _fill);
    canvas.restore();

    final label = _label;
    if (label != null && a > 0.6) {
      label.render(canvas, _labelText, Vector2(ax + cos(_angle) * 16, ay + sin(_angle) * 16 + 12), anchor: Anchor.center);
    }
  }
}
