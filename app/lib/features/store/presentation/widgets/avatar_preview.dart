import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../game/presentation/flame/miner_art.dart';

/// Animated avatar (idle breathing + occasional pickaxe swing).
class AvatarPreview extends StatefulWidget {
  const AvatarPreview({super.key, required this.look, required this.seed, this.size = 200, this.animate = true});
  final Look look;
  final String seed;
  final double size;
  final bool animate;

  @override
  State<AvatarPreview> createState() => _AvatarPreviewState();
}

class _AvatarPreviewState extends State<AvatarPreview> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _AvatarPainter(widget.look, widget.seed, _c.value)),
    ),
  );
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.look, this.seed, this.t);
  final Look look;
  final String seed;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 44;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.62);
    canvas.scale(scale);
    final swinging = t > 0.55 && t < 0.85;
    MinerArt.draw(canvas, look: look, seed: seed, mining: swinging, swing: (t - 0.55) * 40, aim: 0, walk: t * pi * 2, time: t * 9);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.t != t || old.look != look;
}
