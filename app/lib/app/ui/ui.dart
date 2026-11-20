import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Material, MaterialType;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

export 'currency.dart';

/// Shared game-style UI kit. Screens compose these instead of styling raw
/// widgets, so the whole app speaks one visual language.

// ---------------------------------------------------------------------------
// Backdrop
// ---------------------------------------------------------------------------

/// Deep cave backdrop: indigo gradient, soft gold/violet glows, rock
/// silhouettes along the bottom and floating dust.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [MMColors.bgTop, MMColors.bg, Color(0xFF0C0916)],
        stops: [0, 0.5, 1],
      ),
    ),
    child: CustomPaint(painter: _CavePainter(), child: child),
  );
}

class _CavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    // Glows.
    p.shader =
        RadialGradient(
          colors: [
            MMColors.gold.withValues(alpha: 0.16),
            MMColors.gold.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.15, size.height * 0.08),
            radius: size.width * 0.8,
          ),
        );
    canvas.drawRect(Offset.zero & size, p);
    p.shader =
        RadialGradient(
          colors: [
            MMColors.violet.withValues(alpha: 0.18),
            MMColors.violet.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 1.0, size.height * 0.55),
            radius: size.width * 0.75,
          ),
        );
    canvas.drawRect(Offset.zero & size, p);
    p.shader = null;

    // Rock silhouettes.
    final rng = Random(11);
    final ground = Path()..moveTo(0, size.height);
    var x = 0.0;
    while (x < size.width + 40) {
      ground.lineTo(x, size.height - 40 - rng.nextDouble() * 70);
      x += 30 + rng.nextDouble() * 50;
    }
    ground
      ..lineTo(size.width, size.height)
      ..close();
    p.color = const Color(0x40000000);
    canvas.drawPath(ground, p);

    // Dust.
    for (var i = 0; i < 70; i++) {
      final gold = i % 5 == 0;
      p.color = gold
          ? MMColors.gold.withValues(alpha: 0.35)
          : const Color(0x14FFFFFF);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        gold ? 1.4 : 1 + rng.nextDouble(),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// Raised panel. Solid by default; pass a translucent [color] for HUD use
/// over the game (then it blurs what's behind).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
    this.gradient,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final translucent = color != null && color!.a < 1;
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        gradient: color == null ? (gradient ?? MMColors.cardGradient) : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? MMColors.hairline, width: 1),
        boxShadow: translucent
            ? null
            : const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (translucent) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: card,
        ),
      );
    }
    return onTap == null ? card : PressableScale(onTap: onTap!, child: card);
  }
}

/// Subtle press feedback.
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
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

enum ButtonTone { gold, dark, gem, lava, light }

/// Chunky mobile-game button with a solid "lip" that sinks when pressed.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.tone = ButtonTone.gold,
    this.loading = false,
    this.height = 56,
    this.fontSize = 19,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final ButtonTone tone;
  final bool loading;
  final double height;
  final double fontSize;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  (List<Color>, Color, Color) get _colors => switch (widget.tone) {
    ButtonTone.gold => (
      const [MMColors.goldLight, MMColors.gold],
      MMColors.goldDeep,
      MMColors.onGold,
    ),
    ButtonTone.dark => (
      const [Color(0xFF3A2F5C), Color(0xFF2B2246)],
      const Color(0xFF15102A),
      MMColors.text,
    ),
    ButtonTone.gem => (
      const [Color(0xFF6FF2DF), MMColors.gem],
      MMColors.gemDeep,
      const Color(0xFF053B34),
    ),
    ButtonTone.lava => (
      const [Color(0xFFFF8A63), MMColors.lava],
      const Color(0xFFB23A12),
      CupertinoColors.white,
    ),
    ButtonTone.light => (
      const [CupertinoColors.white, Color(0xFFECE8F5)],
      const Color(0xFFB9B2CF),
      const Color(0xFF1F1A2E),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final (faces, lip, ink) = _colors;
    const lipH = 5.0;
    final pressed = _down && enabled;
    return Opacity(
      opacity: enabled || widget.loading ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              Positioned.fill(
                top: lipH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: lip,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: pressed ? lipH : 0,
                bottom: pressed ? 0 : lipH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: faces,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0x33FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: widget.loading
                        ? CupertinoActivityIndicator(color: ink)
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.leading != null) ...[
                                  widget.leading!,
                                  const SizedBox(width: 10),
                                ],
                                if (widget.icon != null) ...[
                                  Icon(
                                    widget.icon,
                                    size: widget.fontSize + 1,
                                    color: ink,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.label.toUpperCase(),
                                      maxLines: 1,
                                      style: MMText.button.copyWith(
                                        color: ink,
                                        fontSize: widget.fontSize,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back-compat names.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => GameButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    loading: loading,
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GameButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    tone: ButtonTone.dark,
    height: 52,
    fontSize: 17,
  );
}

/// Small round icon button for nav bars and HUD.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.color = MMColors.text,
    this.badge,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MMColors.surfaceHi,
        shape: BoxShape.circle,
        border: Border.all(color: MMColors.hairline),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    ),
  );
}

// ---------------------------------------------------------------------------
// Inputs & text
// ---------------------------------------------------------------------------

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
    style: MMText.body.copyWith(fontSize: 16),
    placeholderStyle: MMText.body.copyWith(fontSize: 16, color: MMColors.faint),
    cursorColor: MMColors.gold,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    prefix: icon == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(icon, size: 20, color: MMColors.muted),
          ),
    decoration: BoxDecoration(
      color: MMColors.surfaceLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: MMColors.hairline, width: 1.2),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
    child: Row(
      children: [
        Text(text.toUpperCase(), style: MMText.section),
        const Spacer(),
        ?trailing,
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Lists
// ---------------------------------------------------------------------------

class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: EdgeInsets.zero,
    radius: 20,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 66),
              child: Container(height: 1, color: MMColors.hairline),
            ),
        ],
      ],
    ),
  );
}

