import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../theme.dart';

/// The loading art, cut from the splash illustration (assets/images/loading).
abstract final class LoadingArt {
  static const backdrop = AssetImage('assets/images/loading/backdrop.webp');
  static const hero = AssetImage('assets/images/loading/hero.webp');
  static const title = AssetImage('assets/images/loading/title.webp');
  static const all = [backdrop, hero, title];
}

/// Full-screen loading screen: the miners on one side, the logo and a
/// fuse-style progress bar on the other. Draws nothing expensive (no blur,
/// no shaders): the backdrop is pre-blurred and the art has soft edges baked in.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, required this.progress, required this.showArt});

  /// 0..1; the bar eases towards each new value.
  final ValueListenable<double> progress;

  /// False while the art is still decoding (the OS splash covers that time).
  final bool showArt;

  /// Same colour as the OS splash, so the hand-over is seamless.
  static const background = MMColors.bg;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: background,
    child: AnimatedOpacity(
      opacity: showArt ? 1 : 0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Image(image: LoadingArt.backdrop, fit: BoxFit.cover, gaplessPlayback: true),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: RadialGradient(radius: 1.1, colors: [Color(0x00120E1F), Color(0xB3120E1F)])),
          ),
          SafeArea(child: LayoutBuilder(builder: (context, box) => box.maxWidth >= box.maxHeight ? _landscape(box) : _portrait(box))),
        ],
      ),
    ),
  );

  Widget _landscape(BoxConstraints box) {
    final panel = math.min(box.maxWidth * 0.46, 460.0);
    return Row(
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 12, 0, 0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Image(image: LoadingArt.hero, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ),
        SizedBox(
          width: panel,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 28, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(
                  child: Image(image: LoadingArt.title, fit: BoxFit.contain, gaplessPlayback: true),
                ),
                const SizedBox(height: 14),
                _LoadingBar(progress: progress),
                const SizedBox(height: 14),
                const _Tips(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _portrait(BoxConstraints box) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
    child: Column(
      children: [
        const Flexible(
          flex: 3,
          child: Image(image: LoadingArt.title, fit: BoxFit.contain),
        ),
        const Flexible(
          flex: 5,
          child: Image(image: LoadingArt.hero, fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _LoadingBar(progress: progress),
        ),
        const SizedBox(height: 14),
        const _Tips(),
      ],
    ),
  );
}

/// "LOADING..." + a rounded gold bar with a burning fuse tip.
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress});
  final ValueListenable<double> progress;

  static const _label = TextStyle(
    fontFamily: MMFonts.display,
    fontSize: 15,
    letterSpacing: 1.6,
    color: MMColors.goldLight,
    shadows: [Shadow(color: Color(0xCC000000), offset: Offset(0, 2), blurRadius: 3)],
  );

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, target, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(v >= 0.999 ? "LET'S DIG!" : 'LOADING...', style: _label),
                const Spacer(),
                Text('${(v * 100).round()}%', style: _label),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(height: 22, child: CustomPaint(painter: _BarPainter(v))),
          ],
        ),
      ),
    ),
  );
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, r);
    final p = Paint()..color = const Color(0xFF0B0814);
    canvas.drawRRect(track, p);
    p
      ..color = const Color(0xFF5A4A7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(track.deflate(1), p);
    p.style = PaintingStyle.fill;

    final inner = track.deflate(4);
    final w = inner.width * value.clamp(0.0, 1.0);
    if (w < 1) return;
    final fill = RRect.fromLTRBR(inner.left, inner.top, inner.left + math.max(w, inner.height), inner.bottom, inner.tlRadius);
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [MMColors.goldLight, MMColors.gold, MMColors.goldDeep],
      stops: [0, 0.55, 1],
    ).createShader(fill.outerRect);
    canvas.drawRRect(fill, p);
    p.shader = null;
    // Glossy highlight.
    p.color = const Color(0x59FFFFFF);
    canvas.drawRRect(
      RRect.fromLTRBR(fill.left + 4, fill.top + 2, fill.right - 4, fill.top + fill.height * 0.42, const Radius.circular(4)),
      p,
    );
    // Fuse spark at the tip.
    final tip = Offset(fill.right - 2, fill.center.dy);
    p.color = const Color(0x66FF6A3D);
    canvas.drawCircle(tip, size.height * 0.62, p);
    p.color = const Color(0xFFFFE08A);
    canvas.drawCircle(tip, size.height * 0.26, p);
    p.color = const Color(0xFFFFFFFF);
    canvas.drawCircle(tip, size.height * 0.12, p);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.value != value;
}

/// One short gameplay tip at a time, cross-fading every few seconds.
class _Tips extends StatefulWidget {
  const _Tips();

  @override
  State<_Tips> createState() => _TipsState();
}

class _TipsState extends State<_Tips> {
  static const _tips = [
    'Lava flows. Never dig straight down into it.',
    'Digging under a boulder? It will fall on you.',
    'TNT has a short fuse. Light it and run!',
    'Watch the treasure hint: it gets warmer as you get close.',
    'Spend your coins on upgrades to dig faster.',
  ];
  late int _i = DateTime.now().millisecond % _tips.length;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) => setState(() => _i = (_i + 1) % _tips.length));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _tips[_i],
        key: ValueKey(_i),
        textAlign: TextAlign.center,
        maxLines: 2,
        style: const TextStyle(fontFamily: MMFonts.body, fontWeight: FontWeight.w700, fontSize: 13, height: 1.3, color: MMColors.muted),
      ),
    ),
  );
}
