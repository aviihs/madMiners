import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight, HSLColor;

import '../../../../../app/theme.dart';
import '../../controller/game_controller.dart';
import '../mad_miners_game.dart';

/// Draws every miner: body, helmet lamp, pickaxe swing, name tag, HP bar.
class MinersComponent extends Component with HasGameReference<MadMinersGame> {
  MinersComponent(this.controller) : super(priority: 10);

  final GameController controller;
  static const double ts = MadMinersGame.tileSize;

  final _body = Paint();
  final _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFF14110F);
  final _helmet = Paint()..color = const Color(0xFFF2C14E);
  final _lamp = Paint()..color = const Color(0xFFFFF4C2);
  final _handle = Paint()
    ..color = const Color(0xFF8B5A2B)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final _head = Paint()
    ..color = const Color(0xFFB8C2CC)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  final _barBg = Paint()..color = const Color(0xAA000000);
  final _barFg = Paint()..color = MMColors.health;
  final _youRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = MMColors.amber;

  final _nameText = TextPaint(
    style: const TextStyle(fontSize: 11, color: Color(0xFFF3E9DC), fontWeight: FontWeight.w600),
  );
  final _botText = TextPaint(style: const TextStyle(fontSize: 11, color: Color(0xFFA89A8A)));

  static Color colorFor(String id, int team) {
    if (team >= 0) return MMColors.teams[team % MMColors.teams.length];
    final h = id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xffffff);
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.55, 0.55).toColor();
  }

  @override
  void render(Canvas canvas) {
    final you = controller.youId;
    final miners = controller.miners.values.toList()..sort((a, b) => a.ry.compareTo(b.ry));
    for (final m in miners) {
      final s = m.snap;
      if (!s.alive) continue;
      final c = Offset(m.rx * ts, m.ry * ts);
      final r = ts * 0.34;
      final isYou = s.id == you;

      if (isYou) canvas.drawCircle(c, r + 4, _youRing);

      // Pickaxe (behind the body when facing up).
      final facing = atan2(s.fy, s.fx);
      final swing = s.mining ? sin(m.swing) * 0.9 : 0.35;
      final a = facing + swing;
      final hand = c + Offset(cos(a), sin(a)) * (r * 0.9);
      final tip = c + Offset(cos(a), sin(a)) * (r * 1.9);
      canvas.drawLine(hand, tip, _handle);
      final perp = Offset(-sin(a), cos(a)) * 6;
      canvas.drawLine(tip - perp, tip + perp, _head);

      // Body.
      _body.color = colorFor(s.id, s.team).withValues(alpha: s.connected ? 1 : 0.4);
      canvas.drawCircle(c, r, _body);
      canvas.drawCircle(c, r, _outline);

      // Helmet + lamp facing direction.
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.8), facing - pi * 0.75, pi * 1.5, true, _helmet);
      canvas.drawCircle(c + Offset(cos(facing), sin(facing)) * r * 0.55, 3.5, _lamp);

      // Name + HP.
      final label = s.isBot ? '${s.name} [BOT]' : s.name;
      (s.isBot ? _botText : _nameText).render(canvas, label, Vector2(c.dx, c.dy - r - 16), anchor: Anchor.center);
      if (s.hp < 100) {
        final w = ts * 0.9;
        final bar = Rect.fromLTWH(c.dx - w / 2, c.dy - r - 8, w, 4);
        canvas.drawRect(bar, _barBg);
        canvas.drawRect(Rect.fromLTWH(bar.left, bar.top, w * s.hp / 100, 4), _barFg);
      }
    }
  }
}
