import 'dart:math';
import 'dart:ui';

import 'package:mad_miners_core/mad_miners_core.dart';

/// Draws a miner character at the canvas origin (feet at y≈+12, head at
/// y≈-20). Shared by the Flame world and the Flutter store preview so the
/// avatar looks identical everywhere.
///
/// Every Locker slot changes the silhouette, not just a colour: characters
/// have their own heads, skin and hands; outfits have their own patterns;
/// helmets their own shapes; pickaxes their own heads (pick, axe, mattock,
/// drill).
abstract final class MinerArt {
  static final _p = Paint()..isAntiAlias = true;
  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..color = const Color(0xCC1A120D)
    ..strokeJoin = StrokeJoin.round;

  static const _skins = [Color(0xFFF1C27D), Color(0xFFE0AC69), Color(0xFFC68642), Color(0xFF8D5524), Color(0xFFFFDBAC)];

  static Color skinFor(String seed) => _skins[seed.codeUnits.fold<int>(0, (a, b) => a + b) % _skins.length];

  /// Gradients only depend on the look (not position: the canvas is already
  /// translated), so build each one once instead of every frame.
  static final Map<Object, Shader> _shaders = {};
  static Shader _cached(Object key, Shader Function() make) {
    if (_shaders.length > 400) _shaders.clear();
    return _shaders.putIfAbsent(key, make);
  }

  static Color _shade(Color c, double amount) =>
      amount >= 0 ? Color.lerp(c, const Color(0xFFFFFFFF), amount)! : Color.lerp(c, const Color(0xFF000000), -amount)!;

