import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Virtual joystick. Reports a vector with length ≤ 1.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({super.key, required this.onChanged, this.size = 140});
  final void Function(double x, double y) onChanged;
  final double size;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knob = Offset.zero;

  void _update(Offset local) {
    final r = widget.size / 2;
    var v = local - Offset(r, r);
    if (v.distance > r) v = v / v.distance * r;
    setState(() => _knob = v);
    final x = v.dx / r, y = v.dy / r;
    // Small dead zone.
    widget.onChanged(sqrt(x * x + y * y) < 0.15 ? 0 : x, sqrt(x * x + y * y) < 0.15 ? 0 : y);
  }

  void _end() {
    setState(() => _knob = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      onPanStart: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: SizedBox.square(
        dimension: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: Colors.white24, width: 2),
              ),
            ),
            Transform.translate(
              offset: _knob,
              child: Container(
                width: s * 0.4,
                height: s * 0.4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: MMColors.amber.withValues(alpha: 0.85)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hold-to-mine button.
class MineButton extends StatefulWidget {
  const MineButton({super.key, required this.onChanged});
  final ValueChanged<bool> onChanged;

  @override
  State<MineButton> createState() => _MineButtonState();
}

class _MineButtonState extends State<MineButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? 0.92 : 1,
      duration: const Duration(milliseconds: 80),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (_down ? MMColors.ember : MMColors.amber).withValues(alpha: 0.9),
          boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black54)],
        ),
        child: const Icon(Icons.hardware, size: 44, color: MMColors.bg),
      ),
    ),
  );
}
