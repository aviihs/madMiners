import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Material, MaterialType;
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// Shared, Cupertino-flavoured UI kit. Screens compose these instead of
/// styling raw widgets, so the whole app looks consistent.

/// Warm gradient backdrop with faint rock speckles.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [MMColors.bgTop, MMColors.bg, MMColors.bg],
        stops: [0, 0.45, 1],
      ),
    ),
    child: CustomPaint(painter: _SpecklePainter(), child: child),
  );
}

class _SpecklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    final p = Paint()..color = const Color(0x0DFFFFFF);
    for (var i = 0; i < 140; i++) {
      canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), rng.nextDouble() * 1.6 + 0.4, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted glass card.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.blur = 24,
    this.color = MMColors.glass,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double blur;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: MMColors.hairline, width: 0.5),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? card : PressableScale(onTap: onTap!, child: card);
  }
}

/// Subtle iOS-like press feedback.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedOpacity(opacity: _down ? 0.85 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return PressableScale(
      onTap: enabled ? onPressed! : () {},
      child: AnimatedOpacity(
        opacity: enabled || loading ? 1 : 0.45,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: MMColors.accentGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x55FF7A1A), blurRadius: 18, offset: Offset(0, 6))],
          ),
          alignment: Alignment.center,
          child: loading
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20, color: CupertinoColors.white), const SizedBox(width: 8)],
                    Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.white, letterSpacing: -0.2)),
                  ],
                ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon, this.color = MMColors.text});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onPressed ?? () {},
    child: Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: MMColors.glassStrong,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MMColors.hairline, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 19, color: color), const SizedBox(width: 8)],
            Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: color, letterSpacing: -0.2)),
          ],
        ),
      ),
    ),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.icon,
    this.onSubmitted,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData? icon;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final int? maxLength;

  @override
  Widget build(BuildContext context) => CupertinoTextField(
    controller: controller,
    placeholder: placeholder,
    autofocus: autofocus,
    maxLength: maxLength,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    onSubmitted: onSubmitted,
    style: MMText.body,
    placeholderStyle: MMText.body.copyWith(color: MMColors.faint),
    cursorColor: MMColors.amber,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    prefix: icon == null ? null : Padding(padding: const EdgeInsets.only(left: 14), child: Icon(icon, size: 20, color: MMColors.muted)),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: MMColors.hairline, width: 0.5),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Row(children: [Text(text.toUpperCase(), style: MMText.section), const Spacer(), ?trailing]),
  );
}

/// iOS "inset grouped" list.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: EdgeInsets.zero,
    radius: 16,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const Padding(padding: EdgeInsets.only(left: 64), child: _Hairline()),
        ],
      ],
    ),
  );
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => Container(height: 0.5, color: MMColors.hairline);
}

class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap});
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(width: 38, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MMText.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: MMText.footnote, maxLines: 1, overflow: TextOverflow.ellipsis)],
              ],
            ),
          ),
          ?trailing,
          if (onTap != null) ...[const SizedBox(width: 6), const Icon(CupertinoIcons.chevron_forward, size: 16, color: MMColors.faint)],
        ],
      ),
    );
    return onTap == null ? row : CupertinoButton(padding: EdgeInsets.zero, onPressed: onTap, child: row);
  }
}

/// Rounded square icon tile, like iOS settings icons.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color = MMColors.amber, this.size = 34});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(size * 0.28)),
    child: Icon(icon, size: size * 0.56, color: color),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = MMColors.muted, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color).merge(MMText.number)),
      ],
    ),
  );
}

/// Initials avatar with a stable per-name gradient.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 44, this.color});
  final String name;
  final double size;
  final Color? color;

  static Color colorFor(String seed) {
    final h = seed.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xffffff);
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.6, 0.55).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? colorFor(name);
    final letters = name.replaceAll(RegExp('[^A-Za-z]'), '');
    final initials = letters.isEmpty ? '?' : letters.substring(0, min(2, letters.length)).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [c, Color.lerp(c, const Color(0xFF000000), 0.35)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: CupertinoColors.white)),
    );
  }
}

/// Bottom sheet styled like an iOS card sheet.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) => showCupertinoModalPopup<T>(
  context: context,
  builder: (ctx) => Material(
    type: MaterialType.transparency,
    child: Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1917),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 5, decoration: BoxDecoration(color: MMColors.faint, borderRadius: BorderRadius.circular(3))),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
}) async {
  final r = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(padding: const EdgeInsets.only(top: 6), child: Text(message)),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        CupertinoDialogAction(isDestructiveAction: destructive, isDefaultAction: !destructive, onPressed: () => Navigator.pop(ctx, true), child: Text(confirm)),
      ],
    ),
  );
  return r ?? false;
}

/// Top banner toast.
void showToast(BuildContext context, String message, {bool error = false}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Toast(message: message, error: error, onDone: () => entry.remove()));
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
    overlay.insert(entry);
  } else {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (overlay.mounted) overlay.insert(entry);
    });
  }
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.error, required this.onDone});
  final String message;
  final bool error;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future<void>.delayed(const Duration(milliseconds: 2600), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + 8,
    left: 16,
    right: 16,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, -1.4), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassCard(
            color: const Color(0xD92B2623),
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  widget.error ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.checkmark_circle_fill,
                  color: widget.error ? MMColors.health : MMColors.stamina,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.message, style: MMText.body.copyWith(fontSize: 15))),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The app mark: pickaxe in a glowing rounded square.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: MMColors.accentGradient,
      borderRadius: BorderRadius.circular(size * 0.27),
      boxShadow: const [BoxShadow(color: Color(0x66FF7A1A), blurRadius: 30, offset: Offset(0, 10))],
    ),
    child: Icon(Icons.hardware_rounded, size: size * 0.55, color: CupertinoColors.white),
  );
}
