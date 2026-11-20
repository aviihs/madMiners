import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight, HSLColor;
import 'package:mad_miners_core/mad_miners_core.dart';

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
  final _botText = TextPaint(style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Color(0xFF8FC8FF), fontWeight: FontWeight.w800));
  final _youText = TextPaint(style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Color(0xFFFFC233), fontWeight: FontWeight.w900));

  final Map<String, _Anim> _anim = {};
  double _t = 0;

  static Color colorFor(String id, int team) {
    if (team >= 0) return MMColors.teams[team % MMColors.teams.length];
    final h = id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xffffff);
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.62, 0.52).toColor();
  }


  @override
  void update(double dt) {
    _t += dt;
    final map = controller.map;
    for (final m in controller.miners.values) {
      final a = _anim.putIfAbsent(m.snap.id, () => _Anim(m.rx, m.ry));
      final dx = m.rx - a.lastX, dy = m.ry - a.lastY;
      final hs = dx.abs() / max(dt, 1e-4);
      final vs = dy / max(dt, 1e-4);
      // Smoothed vertical speed for the jump/fall pose.
      a.vy += (vs - a.vy) * min(1, dt * 14);
      final grounded = map != null && Physics.onGround(map, m.rx, m.ry, Balance.playerRadius + 0.02);
      final wasAir = a.airborne;
      a.airborne = !grounded && a.vy.abs() > 0.6;
      if (wasAir && grounded && a.peakFall > 7 && m.snap.alive) {
        game.particles.dust(m.rx, m.ry + Balance.playerRadius, (a.peakFall / 3).clamp(3, 12).round());
      }
      a.peakFall = a.airborne ? max(a.peakFall, a.vy) : 0;
      if (m.snap.jetting && m.snap.alive) game.particles.jet(m.rx - (a.left ? -0.3 : 0.3), m.ry + 0.25);
      a.walk += hs * dt * 9;
      a.moving = hs > 0.4;
      if (dx.abs() > 0.004) a.left = dx < 0;
      if (m.snap.fx.abs() > 0.3 && (m.snap.mining || !a.moving)) a.left = m.snap.fx < 0;
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
      final c = Offset(m.rx * ts, m.ry * ts - 2);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      _drawMiner(canvas, m, a, isYou);
      canvas.restore();
      _drawTag(canvas, c, s.name, isYou, s.hp, bot: s.isBot);
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
      airborne: a?.airborne ?? false,
      vy: a?.vy ?? 0,
      time: _t,
      jetpack: true,
      jetting: s.jetting,
    );
  }

  void _drawTag(Canvas canvas, Offset c, String name, bool isYou, double hp, {bool bot = false}) {
    final label = isYou ? 'You' : (bot ? 'BOT $name' : name);
    final w = label.length * 6.2 + 12;
    final tag = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - 34), width: w, height: 16), const Radius.circular(8));
    _p.color = const Color(0x80000000);
    canvas.drawRRect(tag, _p);
    (isYou ? _youText : (bot ? _botText : _nameText)).render(canvas, label, Vector2(c.dx, c.dy - 34), anchor: Anchor.center);
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
  bool airborne = false;
  double vy = 0;
  double peakFall = 0;
}