class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.highlight = false,
  });
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      color: highlight ? MMColors.gold.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 40, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MMText.headline.copyWith(
                    color: highlight ? MMColors.gold : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: MMText.footnote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: MMColors.faint,
            ),
          ],
        ],
      ),
    );
    return onTap == null ? row : PressableScale(onTap: onTap!, child: row);
  }
}

/// Rounded-square icon with a tinted fill.
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.color = MMColors.gold,
    this.size = 36,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.14)],
      ),
      borderRadius: BorderRadius.circular(size * 0.3),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Icon(icon, size: size * 0.55, color: color),
  );
}

/// Small status chip.
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.color = MMColors.muted,
    this.icon,
    this.leading,
  });
  final String text;
  final Color color;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 5)],
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            fontFamily: MMFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

/// Initials avatar with a stable per-name colour (used where no miner art).
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
    final initials = letters.isEmpty
        ? '?'
        : letters.substring(0, min(2, letters.length)).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [c, Color.lerp(c, const Color(0xFF000000), 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: MMFonts.display,
          fontSize: size * 0.4,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}

/// The app mark.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [MMColors.goldLight, MMColors.gold, Color(0xFFFF8A1F)],
      ),
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: const Color(0x66FFFFFF), width: 2),
      boxShadow: [
        BoxShadow(
          color: MMColors.gold.withValues(alpha: 0.45),
          blurRadius: 36,
          offset: const Offset(0, 12),
        ),
        const BoxShadow(color: MMColors.goldDeep, offset: Offset(0, 6)),
      ],
    ),
    child: Icon(
      Icons.hardware_rounded,
      size: size * 0.56,
      color: MMColors.onGold,
    ),
  );
}

/// Segmented control styled for the app.
class AppSegmented<T extends Object> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => CupertinoSlidingSegmentedControl<T>(
    groupValue: value,
    thumbColor: MMColors.gold,
    backgroundColor: MMColors.surfaceLow,
    padding: const EdgeInsets.all(4),
    children: {
      for (final e in items.entries)
        e.key: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            e.value,
            style: TextStyle(
              fontFamily: MMFonts.display,
              fontSize: 15,
              letterSpacing: 0.5,
              color: e.key == value ? MMColors.onGold : MMColors.muted,
            ),
          ),
        ),
    },
    onValueChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A2145), MMColors.surface],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: MMColors.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: MMColors.faint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
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
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: MMFonts.display,
          fontSize: 20,
          letterSpacing: 0.3,
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: MMFonts.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Top banner toast. Safe to call at any time (even during a build).
void showToast(BuildContext context, String message, {bool error = false}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) =>
        _Toast(message: message, error: error, onDone: () => entry.remove()),
  );
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.idle ||
      phase == SchedulerPhase.postFrameCallbacks) {
    overlay.insert(entry);
  } else {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (overlay.mounted) overlay.insert(entry);
    });
  }
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.error,
    required this.onDone,
  });
  final String message;
  final bool error;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

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
  Widget build(BuildContext context) {
    final accent = widget.error ? MMColors.lava : MMColors.leaf;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              decoration: BoxDecoration(
                color: MMColors.surfaceHi,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accent.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.error
                          ? CupertinoIcons.exclamationmark
                          : CupertinoIcons.checkmark_alt,
                      color: accent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: MMText.body.copyWith(
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