  /// [airborne] switches to a jump/fall pose; [vy] (tiles/s, + is down)
  /// picks rising vs falling. [time] drives idle effects (glows, sparkles).
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
    bool airborne = false,
    double vy = 0,
    double time = 0,
    bool jetpack = false,
    bool jetting = false,
  }) {
    final outfit = look.def(CosmeticSlot.outfit);
    final helmet = look.def(CosmeticSlot.helmet);
    final pick = look.def(CosmeticSlot.pickaxe);
    final character = look.def(CosmeticSlot.character);
    Color c(int argb) => Color(argb).withValues(alpha: opacity);
    Color cc(Color col) => col.withValues(alpha: col.a * opacity);
    _line.color = Color.fromRGBO(26, 18, 13, 0.8 * opacity);
    final dir = left ? -1.0 : 1.0;
    final bob = moving && !airborne ? sin(walk) * 1.4 : 0.0;

    // Ground shadow + ring (only when standing on something).
    if (!airborne) {
      _p.color = Color.fromRGBO(0, 0, 0, 0.35 * opacity);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 12), width: 22, height: 5), _p);
    }
    if (you || teamColor != null) {
      _stroke
        ..color = (teamColor ?? const Color(0xFFFFB340)).withValues(alpha: 0.75 * opacity)
        ..strokeWidth = 2;
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 12), width: 28, height: 8), _stroke);
    }

    final skin = c(character.primary);
    final isBot = character.style == Face.robot;
    final isBones = character.style == Face.skeleton;
    final isMole = character.style == Face.mole;
    final handColor = isBot ? c(0xFF8C98A6) : (isBones ? c(0xFFEDE6D6) : (isMole ? c(0xFF4E3629) : skin));

    // ---- legs + boots ----
    final pants = c(outfit.secondary);
    final boot = isBot ? c(0xFF4A5462) : c(0xFF3B2416);
    void leg(double hipX, double kneeDx, double footDx, double footDy) {
      final hip = Offset(hipX, 2);
      final foot = Offset(hipX + footDx, 9 + footDy);
      final knee = Offset((hip.dx + foot.dx) / 2 + kneeDx, (hip.dy + foot.dy) / 2);
      _stroke
        ..color = pants
        ..strokeWidth = 5;
      canvas.drawPath(
        Path()
          ..moveTo(hip.dx, hip.dy)
          ..quadraticBezierTo(knee.dx, knee.dy, foot.dx, foot.dy),
        _stroke,
      );
      _p.color = boot;
      final b = RRect.fromRectAndRadius(Rect.fromLTWH(foot.dx - 3 + dir * 0.5, foot.dy - 1, 7, 4), const Radius.circular(1.8));
      canvas.drawRRect(b, _p);
      _p.color = cc(const Color(0x33FFFFFF));
      canvas.drawRect(Rect.fromLTWH(b.left + 1, b.top + 0.5, 4, 1), _p);
    }

    if (airborne) {
      // Tucked legs when rising, dangling when falling.
      final rising = vy < 0;
      leg(-3, -2 * dir, rising ? -1 * dir : -2, rising ? -3 : 1);
      leg(3, 2 * dir, rising ? 3 * dir : 2, rising ? -1 : 2);
    } else {
      final step = moving ? sin(walk) * 3.2 : 0.0;
      final lift = moving ? max(0.0, cos(walk)) * 1.5 : 0.0;
      final lift2 = moving ? max(0.0, -cos(walk)) * 1.5 : 0.0;
      leg(-3, 1.5 * dir, step - 0.5, -lift);
      leg(3, 1.5 * dir, -step + 0.5, -lift2);
    }

    canvas.save();
    canvas.translate(0, -bob.abs());

    if (jetpack) _drawJetpack(canvas, dir, jetting, time, opacity);

    // Pickaxe pose: swinging toward the aim while digging, carried on the
    // shoulder otherwise, raised overhead mid-air.
    final angle = mining
        ? aim + sin(swing) * 0.9
        : airborne
        ? (left ? pi + 0.3 : -0.3) + (vy < 0 ? -0.6 * dir : 0.4 * dir)
        : (left ? pi + 0.9 : -0.9);
    final hand = Offset(cos(angle), sin(angle)) * 6.5 + const Offset(0, -3);

    void pickaxe() => _drawPickaxe(canvas, pick, hand, angle, c, time, opacity);

    // Back arm (behind the body).
    final backSwing = moving && !airborne ? -sin(walk) * 2.5 : (airborne ? -3.0 : 0.0);
    _stroke
      ..color = _shade(Color(outfit.primary), -0.25).withValues(alpha: opacity)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(-4 * dir, -7), Offset(-5 * dir + backSwing * dir, airborne ? -10 : 0), _stroke);
    _p.color = handColor;
    canvas.drawCircle(Offset(-5 * dir + backSwing * dir, airborne ? -10.5 : 0.5), 2, _p);

    final pickBehind = sin(angle) < -0.2;
    if (pickBehind) pickaxe();

    // ---- torso ----
    _drawTorso(canvas, outfit, character, dir, c, time, opacity);

    // ---- head + helmet ----
    _drawHead(canvas, character, dir, c);
    _drawHelmet(canvas, helmet, dir, c, time, opacity);

    if (!pickBehind) pickaxe();

    // Front arm reaching the pickaxe grip.
    _stroke
      ..color = c(outfit.primary)
      ..strokeWidth = 4.2;
    final shoulder = Offset(3 * dir, -7);
    canvas.drawLine(shoulder, hand, _stroke);
    _p.color = handColor;
    canvas.drawCircle(hand, 2.3, _p);
    canvas.drawCircle(hand, 2.3, _line);
    if (isMole) {
      // Digging claws.
      _stroke
        ..color = c(0xFFEDE6D6)
        ..strokeWidth = 0.9;
      for (var i = -1; i <= 1; i++) {
        final a = angle + i * 0.45;
        canvas.drawLine(hand, hand + Offset(cos(a), sin(a)) * 3.6, _stroke);
      }
    }
    canvas.restore();
  }

  // ---- torso / outfits --------------------------------------------------------

  static void _drawTorso(Canvas canvas, CosmeticDef outfit, CosmeticDef ch, double dir, Color Function(int) c, double t, double opacity) {
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -3), width: 17, height: 15), const Radius.circular(5.5));
    final base = Color(outfit.primary);
    _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
    _p.shader = _cached(
      ('torso', outfit.primary, opacity),
      () => Gradient.linear(
        const Offset(-8, -10),
        const Offset(8, 5),
        [_shade(base, 0.18).withValues(alpha: opacity), base.withValues(alpha: opacity), _shade(base, -0.3).withValues(alpha: opacity)],
        const [0, 0.5, 1],
      ),
    );
    canvas.drawRRect(body, _p);
    _p.shader = null;

    canvas.save();
    canvas.clipRRect(body);
    final sec = c(outfit.secondary);
    switch (outfit.id) {
      case 'outfit_plaid':
        _p.color = Color.fromRGBO(0, 0, 0, 0.28 * opacity);
        for (var i = -8.0; i < 9; i += 4) {
          canvas.drawRect(Rect.fromLTWH(i, -11, 1.6, 16), _p);
          canvas.drawRect(Rect.fromLTWH(-9, i - 2, 18, 1.4), _p);
        }
      case 'outfit_forest':
        // Camo blotches.
        _p.color = _shade(Color(outfit.primary), -0.3).withValues(alpha: opacity);
        for (final (x, y, w) in const [(-5.0, -8.0, 6.0), (3.0, -4.0, 7.0), (-3.0, 1.0, 5.0), (5.0, -10.0, 4.0)]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.6), _p);
        }
        _p.color = c(0xFF6B4A2A);
        canvas.drawOval(Rect.fromCenter(center: const Offset(-1, -5), width: 4, height: 2.6), _p);
      case 'outfit_denim':
        _stroke
          ..color = Color.fromRGBO(255, 214, 140, 0.7 * opacity)
          ..strokeWidth = 0.6;
        canvas.drawRect(const Rect.fromLTWH(-5, -7, 10, 7), _stroke);
        _p.color = c(0xFFD9A441);
        canvas.drawCircle(const Offset(-4, -8), 0.9, _p);
        canvas.drawCircle(const Offset(4, -8), 0.9, _p);
      case 'outfit_purple':
        _p.color = c(0xFFFFD34D);
        canvas.drawRect(const Rect.fromLTWH(-1, -11, 2, 16), _p);
        canvas.drawCircle(const Offset(0, -6), 1.2, _p);
        canvas.drawCircle(const Offset(0, -2), 1.2, _p);
      case 'outfit_mint':
        _p.color = Color.fromRGBO(255, 255, 255, 0.55 * opacity);
        canvas.drawRect(const Rect.fromLTWH(-9, -6, 18, 1.6), _p);
        canvas.drawRect(const Rect.fromLTWH(-9, -3, 18, 1.6), _p);
      case 'outfit_gold':
        final shine = (sin(t * 2.4) + 1) / 2;
        _p.color = Color.fromRGBO(255, 255, 255, (0.2 + 0.45 * shine) * opacity);
        canvas.drawPath(
          Path()
            ..moveTo(-9 + shine * 10, -11)
            ..lineTo(-5 + shine * 10, -11)
            ..lineTo(-11 + shine * 10, 5)
            ..lineTo(-15 + shine * 10, 5)
            ..close(),
          _p,
        );
      case 'outfit_ice':
        _stroke
          ..color = Color.fromRGBO(255, 255, 255, 0.75 * opacity)
          ..strokeWidth = 0.8;
        for (final o in const [Offset(-4, -6), Offset(4, -1)]) {
          for (var k = 0; k < 3; k++) {
            final a = k * pi / 3;
            canvas.drawLine(o - Offset(cos(a), sin(a)) * 2.6, o + Offset(cos(a), sin(a)) * 2.6, _stroke);
          }
        }
      case 'outfit_lava':
        // Glowing magma cracks.
        final glow = 0.6 + 0.4 * sin(t * 3);
        _stroke
          ..color = Color.fromRGBO(255, 190, 60, glow * opacity)
          ..strokeWidth = 1.2;
        canvas.drawPath(
          Path()
            ..moveTo(-7, -9)
            ..lineTo(-3, -5)
            ..lineTo(-5, -1)
            ..lineTo(-1, 3),
          _stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6, -10)
            ..lineTo(3, -6)
            ..lineTo(6, -2),
          _stroke,
        );
      default:
        // Classic overalls: bib + straps.
        _p.color = sec.withValues(alpha: 0.85 * opacity);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -6, 10, 8), const Radius.circular(2)), _p);
        canvas.drawRect(const Rect.fromLTWH(-5, -11, 2, 6), _p);
        canvas.drawRect(const Rect.fromLTWH(3, -11, 2, 6), _p);
        _p.color = c(0xFFD9A441);
        canvas.drawCircle(const Offset(-4, -5.5), 0.9, _p);
        canvas.drawCircle(const Offset(4, -5.5), 0.9, _p);
    }
    // Character-specific chest details.
    if (ch.style == Face.robot) {
      _p.color = c(0xFF2FD4C4).withValues(alpha: (0.5 + 0.4 * sin(t * 4)) * opacity);
      canvas.drawCircle(Offset(2 * dir, -5), 1.6, _p);
    } else if (ch.style == Face.goggles) {
      // Tinker's tool belt.
      _p.color = c(0xFFB5651D);
      canvas.drawRect(const Rect.fromLTWH(-9, 0.5, 18, 2.4), _p);
      _p.color = c(0xFFC9D1D9);
      canvas.drawRect(Rect.fromLTWH(-5 * dir, -1, 1.4, 4), _p);
    }
    canvas.restore();

    // Belt + outline.
    _p.color = Color.fromRGBO(30, 20, 14, 0.55 * opacity);
    canvas.drawRect(const Rect.fromLTWH(-8.5, 1, 17, 1.8), _p);
    canvas.drawRRect(body, _line);
    if (outfit.isPremium) {
      final tw = (sin(t * 3.1) + 1) / 2;
      if (tw > 0.6) {
        _p.color = Color.fromRGBO(255, 255, 255, (tw - 0.6) * 2.4 * opacity);
        _sparkle(canvas, Offset(5 * dir, -8), 3 * tw);
      }
    }
  }

  // ---- heads --------------------------------------------------------------------

  static void _drawHead(Canvas canvas, CosmeticDef ch, double dir, Color Function(int) c) {
    const head = Offset(0, -14);
    final skin = c(ch.primary);
    final hair = c(ch.secondary);
    final eye = Offset(2.8 * dir, -14.2);

    switch (ch.style) {
      case Face.ponytail:
        _p.color = hair;
        canvas.drawOval(Rect.fromCenter(center: Offset(-7 * dir, -11.5), width: 5, height: 10), _p);
        canvas.drawOval(Rect.fromCenter(center: Offset(-7 * dir, -11.5), width: 5, height: 10), _line);
      case Face.robot:
        final r = RRect.fromRectAndRadius(Rect.fromCenter(center: head, width: 15, height: 13.5), const Radius.circular(3.5));
        _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
        _p.shader = _cached(
          ('robot', ch.primary),
          () => Gradient.linear(
            const Offset(-7, -20),
            const Offset(7, -8),
            [_shade(Color(ch.primary), 0.3), Color(ch.primary), _shade(Color(ch.primary), -0.35)],
            const [0, 0.5, 1],
          ),
        );
        canvas.drawRRect(r, _p);
        _p.shader = null;
        canvas.drawRRect(r, _line);
        // Visor.
        _p.color = c(0xFF111820);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(1.8 * dir, -14), width: 10, height: 4.4), const Radius.circular(2)),
          _p,
        );
        _p.color = hair;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(3 * dir, -14), width: 4.5, height: 2), const Radius.circular(1)),
          _p,
        );
        // Rivets + antenna.
        _p.color = c(0xFF6B7785);
        canvas.drawCircle(Offset(-5 * dir, -10), 0.8, _p);
        canvas.drawCircle(Offset(-5 * dir, -18), 0.8, _p);
        canvas.drawRect(const Rect.fromLTWH(-0.8, -25, 1.6, 4.5), _p);
        _p.color = hair;
        canvas.drawCircle(const Offset(0, -25.5), 1.5, _p);
        return;
      default:
        break;
    }

    // Head with soft shading.
    _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
    _p.shader = _cached(
      ('head', ch.primary, dir),
      () => Gradient.radial(
        head + Offset(2 * dir, -2),
        8.5,
        [_shade(Color(ch.primary), 0.15), Color(ch.primary), _shade(Color(ch.primary), -0.25)],
        const [0, 0.6, 1],
      ),
    );
    canvas.drawCircle(head, 6.8, _p);
    _p.shader = null;
    canvas.drawCircle(head, 6.8, _line);
    // Ear.
    if (ch.style != Face.skeleton && ch.style != Face.mole) {
      _p.color = _shade(Color(ch.primary), -0.15);
      canvas.drawCircle(Offset(-3.2 * dir, -13.5), 1.7, _p);
    }

    switch (ch.style) {
      case Face.beard:
        _p.color = hair;
        canvas.drawPath(
          Path()
            ..moveTo(-6.5, -13)
            ..quadraticBezierTo(-6.5, -3, 0, -2.5)
            ..quadraticBezierTo(6.5, -3, 6.5, -13)
            ..quadraticBezierTo(0, -9.5, -6.5, -13)
            ..close(),
          _p,
        );
        // Moustache + bushy brow.
        canvas.drawOval(Rect.fromCenter(center: Offset(2.8 * dir, -11.4), width: 6, height: 2.2), _p);
        canvas.drawRect(Rect.fromLTWH(1.2 * dir - (dir < 0 ? 3.4 : 0), -16.6, 3.4, 1.2), _p);
        _p.color = c(0xFF1B1B1B);
        canvas.drawCircle(eye, 1.1, _p);
      case Face.goggles:
        _p.color = hair;
        canvas.drawRect(const Rect.fromLTWH(-6.8, -15.8, 13.6, 2.6), _p);
        _p.color = c(0xFF8A5A2B);
        canvas.drawCircle(Offset(2.8 * dir, -14.4), 3, _p);
        _p.color = c(0xFF7FD3FF);
        canvas.drawCircle(Offset(2.8 * dir, -14.4), 2, _p);
        _p.color = c(0xFFFFFFFF);
        canvas.drawCircle(Offset(2.2 * dir, -15), 0.7, _p);
        _drawSmile(canvas, dir, c);
      case Face.ninja:
        _p.color = hair;
        canvas.drawPath(
          Path()
            ..addArc(Rect.fromCircle(center: head, radius: 6.8), 0.05, pi - 0.1)
            ..close(),
          _p,
        );
        canvas.drawPath(
          Path()
            ..addArc(Rect.fromCircle(center: head, radius: 6.8), pi + 0.05, pi - 0.1)
            ..close(),
          _p,
        );
        _p.color = skin;
        canvas.drawRect(Rect.fromLTWH(dir > 0 ? -1 : -6, -16, 7, 3.2), _p);
        // Headband tails.
        _p.color = c(0xFFE53935);
        canvas.drawRect(const Rect.fromLTWH(-6.8, -18.5, 13.6, 1.6), _p);
        canvas.drawPath(
          Path()
            ..moveTo(-6 * dir, -18)
            ..lineTo(-11 * dir, -20)
            ..lineTo(-10 * dir, -16.5)
            ..close(),
          _p,
        );
        _p.color = c(0xFF1B1B1B);
        canvas.drawCircle(eye, 1.1, _p);
      case Face.mole:
        _p.color = c(0xFF4E3629);
        canvas.drawCircle(head + const Offset(0, -0.5), 6, _p);
        // Snout + pink nose + tiny eye.
        _p.color = c(0xFF8A6A55);
        canvas.drawOval(Rect.fromCenter(center: Offset(5 * dir, -12.6), width: 5.5, height: 4), _p);
        _p.color = hair;
        canvas.drawCircle(Offset(7.4 * dir, -12.8), 1.8, _p);
        _p.color = c(0xFF111111);
        canvas.drawCircle(Offset(2.2 * dir, -15.4), 0.8, _p);
        _stroke
          ..color = c(0xFFEDE6D6)
          ..strokeWidth = 0.4;
        canvas.drawLine(Offset(6 * dir, -12), Offset(10 * dir, -11), _stroke);
        canvas.drawLine(Offset(6 * dir, -12.6), Offset(10 * dir, -13.2), _stroke);
      case Face.skeleton:
        _p.color = hair;
        canvas.drawOval(Rect.fromCenter(center: Offset(2.4 * dir, -14.6), width: 3.4, height: 3.8), _p);
        canvas.drawOval(Rect.fromCenter(center: Offset(-1.6 * dir, -14.6), width: 2.8, height: 3.4), _p);
        canvas.drawPath(
          Path()
            ..moveTo(0.4 * dir, -12.4)
            ..lineTo(1.2 * dir, -11.2)
            ..lineTo(-0.4 * dir, -11.2)
            ..close(),
          _p,
        );
        for (var i = -2; i <= 2; i++) {
          canvas.drawRect(Rect.fromLTWH(i * 1.6 - 0.5, -9.8, 1, 1.8), _p);
        }
        // Glowing pupil.
        _p.color = c(0xFF7CFFB2);
        canvas.drawCircle(Offset(2.4 * dir, -14.6), 0.6, _p);
      case Face.ponytail:
        _p.color = hair;
        canvas.drawArc(Rect.fromCircle(center: head, radius: 6.8), pi + 0.2, pi - 0.4, true, _p);
        _p.color = c(0xFF1B1B1B);
        canvas.drawCircle(eye, 1.1, _p);
        _p.color = c(0xFFE88A8A).withValues(alpha: 0.5);
        canvas.drawCircle(Offset(3.2 * dir, -11.6), 1.3, _p);
        _drawSmile(canvas, dir, c);
      default:
        // Rookie: a little fringe and a grin.
        _p.color = hair;
        canvas.drawArc(Rect.fromCircle(center: head, radius: 6.8), pi + 0.4, pi - 0.9, true, _p);
        _p.color = c(0xFF1B1B1B);
        canvas.drawCircle(eye, 1.1, _p);
        _p.color = c(0xFFFFFFFF);
        canvas.drawCircle(eye + Offset(0.35 * dir, -0.4), 0.35, _p);
        _drawSmile(canvas, dir, c);
    }
  }

  static void _drawSmile(Canvas canvas, double dir, Color Function(int) c) {
    _stroke
      ..color = c(0xFF7A3B2A)
      ..strokeWidth = 1;
    canvas.drawArc(Rect.fromCenter(center: Offset(2.4 * dir, -11.2), width: 3.6, height: 2.4), 0.2, pi - 0.4, false, _stroke);
  }

  // ---- helmets -------------------------------------------------------------------

  static void _drawHelmet(Canvas canvas, CosmeticDef h, double dir, Color Function(int) c, double t, double opacity) {
    final base = Color(h.primary);
    Shader dome(Rect r) => _cached(
      ('dome', h.primary, opacity, r),
      () => Gradient.linear(
        r.topLeft,
        r.bottomRight,
        [_shade(base, 0.35).withValues(alpha: opacity), base.withValues(alpha: opacity), _shade(base, -0.3).withValues(alpha: opacity)],
        const [0, 0.45, 1],
      ),
    );

    switch (h.style) {
      case 1: // crown
        final crown = Path()
          ..moveTo(-7.5, -17)
          ..lineTo(-7.5, -24)
          ..lineTo(-3.8, -20.5)
          ..lineTo(0, -26)
          ..lineTo(3.8, -20.5)
          ..lineTo(7.5, -24)
          ..lineTo(7.5, -17)
          ..close();
        _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
        _p.shader = dome(const Rect.fromLTWH(-7.5, -26, 15, 9));
        canvas.drawPath(crown, _p);
        _p.shader = null;
        canvas.drawPath(crown, _line);
        _p.color = c(h.secondary);
        canvas.drawCircle(const Offset(0, -19.5), 1.7, _p);
        _p.color = c(0xFF3E6FB0);
        canvas.drawCircle(const Offset(-4.5, -18.8), 1, _p);
        canvas.drawCircle(const Offset(4.5, -18.8), 1, _p);
        final tw = (sin(t * 2.7) + 1) / 2;
        if (tw > 0.55) {
          _p.color = Color.fromRGBO(255, 255, 255, (tw - 0.55) * 2 * opacity);
          _sparkle(canvas, const Offset(0, -26), 3.5 * tw);
        }
      case 2: // viking
        final r = Rect.fromCircle(center: const Offset(0, -15.5), radius: 7.5);
        _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
        _p.shader = dome(r);
        canvas.drawArc(r, pi, pi, true, _p);
        _p.shader = null;
        canvas.drawArc(r, pi, pi, true, _line);
        _p.color = c(0xFF8A6A3A);
        canvas.drawRect(const Rect.fromLTWH(-7.5, -16.5, 15, 2), _p);
        _p.color = c(h.secondary);
        final hornL = Path()
          ..moveTo(-6, -19)
          ..quadraticBezierTo(-13, -20, -12, -28)
          ..quadraticBezierTo(-10, -22, -6.5, -21.5)
          ..close();
        final hornR = Path()
          ..moveTo(6, -19)
          ..quadraticBezierTo(13, -20, 12, -28)
          ..quadraticBezierTo(10, -22, 6.5, -21.5)
          ..close();
        canvas.drawPath(hornL, _p);
        canvas.drawPath(hornR, _p);
        canvas.drawPath(hornL, _line);
        canvas.drawPath(hornR, _line);
      case 3: // prospector hat
        _p.color = _shade(base, -0.15).withValues(alpha: opacity);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -19, 24, 3.2), const Radius.circular(1.6)), _p);
        final crown = RRect.fromRectAndRadius(const Rect.fromLTWH(-6.5, -26, 13, 8.5), const Radius.circular(3.2));
        _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
        _p.shader = dome(crown.outerRect);
        canvas.drawRRect(crown, _p);
        _p.shader = null;
        canvas.drawRRect(crown, _line);
        _p.color = c(h.secondary);
        canvas.drawRect(const Rect.fromLTWH(-6.5, -20, 13, 1.8), _p);
      case 4: // beanie
        final r = Rect.fromCircle(center: const Offset(0, -15.2), radius: 7.3);
        _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
        _p.shader = dome(r);
        canvas.drawArc(r, pi, pi, true, _p);
        _p.shader = null;
        _stroke
          ..color = _shade(base, -0.25).withValues(alpha: opacity)
          ..strokeWidth = 0.7;
        for (var x = -5.0; x <= 5; x += 2.5) {
          canvas.drawLine(Offset(x, -20.5), Offset(x, -16), _stroke);
        }
        _p.color = c(h.secondary);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -16.8, 16, 3.2), const Radius.circular(1.6)), _p);
        canvas.drawCircle(const Offset(0, -23.2), 2.5, _p);
        canvas.drawCircle(const Offset(0, -23.2), 2.5, _line);
      default: // hard hat with lamp
        final r = Rect.fromCircle(center: const Offset(0, -15.5), radius: 7.5);
        _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
        _p.shader = dome(r);
        canvas.drawArc(r, pi, pi, true, _p);
        _p.shader = null;
        canvas.drawArc(r, pi, pi, true, _line);
        _p.color = _shade(base, 0.25).withValues(alpha: opacity);
        canvas.drawRect(const Rect.fromLTWH(-0.8, -22.8, 1.6, 6.5), _p); // ridge
        _p.color = _shade(base, -0.2).withValues(alpha: opacity);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-8.5 + dir, -16.8, 17, 2.6), const Radius.circular(1.2)), _p);
        // Lamp.
        final lamp = Offset(5 * dir, -19);
        _p.color = c(0xFF3A3A3A);
        canvas.drawCircle(lamp, 2.6, _p);
        _p.color = c(h.secondary);
        canvas.drawCircle(lamp, 1.8, _p);
        _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
        _p.shader = _cached((
          'lamp',
          dir,
          opacity,
        ), () => Gradient.radial(lamp, 7, [Color.fromRGBO(255, 247, 209, 0.55 * opacity), const Color(0x00FFF7D1)]));
        canvas.drawCircle(lamp, 7, _p);
        _p.shader = null;
    }
  }

  // ---- pickaxes ------------------------------------------------------------------

  static void _drawPickaxe(Canvas canvas, CosmeticDef pick, Offset hand, double angle, Color Function(int) c, double t, double opacity) {
    final d = Offset(cos(angle), sin(angle));
    final perp = Offset(-sin(angle), cos(angle));
    final handleColor = c(pick.primary);
    final headColor = Color(pick.secondary);

    if (pick.style == PickStyle.drill) {
      // Motor body in hand, spinning cone bit pointing forward.
      final body = hand + d * 4;
      final tip = hand + d * 17;
      _stroke
        ..color = handleColor
        ..strokeWidth = 6;
      canvas.drawLine(hand - d * 1, body + d * 3, _stroke);
      _p.color = headColor.withValues(alpha: opacity);
      final cone = Path()
        ..moveTo((body + d * 3 + perp * 3.6).dx, (body + d * 3 + perp * 3.6).dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo((body + d * 3 - perp * 3.6).dx, (body + d * 3 - perp * 3.6).dy)
        ..close();
      canvas.drawPath(cone, _p);
      canvas.drawPath(cone, _line);
      // Spiral grooves (spin with time).
      _stroke
        ..color = _shade(headColor, -0.4).withValues(alpha: opacity)
        ..strokeWidth = 0.9;
      final ph = (t * 14) % 1;
      for (var k = 0; k < 3; k++) {
        final f = (k + ph) / 3;
        final at = body + d * (3 + 10 * f);
        final w = 3.6 * (1 - f);
        canvas.drawLine(at + perp * w, at + d * 2 - perp * w, _stroke);
      }
      if (pick.isPremium) {
        _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
        _p.shader = Gradient.radial(tip, 6, [headColor.withValues(alpha: 0.6 * opacity), headColor.withValues(alpha: 0)]);
        canvas.drawCircle(tip, 6, _p);
        _p.shader = null;
      }
      return;
    }

    // Wooden/metal handle.
    final head = hand + d * 14;
    _stroke
      ..color = _shade(Color(pick.primary), -0.3).withValues(alpha: opacity)
      ..strokeWidth = 3.6;
    canvas.drawLine(hand - d * 2, head, _stroke);
    _stroke
      ..color = handleColor
      ..strokeWidth = 2.4;
    canvas.drawLine(hand - d * 2, head, _stroke);

    _p.color = headColor.withValues(alpha: opacity);
    switch (pick.style) {
      case PickStyle.axe:
        // Two curved blades.
        for (final s in const [1.0, -1.0]) {
          final blade = Path()
            ..moveTo((head + perp * 1.5 * s - d * 2).dx, (head + perp * 1.5 * s - d * 2).dy)
            ..quadraticBezierTo(
              (head + perp * 9 * s - d * 5).dx,
              (head + perp * 9 * s - d * 5).dy,
              (head + perp * 8 * s).dx,
              (head + perp * 8 * s).dy,
            )
            ..quadraticBezierTo(
              (head + perp * 9 * s + d * 5).dx,
              (head + perp * 9 * s + d * 5).dy,
              (head + perp * 1.5 * s + d * 2).dx,
              (head + perp * 1.5 * s + d * 2).dy,
            )
            ..close();
          canvas.drawPath(blade, _p);
          canvas.drawPath(blade, _line);
        }
        _p.color = c(0xFF2E2E36);
        canvas.drawCircle(head, 2, _p);
      case PickStyle.mattock:
        // Wide flat blade one side, spike the other.
        final blade = Path()
          ..moveTo((head - d * 2.5).dx, (head - d * 2.5).dy)
          ..lineTo((head + perp * 8 - d * 3.5).dx, (head + perp * 8 - d * 3.5).dy)
          ..lineTo((head + perp * 8 + d * 3.5).dx, (head + perp * 8 + d * 3.5).dy)
          ..lineTo((head + d * 2.5).dx, (head + d * 2.5).dy)
          ..close();
        canvas.drawPath(blade, _p);
        canvas.drawPath(blade, _line);
        _stroke
          ..color = headColor.withValues(alpha: opacity)
          ..strokeWidth = 3;
        canvas.drawLine(head, head - perp * 7, _stroke);
      default:
        // Classic curved pick head.
        final pickHead = Path()
          ..moveTo((head - perp * 8 + d * 1.5).dx, (head - perp * 8 + d * 1.5).dy)
          ..quadraticBezierTo((head + d * 4).dx, (head + d * 4).dy, (head + perp * 7 + d * 1.5).dx, (head + perp * 7 + d * 1.5).dy)
          ..lineTo((head + perp * 6).dx, (head + perp * 6).dy)
          ..quadraticBezierTo((head - d * 1).dx, (head - d * 1).dy, (head - perp * 7).dx, (head - perp * 7).dy)
          ..close();
        canvas.drawPath(pickHead, _p);
        canvas.drawPath(pickHead, _line);
    }
    // Shine on the metal.
    _p.color = Color.fromRGBO(255, 255, 255, 0.5 * opacity);
    canvas.drawCircle(head + perp * 3 + d * 1.2, 0.9, _p);
    if (pick.isPremium || pick.price >= 1400) {
      final tw = (sin(t * 3.3 + pick.id.length) + 1) / 2;
      if (tw > 0.5) {
        _p.color = Color.fromRGBO(255, 255, 255, (tw - 0.5) * 2 * opacity);
        _sparkle(canvas, head + perp * 6, 3 * tw);
      }
    }
  }

  /// Twin-tank jetpack on the back; a flickering flame while it fires.
  static void _drawJetpack(Canvas canvas, double dir, bool firing, double t, double opacity) {
    final x = -9.5 * dir;
    if (firing) {
      final f = 0.75 + 0.25 * sin(t * 40);
      _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
      _p.shader = Gradient.linear(
        Offset(x, 4),
        Offset(x, 4 + 13 * f),
        [Color.fromRGBO(255, 248, 200, opacity), Color.fromRGBO(255, 150, 40, 0.9 * opacity), const Color(0x00FF5A1F)],
        const [0, 0.4, 1],
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - 3.2, 3)
          ..quadraticBezierTo(x, 4 + 14 * f, x + 3.2, 3)
          ..close(),
        _p,
      );
      _p.shader = null;
    }
    final tank = RRect.fromRectAndRadius(Rect.fromLTWH(x - 3.5, -11, 7, 14), const Radius.circular(3));
    _p.color = const Color(0xFFFFFFFF); // a shader fill must not inherit a faded colour
    _p.shader = _cached(
      ('tank', x, opacity),
      () => Gradient.linear(Offset(x - 3.5, 0), Offset(x + 3.5, 0), [
        Color.fromRGBO(190, 200, 212, opacity),
        Color.fromRGBO(120, 130, 145, opacity),
      ]),
    );
    canvas.drawRRect(tank, _p);
    _p.shader = null;
    canvas.drawRRect(tank, _line);
    _p.color = Color.fromRGBO(229, 57, 53, opacity);
    canvas.drawRect(Rect.fromLTWH(x - 3.5, -6, 7, 2), _p);
    _p.color = Color.fromRGBO(60, 60, 66, opacity);
    canvas.drawRect(Rect.fromLTWH(x - 2.2, 3, 4.4, 2), _p);
  }

  static void _sparkle(Canvas canvas, Offset o, double s) {
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
}
