import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight, HSLColor;

import '../../../../../app/theme.dart';
import '../../controller/game_controller.dart';
import '../mad_miners_game.dart';
import '../miner_art.dart';

/// Draws every miner as a little side-view character: boots, overalls,
/// face, helmet with lamp, swinging pickaxe, plus a name tag.
class MinersComponent extends Component with HasGameReference<MadMinersGame> {
  MinersComponent(this.controller) : super(priority: 10);

  final GameController controller;
  static const double ts = MadMinersGame.tileSize;

  final _p = Paint();
  final _nameText = TextPaint(style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Color(0xFFFFFFFF), fontWeight: FontWeight.w800));
  final _youText = TextPaint(style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Color(0xFFFFC233), fontWeight: FontWeight.w900));

  final Map<String, _Anim> _anim = {};

  static Color colorFor(String id, int team) {
    if (team >= 0) return MMColors.teams[team % MMColors.teams.length];
    final h = id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xffffff);
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.62, 0.52).toColor();
  }


  @override
  void update(double dt) {
    for (final m in controller.miners.values) {
      final a = _anim.putIfAbsent(m.snap.id, () => _Anim(m.rx, m.ry));
      final dx = m.rx - a.lastX, dy = m.ry - a.lastY;
      final speed = sqrt(dx * dx + dy * dy) / max(dt, 1e-4);
      a.walk += speed * dt * 9;
      a.moving = speed > 0.4;
      if (m.snap.fx.abs() > 0.3) a.left = m.snap.fx < 0;
      a
        ..lastX = m.rx
        ..lastY = m.ry;
    }
    _anim.removeWhere((id, _) => !controller.miners.containsKey(id));
  }

  @override
  void render(Canvas canvas) {
    final you = controller.youId;
    final miners = controller.miners.values.toList()..sort((a, b) => a.ry.compareTo(b.ry));
    for (final m in miners) {
      final s = m.snap;
      if (!s.alive) continue;
      final a = _anim[s.id];
      final isYou = s.id == you;
      final c = Offset(m.rx * ts, m.ry * ts);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      _drawMiner(canvas, m, a, isYou);
      canvas.restore();
      _drawTag(canvas, c, s.name, isYou, s.hp);
    }
  }

  void _drawMiner(Canvas canvas, RenderMiner m, _Anim? a, bool isYou) {
    final s = m.snap;
    MinerArt.draw(
      canvas,
      look: s.look,
      seed: s.id,
      left: a?.left ?? false,
      walk: a?.walk ?? 0,
      moving: a?.moving ?? false,
      mining: s.mining,
      swing: m.swing,
      aim: atan2(s.fy, s.fx),
      opacity: s.connected ? 1 : 0.45,
      teamColor: s.team >= 0 ? MMColors.teams[s.team % MMColors.teams.length] : null,
      you: isYou,
    );
  }

  void _drawTag(Canvas canvas, Offset c, String name, bool isYou, double hp) {
    final label = isYou ? 'You' : name;
    final w = label.length * 6.2 + 12;
    final tag = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - 34), width: w, height: 16), const Radius.circular(8));
    _p.color = const Color(0x80000000);
    canvas.drawRRect(tag, _p);
    (isYou ? _youText : _nameText).render(canvas, label, Vector2(c.dx, c.dy - 34), anchor: Anchor.center);
    if (hp < 100) {
      const bw = 26.0;
      final bar = Rect.fromLTWH(c.dx - bw / 2, c.dy - 25, bw, 3);
      _p.color = const Color(0x99000000);
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(2)), _p);
      _p.color = MMColors.health;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bar.left, bar.top, bw * hp / 100, 3), const Radius.circular(2)), _p);
    }
  }
}

class _Anim {
  _Anim(this.lastX, this.lastY);
  double lastX;
  double lastY;
  double walk = 0;
  bool moving = false;
  bool left = false;
}
