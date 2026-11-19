import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight, Shadow;
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../controller/game_controller.dart';
import '../mad_miners_game.dart';

/// Rising "+Gold Ore" / "+120 coins" labels.
class FloatingText extends Component {
  FloatingText(FxRequest r)
    : _pos = Vector2(r.x * MadMinersGame.tileSize, r.y * MadMinersGame.tileSize),
      _text = r.text,
      _paint = TextPaint(
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(r.color),
          shadows: const [Shadow(blurRadius: 3, color: Color(0xFF000000))],
        ),
      ),
      super(priority: 30);

  final Vector2 _pos;
  final String _text;
  final TextPaint _paint;
  double _age = 0;
  static const _life = 1.2;

  @override
  void update(double dt) {
    _age += dt;
    _pos.y -= dt * 28;
    if (_age > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) => _paint.render(canvas, _text, _pos, anchor: Anchor.center);
}

/// Darkness hazard: everything outside your helmet light fades to black.
/// The surface camp is lit.
class DarknessComponent extends Component with HasGameReference<MadMinersGame> {
  DarknessComponent(this.controller) : super(priority: 20);
  final GameController controller;
  final _paint = Paint();

  @override
  void render(Canvas canvas) {
    final me = controller.me;
    if (me == null) return;
    final view = game.camera.visibleWorldRect.inflate(64);
    final ts = MadMinersGame.tileSize;
    final center = Offset(me.rx * ts, me.ry * ts);

    // Fade darkness in as you descend.
    final depth = ((me.ry - MapGenerator.surfaceRows) / 6).clamp(0.0, 1.0);
    if (depth <= 0) return;
    final radius = me.snap.vision * ts;
    final edge = Color.fromARGB((235 * depth).round(), 6, 4, 3);
    _paint.shader = Gradient.radial(
      center,
      max(radius, 1),
      [const Color(0x00000000), const Color(0x00000000), edge],
      const [0, 0.55, 1],
    );
    canvas.drawRect(view, _paint);
  }
}
