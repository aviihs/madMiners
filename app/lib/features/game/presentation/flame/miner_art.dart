import 'dart:math';
import 'dart:ui';

import 'package:mad_miners_core/mad_miners_core.dart';

/// Draws a miner character at the canvas origin (feet at y≈+12, head at
/// y≈-20). Shared by the Flame world and the Flutter store preview so the
/// avatar looks identical everywhere.
abstract final class MinerArt {
  static final _p = Paint();
  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const _skins = [Color(0xFFF1C27D), Color(0xFFE0AC69), Color(0xFFC68642), Color(0xFF8D5524), Color(0xFFFFDBAC)];

  static Color skinFor(String seed) => _skins[seed.codeUnits.fold<int>(0, (a, b) => a + b) % _skins.length];

  static void draw(
    Canvas canvas, {
    required Look look,
    required String seed,
    bool left = false,
    double walk = 0,
    bool moving = false,
    bool mining = false,
    double swing = 0,
    double aim = pi / 2,
    double opacity = 1,
    Color? teamColor,
    bool you = false,
  }) {
    final outfit = look.def(CosmeticSlot.outfit);
    final helmet = look.def(CosmeticSlot.helmet);
    final pick = look.def(CosmeticSlot.pickaxe);
    Color c(int argb) => Color(argb).withValues(alpha: opacity);
    final dir = left ? -1.0 : 1.0;
    final bob = moving ? sin(walk) * 1.6 : 0.0;

    // Ground shadow + ring.
    _p.color = const Color(0x55000000);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 11), width: 20, height: 5), _p);
    if (you || teamColor != null) {
      _stroke
        ..color = (teamColor ?? const Color(0xFFFFB340)).withValues(alpha: 0.75)
        ..strokeWidth = 2;
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 11), width: 26, height: 8), _stroke);
    }

    // Legs + boots.
    final step = moving ? sin(walk) * 3 : 0.0;
    _p.color = c(outfit.secondary);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-6 + step, 2, 5, 9), const Radius.circular(2)), _p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(1 - step, 2, 5, 9), const Radius.circular(2)), _p);
    _p.color = c(0xFF3B2416);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-7 + step, 9, 7, 3), const Radius.circular(1.5)), _p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0 - step, 9, 7, 3), const Radius.circular(1.5)), _p);

    canvas.save();
    canvas.translate(0, -bob.abs());

    final angle = mining ? aim + sin(swing) * 0.9 : (left ? pi + 0.9 : -0.9);
    void pickaxe() {
      final hand = Offset(cos(angle), sin(angle)) * 7 + const Offset(0, -3);
      final tip = hand + Offset(cos(angle), sin(angle)) * 13;
      _stroke
        ..color = c(pick.primary)
        ..strokeWidth = 3;
      canvas.drawLine(hand, tip, _stroke);
      final perp = Offset(-sin(angle), cos(angle));
      _stroke
        ..color = c(pick.secondary)
        ..strokeWidth = 3.5;
      canvas.drawLine(tip - perp * 7, tip + perp * 6, _stroke);
    }

    if (sin(angle) < -0.2) pickaxe();

    // Torso.
    _p.color = c(outfit.primary);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -3), width: 16, height: 14), const Radius.circular(5)), _p);
    _p.color = c(outfit.secondary).withValues(alpha: 0.55 * opacity);
    canvas.drawRect(const Rect.fromLTWH(-8, 0, 16, 2), _p); // belt
    if (outfit.id == 'outfit_plaid') {
      _p.color = const Color(0x40000000);
      for (var i = -6.0; i < 8; i += 4) {
        canvas.drawRect(Rect.fromLTWH(i, -10, 1.4, 14), _p);
      }
    }
    _p.color = const Color(0x40FFFFFF);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -9, 4, 6), const Radius.circular(2)), _p);
    if (outfit.isPremium) {
      // Premium shimmer.
      _p.color = const Color(0x66FFFFFF);
      canvas.drawCircle(const Offset(4, -7), 1.4, _p);
    }

    final character = look.def(CosmeticSlot.character);
    _drawHead(canvas, character, dir, c);
    _drawHelmet(canvas, helmet, dir, c);
    if (sin(angle) >= -0.2) pickaxe();
    canvas.restore();
  }

  static void _drawHead(Canvas canvas, CosmeticDef ch, double dir, Color Function(int) c) {
    const head = Offset(0, -14);
    final skin = c(ch.primary);
    final hair = c(ch.secondary);
    final eye = Offset(2.6 * dir, -14.2);

    switch (ch.style) {
      case Face.ponytail:
        _p.color = hair;
        canvas.drawOval(Rect.fromCenter(center: Offset(-6.5 * dir, -12), width: 5, height: 9), _p);
      case Face.robot:
        _p.color = skin;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: head, width: 14, height: 13), const Radius.circular(3.5)), _p);
        _p.color = hair;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(1.8 * dir, -14), width: 9, height: 4), const Radius.circular(2)), _p);
        _p.color = const Color(0xAAFFFFFF);
        canvas.drawCircle(Offset(3.5 * dir, -14.6), 0.9, _p);
        _p.color = c(0xFF6B7785);
        canvas.drawRect(const Rect.fromLTWH(-1, -24, 2, 4), _p);
        return;
      default:
        break;
    }

    _p.color = skin;
    canvas.drawCircle(head, 6.5, _p);

    switch (ch.style) {
      case Face.beard:
        _p.color = hair;
        canvas.drawPath(
          Path()
            ..moveTo(-6, -13)
            ..quadraticBezierTo(-6, -4, 0, -3.5)
            ..quadraticBezierTo(6, -4, 6, -13)
            ..quadraticBezierTo(0, -10, -6, -13)
            ..close(),
          _p,
        );
        _p.color = c(0xFF1B1B1B);
        canvas.drawCircle(eye, 1.1, _p);
      case Face.goggles:
        _p.color = hair;
        canvas.drawRect(const Rect.fromLTWH(-6.5, -15.6, 13, 2.4), _p);
        _p.color = c(0xFF2B2B2B);
        canvas.drawCircle(Offset(2.6 * dir, -14.4), 2.6, _p);
        _p.color = c(0xFF7FD3FF);
        canvas.drawCircle(Offset(2.6 * dir, -14.4), 1.7, _p);
      case Face.ninja:
        _p.color = hair;
        canvas.drawPath(
          Path()
            ..addArc(Rect.fromCircle(center: head, radius: 6.5), 0.05, pi - 0.1)
            ..close(),
          _p,
        );
        canvas.drawRect(const Rect.fromLTWH(-6.5, -14.5, 13, 1.2), _p);
        _p.color = c(0xFFFFFFFF);
        canvas.drawCircle(eye, 1.2, _p);
        _p.color = c(0xFF1B1B1B);
        canvas.drawCircle(eye + Offset(0.3 * dir, 0), 0.6, _p);
      case Face.mole:
        _p.color = c(0xFF4E3629);
        canvas.drawCircle(head + const Offset(0, -1), 5.4, _p);
        _p.color = hair;
        canvas.drawCircle(Offset(5.6 * dir, -12.6), 2, _p);
        _p.color = c(0xFF111111);
        canvas.drawCircle(Offset(2.4 * dir, -15), 0.8, _p);
      case Face.skeleton:
        _p.color = hair;
        canvas.drawOval(Rect.fromCenter(center: Offset(2.2 * dir, -14.6), width: 3.2, height: 3.6), _p);
        canvas.drawOval(Rect.fromCenter(center: Offset(-1.6 * dir, -14.6), width: 2.6, height: 3.2), _p);
        for (var i = -2; i <= 2; i++) {
          canvas.drawRect(Rect.fromLTWH(i * 1.6 - 0.5, -10.6, 1, 1.8), _p);
        }
      default:
        _p.color = c(0xFF1B1B1B);
        canvas.drawCircle(eye, 1.1, _p);
        _stroke
          ..color = c(0xFF7A3B2A)
          ..strokeWidth = 1;
        canvas.drawArc(Rect.fromCenter(center: Offset(2 * dir, -11.5), width: 3.6, height: 2.4), 0.2, pi - 0.4, false, _stroke);
    }
  }

  static void _drawHelmet(Canvas canvas, CosmeticDef h, double dir, Color Function(int) c) {
    switch (h.style) {
      case 1: // crown
        _p.color = c(h.primary);
        final crown = Path()
          ..moveTo(-7, -17)
          ..lineTo(-7, -23)
          ..lineTo(-3.5, -20)
          ..lineTo(0, -25)
          ..lineTo(3.5, -20)
          ..lineTo(7, -23)
          ..lineTo(7, -17)
          ..close();
        canvas.drawPath(crown, _p);
        _p.color = c(h.secondary);
        canvas.drawCircle(const Offset(0, -19.5), 1.6, _p);
      case 2: // viking
        _p.color = c(h.primary);
        canvas.drawArc(Rect.fromCircle(center: const Offset(0, -15.5), radius: 7.2), pi, pi, true, _p);
        _p.color = c(h.secondary);
        canvas.drawPath(Path()..moveTo(-6, -19)..quadraticBezierTo(-12, -21, -11, -27)..lineTo(-7, -21)..close(), _p);
        canvas.drawPath(Path()..moveTo(6, -19)..quadraticBezierTo(12, -21, 11, -27)..lineTo(7, -21)..close(), _p);
      case 3: // prospector hat
        _p.color = c(h.primary);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -18.5, 22, 3), const Radius.circular(1.5)), _p);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -25, 12, 8), const Radius.circular(3)), _p);
        _p.color = c(h.secondary);
        canvas.drawRect(const Rect.fromLTWH(-6, -19.5, 12, 1.6), _p);
      case 4: // beanie
        _p.color = c(h.primary);
        canvas.drawArc(Rect.fromCircle(center: const Offset(0, -15.2), radius: 7), pi, pi, true, _p);
        _p.color = c(h.secondary);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7.5, -16.5, 15, 3), const Radius.circular(1.5)), _p);
        canvas.drawCircle(const Offset(0, -23), 2.3, _p);
      default: // hard hat with lamp
        _p.color = c(h.primary);
        canvas.drawArc(Rect.fromCircle(center: const Offset(0, -15.5), radius: 7.2), pi, pi, true, _p);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -16.5, 16, 2.5), const Radius.circular(1)), _p);
        _p.color = c(h.secondary);
        canvas.drawCircle(Offset(4.5 * dir, -19), 2.3, _p);
        _p.color = const Color(0x55FFF7D1);
        canvas.drawCircle(Offset(4.5 * dir, -19), 5, _p);
    }
  }
}
