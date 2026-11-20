import 'package:flutter/widgets.dart';

import '../theme.dart';

/// Drawn coin: gold disc, darker rim, embossed inner ring and shine.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final p = Paint()..color = MMColors.goldDeep;
    canvas.drawCircle(c + Offset(0, r * 0.1), r, p);
    p.shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [MMColors.goldLight, MMColors.gold])
        .createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * 0.94, p);
    p
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14
      ..color = const Color(0x55C27A00);
    canvas.drawCircle(c, r * 0.6, p);
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xCCFFFFFF);
    canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.38), r * 0.16, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Drawn gem: faceted teal diamond.
class GemIcon extends StatelessWidget {
  const GemIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GemPainter());
}

class _GemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final outline = Path()
      ..moveTo(w * 0.22, h * 0.12)
      ..lineTo(w * 0.78, h * 0.12)
      ..lineTo(w * 0.98, h * 0.38)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.02, h * 0.38)
      ..close();
    final p = Paint()..color = MMColors.gemDeep;
    canvas.drawPath(outline.shift(Offset(0, h * 0.05)), p);
    p.color = MMColors.gem;
    canvas.drawPath(outline, p);
    p.color = const Color(0xFF9CFAEC);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.22, h * 0.12)
        ..lineTo(w * 0.78, h * 0.12)
        ..lineTo(w * 0.66, h * 0.38)
        ..lineTo(w * 0.34, h * 0.38)
        ..close(),
      p,
    );
    p.color = const Color(0x3D000000);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.95)
        ..lineTo(w * 0.66, h * 0.38)
        ..lineTo(w * 0.98, h * 0.38)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum CurrencyKind { coins, gems }

/// Balance chip, e.g. [coin] 1,250.
class CurrencyPill extends StatelessWidget {
  const CurrencyPill(this.amount, {super.key, this.kind = CurrencyKind.coins, this.large = false});
  final int amount;
  final CurrencyKind kind;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final iconSize = large ? 22.0 : 16.0;
    return Container(
      padding: EdgeInsets.fromLTRB(5, large ? 5 : 3, large ? 14 : 10, large ? 5 : 3),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: (kind == CurrencyKind.coins ? MMColors.gold : MMColors.gem).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kind == CurrencyKind.coins) CoinIcon(size: iconSize) else GemIcon(size: iconSize),
          SizedBox(width: large ? 7 : 5),
          Text(formatAmount(amount), style: MMText.number.copyWith(fontSize: large ? 18 : 14, color: MMColors.text, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

String formatAmount(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
