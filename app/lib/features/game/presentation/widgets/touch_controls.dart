import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';

/// Frosted virtual joystick. Reports a vector with length ≤ 1.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({super.key, required this.onChanged, this.size = 124});
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
    final dead = sqrt(x * x + y * y) < 0.15;
    widget.onChanged(dead ? 0 : x, dead ? 0 : y);
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
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x33FFFFFF),
                    border: Border.all(color: const Color(0x33FFFFFF), width: 1),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: _knob,
              child: Container(
                width: s * 0.42,
                height: s * 0.42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xEEFFFFFF),
                  boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hold-to-dig button.
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
    if (v) HapticFeedback.lightImpact();
    setState(() => _down = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? 0.9 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: MMColors.accentGradient,
          border: Border.all(color: const Color(0x55FFFFFF), width: 2),
          boxShadow: [BoxShadow(color: const Color(0x88FF6B2C), blurRadius: _down ? 8 : 22, offset: const Offset(0, 6))],
        ),
        child: const Icon(Icons.hardware_rounded, size: 42, color: CupertinoColors.white),
      ),
    ),
  );
}
