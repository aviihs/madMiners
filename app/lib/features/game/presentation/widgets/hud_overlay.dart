import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/di.dart';
import '../../../../app/settings.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../domain/entities/session_event.dart';
import '../controller/game_controller.dart';
import '../controller/hud_state.dart';
import 'minimap.dart';
import 'shop_panel.dart';
import 'touch_controls.dart';

bool get isTouchPlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Gameplay HUD (SRS §9.3): vitals, depth, tool, timer, standings,
/// connection status, depot shop, lobby countdown and touch controls.
class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key, required this.controller, required this.onExit});
  final GameController controller;
  final VoidCallback onExit;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  bool _showStandings = !isTouchPlatform;

  @override
  Widget build(BuildContext context) {
    // Never blur over the live game: it's the single most expensive thing
    // a HUD can do on Android. RepaintBoundary keeps HUD repaints (15/s)
    // separate from the game's 60 fps canvas.
    return GlassScope(blur: false, child: RepaintBoundary(child: _build(context)));
  }

  Widget _build(BuildContext context) {
    final c = widget.controller;
    return ValueListenableBuilder<HudState>(
      valueListenable: c.hud,
      builder: (context, hud, _) {
        final me = hud.me;
        final touch = isTouchPlatform;
        return DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyLarge!.merge(MMText.body),
          child: SafeArea(
            child: Stack(
              children: [
                if (hud.hint.level >= 2) Positioned.fill(child: _HintGlow(level: hud.hint.level)),
                if (me != null)
                  Positioned(left: 12, top: 10, child: _Vitals(me: me, depth: hud.depth, lavaDepth: hud.lavaDepth, hint: hud.hint)),
                Positioned(top: 10, left: 0, right: 0, child: Center(child: _TopBar(hud: hud, onExit: widget.onExit))),
                if (me != null) Positioned(right: 12, top: 10, child: MiniMap(controller: c, width: touch ? 112 : 132, height: touch ? 120 : 150)),
                if (hud.worldEvent != null)
                  Positioned(
                    top: (touch ? 54 : 60) + (hud.hint.level >= 1 ? 50 : 0),
                    left: 0,
                    right: 0,
                    child: Center(child: _EventChip(kind: hud.worldEvent!, left: hud.worldEventLeft)),
                  ),
                if (hud.banner != null) Positioned(top: 0, bottom: 0, left: 0, right: 0, child: IgnorePointer(child: Center(child: _BannerView(banner: hud.banner!)))),
                Positioned(
                  // Phones: left of the mini-map (clear of the bomb buttons). Desktop: under it.
                  right: me != null && touch ? 132 : 12,
                  top: me != null && !touch ? 168 : 10,
                  child: _showStandings
                      ? _Standings(hud: hud, onClose: () => setState(() => _showStandings = false))
                      : _RoundButton(icon: CupertinoIcons.list_number, onTap: () => setState(() => _showStandings = true)),
                ),
                if (touch)
                  Positioned(
                    top: 58,
                    left: 0,
                    right: 0,
                    child: Center(child: _Feed(lines: hud.feed.skip(hud.feed.length > 2 ? hud.feed.length - 2 : 0).toList(), centered: true)),
                  )
                else
                  Positioned(left: 12, top: me == null ? 10 : 196, child: _Feed(lines: hud.feed)),
                if (me != null && me.inDepot && me.alive && hud.warmup <= 0)
                  Positioned(
                    // Phones: left of the jump / jetpack / dig buttons, never on top of them.
                    right: touch ? 212 : 12,
                    bottom: touch ? 12 : 44,
                    child: ShopPanel(me: me, onUpgrade: c.buy, onBuyItem: c.buyItem),
                  ),
                if (me != null && me.alive && hud.warmup <= 0 && !me.inDepot)
                  if (touch)
                    _ActionSide(bottom: 140, inset: 30, child: _ItemBar(me: me, onUse: c.useItem, vertical: true))
                  else
                    Positioned(right: 12, bottom: 44, child: _ItemBar(me: me, onUse: c.useItem, vertical: false)),
                if (hud.warmup > 0 && hud.link == LinkStatus.connected)
                  Positioned(top: touch ? 54 : 60, left: 0, right: 0, child: Center(child: _Lobby(hud: hud))),
                if (me != null && me.alive && hud.hint.level >= 1 && hud.warmup <= 0)
                  Positioned(top: touch ? 54 : 60, left: 0, right: 0, child: Center(child: _TreasureCompass(hint: hud.hint, depth: hud.depth, lavaDepth: hud.lavaDepth))),
                if (me != null && !me.alive) Center(child: _DeathBanner(seconds: me.respawnIn, cause: hud.deathCause, lost: hud.deathLost)),
                if (hud.link != LinkStatus.connected) Center(child: _LinkBanner(hud: hud, onExit: widget.onExit)),
                if (!hud.ready && hud.link == LinkStatus.connected) const Center(child: CupertinoActivityIndicator(radius: 14)),
                if (touch) ...[
                  Positioned.fill(child: _TouchControls(controller: c)),
                ] else
                  const Positioned(bottom: 14, left: 0, right: 0, child: Center(child: _KeyHints())),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 22,
    padding: const EdgeInsets.all(10),
    color: const Color(0x66000000),
    onTap: onTap,
    child: Icon(icon, size: 20, color: MMColors.text),
  );
}

class _Vitals extends StatelessWidget {
  const _Vitals({required this.me, required this.depth, required this.lavaDepth, required this.hint});
  final PlayerSnapshot me;
  final int depth;
  final int lavaDepth;
  final TreasureHint hint;

  @override
  Widget build(BuildContext context) {
    final progress = lavaDepth <= 0 ? 0.0 : (depth / lavaDepth).clamp(0.0, 1.0);
    final nearLava = progress > 0.85;
    return GlassCard(
      radius: 18,
      color: const Color(0x66000000),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SizedBox(
        width: 176,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Bar(icon: CupertinoIcons.heart_fill, value: me.hp / Balance.maxHealth, color: MMColors.health),
            const SizedBox(height: 6),
            _Bar(icon: CupertinoIcons.bolt_fill, value: me.stamina / Balance.maxStamina, color: MMColors.stamina),
            const SizedBox(height: 6),
            _Bar(icon: CupertinoIcons.rocket_fill, value: me.fuel / Balance.jetFuelMax, color: MMColors.sky),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(CupertinoIcons.arrow_down, size: 13, color: nearLava ? MMColors.ember : MMColors.muted),
                const SizedBox(width: 5),
                Text('${depth}m', style: MMText.headline.copyWith(fontSize: 15).merge(MMText.number)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nearLava ? 'Lava close!' : Zone.at(lavaDepth <= 0 ? 0 : depth / lavaDepth).label,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MMText.caption.copyWith(color: nearLava ? MMColors.ember : MMColors.gold, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _Track(value: progress, gradient: const LinearGradient(colors: [MMColors.amber, MMColors.ember])),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(CupertinoIcons.hammer_fill, size: 13, color: MMColors.muted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    me.gear(UpgradeKind.pickaxe).name,
                    style: MMText.caption.copyWith(color: MMColors.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CurrencyPill(me.coins),
              ],
            ),
            const SizedBox(height: 8),
            _SenseRow(hint: hint),
          ],
        ),
      ),
    );
  }
}

/// Vague treasure sense: never says exactly where.
class _SenseRow extends StatelessWidget {
  const _SenseRow({required this.hint});
  final TreasureHint hint;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (hint.level) {
      0 => ('No treasure sense', MMColors.faint),
      1 => ('Faint glimmer below…', MMColors.muted),
      2 => (
        switch (hint.side) {
          -1 => 'Warmer · somewhere left',
          1 => 'Warmer · somewhere right',
          _ => 'Warmer · keep digging',
        },
        MMColors.amber,
      ),
      _ => ('HOT! It\'s right here', MMColors.gold),
    };
    return Row(
      children: [
        for (var i = 1; i <= 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              CupertinoIcons.sparkles,
              size: 13,
              color: hint.level >= i ? (hint.level == 3 ? MMColors.gold : MMColors.amber) : const Color(0x33FFFFFF),
            ),
          ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: MMText.caption.copyWith(color: color, fontWeight: hint.level >= 2 ? FontWeight.w700 : null)),
        ),
      ],
    );
  }
}

/// Golden glow around the screen edge when the treasure is close.
class _HintGlow extends StatefulWidget {
  const _HintGlow({required this.level});
  final int level;

  @override
  State<_HintGlow> createState() => _HintGlowState();
}

class _HintGlowState extends State<_HintGlow> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final a = (widget.level == 3 ? 0.35 : 0.16) * (0.6 + 0.4 * _c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.05,
              colors: [const Color(0x00FFD34D), const Color(0x00FFD34D), const Color(0xFFFFD34D).withValues(alpha: a)],
              stops: const [0, 0.7, 1],
            ),
          ),
        );
      },
    ),
  );
}

class _ItemBar extends StatelessWidget {
  const _ItemBar({required this.me, required this.onUse, required this.vertical});
  final PlayerSnapshot me;
  final ValueChanged<ItemKind> onUse;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      for (final k in ItemKind.values)
        Padding(
          padding: EdgeInsets.only(top: vertical ? 8 : 0, left: vertical ? 0 : 8),
          child: _ItemButton(
            icon: k == ItemKind.bomb ? CupertinoIcons.burst_fill : CupertinoIcons.flame_fill,
            count: me.itemCount(k),
            hotkey: vertical ? null : (k == ItemKind.bomb ? 'B' : 'N'),
            onTap: () => onUse(k),
          ),
        ),
    ];
    return vertical ? Column(mainAxisSize: MainAxisSize.min, children: buttons) : Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}

class _ItemButton extends StatelessWidget {
  const _ItemButton({required this.icon, required this.count, required this.onTap, this.hotkey});
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final String? hotkey;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: count > 0 ? 1 : 0.4,
    child: GlassCard(
      radius: 26,
      color: const Color(0x80000000),
      padding: EdgeInsets.zero,
      onTap: count > 0 ? onTap : null,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 24, color: MMColors.ember),
            Positioned(
              right: 6,
              bottom: 5,
              child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MMColors.text)),
            ),
            if (hotkey != null)
              Positioned(left: 7, top: 5, child: Text(hotkey!, style: const TextStyle(fontSize: 10, color: MMColors.muted, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    ),
  );
}

class _Track extends StatelessWidget {
  const _Track({required this.value, this.gradient, this.color});
  final double value;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(
      height: 6,
      child: Stack(
        children: [
          Container(color: const Color(0x22FFFFFF)),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 250),
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(decoration: BoxDecoration(gradient: gradient, color: color)),
          ),
        ],
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.icon, required this.value, required this.color});
  final IconData icon;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 7),
      Expanded(child: _Track(value: value, color: color)),
    ],
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.hud, required this.onExit});
  final HudState hud;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final t = hud.timeLeft.ceil();
    final time = '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
    final rtt = hud.rttMs;
    final pingColor = rtt == null || rtt <= 0 ? null : (rtt < 100 ? MMColors.stamina : rtt < 200 ? MMColors.amber : MMColors.health);
    final urgent = t < 30 && hud.warmup <= 0;
    return GlassCard(
      radius: 22,
      color: const Color(0x66000000),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.timer, size: 15, color: urgent ? MMColors.health : MMColors.muted),
          const SizedBox(width: 5),
          Text(time, style: MMText.headline.copyWith(color: urgent ? MMColors.health : null).merge(MMText.number)),
          if (hud.teamScores.length == 2) ...[
            const SizedBox(width: 12),
            Text('${hud.teamScores[0]}', style: MMText.headline.copyWith(color: MMColors.teams[0]).merge(MMText.number)),
            const Text(' : ', style: MMText.footnote),
            Text('${hud.teamScores[1]}', style: MMText.headline.copyWith(color: MMColors.teams[1]).merge(MMText.number)),
          ],
          if (pingColor != null) ...[
            const SizedBox(width: 12),
            Container(width: 7, height: 7, decoration: BoxDecoration(color: pingColor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('${rtt}ms', style: MMText.caption.merge(MMText.number)),
          ],
          const SizedBox(width: 6),
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minimumSize: const Size(30, 30),
            onPressed: onExit,
            child: const Icon(CupertinoIcons.xmark_circle_fill, size: 24, color: MMColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Standings extends StatelessWidget {
  const _Standings({required this.hud, required this.onClose});
  final HudState hud;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final lines = hud.scoreboard;
    final youIdx = lines.indexWhere((l) => l.isYou);
    final shown = lines.take(6).toList();
    return GlassCard(
      radius: 18,
      color: const Color(0x66000000),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 10),
      child: SizedBox(
        width: 178,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('DEEPEST', style: MMText.section),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(26, 26),
                  onPressed: onClose,
                  child: const Icon(CupertinoIcons.chevron_up, size: 14, color: MMColors.muted),
                ),
              ],
            ),
            for (final (i, s) in shown.indexed) _line(i + 1, s),
            if (youIdx >= shown.length) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Text('···', style: MMText.caption)),
              _line(youIdx + 1, lines[youIdx]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(int rank, ScoreLine s) => Padding(
    padding: const EdgeInsets.only(top: 5, right: 6),
    child: Row(
      children: [
        SizedBox(width: 16, child: Text('$rank', style: MMText.caption.merge(MMText.number))),
        Avatar(s.name, size: 18, color: s.team >= 0 ? MMColors.teams[s.team] : null),
        const SizedBox(width: 6),
        if (s.isBot) ...[const Pill('BOT', color: MMColors.sky), const SizedBox(width: 4)],
        Expanded(
          child: Text(
            s.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: s.isYou ? FontWeight.w700 : FontWeight.w500,
              color: s.isYou ? MMColors.amber : (s.connected ? MMColors.text : MMColors.faint),
            ),
          ),
        ),
        Text('${s.depth}m', style: MMText.caption.copyWith(color: MMColors.text).merge(MMText.number)),
      ],
    ),
  );
}

class _Feed extends StatelessWidget {
  const _Feed({required this.lines, this.centered = false});
  final List<String> lines;
  final bool centered;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, l) in lines.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Opacity(
              opacity: 0.45 + 0.55 * (i + 1) / lines.length,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(10)),
                child: Text(l, style: const TextStyle(fontSize: 13, color: MMColors.text)),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Pre-match lobby: miners trickle in, then 3‑2‑1.
/// Pre-match lobby strip: sits under the timer (never over the miners),
/// one compact row, and shrinks to fit any screen, so it can't overflow.
class _Lobby extends StatelessWidget {
  const _Lobby({required this.hud});
  final HudState hud;

  @override
  Widget build(BuildContext context) {
    final count = hud.scoreboard.length;
    final countdown = hud.warmup <= 3.2;
    final maxW = (MediaQuery.sizeOf(context).width - 32).clamp(200.0, 460.0);
    const shown = 7;
    final people = hud.scoreboard.take(shown).toList();
    final extra = count - people.length;
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: 96),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: GlassCard(
            radius: 20,
            color: const Color(0xB3000000),
            padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Center(
                    child: countdown
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: Text(
                              '${hud.warmup.ceil()}',
                              key: ValueKey(hud.warmup.ceil()),
                              style: MMText.number.copyWith(fontSize: 44, color: MMColors.amber, height: 1),
                            ),
                          )
                        : const CupertinoActivityIndicator(radius: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(countdown ? 'Get ready to dig!' : 'Finding miners…', style: MMText.headline.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text('$count / ${hud.lobbyTarget} miners · ${hud.mapName}', style: MMText.caption),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in people)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: s.isYou ? MMColors.amber : const Color(0x00000000), width: 2),
                                  ),
                                  child: Avatar(s.isYou ? 'You' : s.name, size: 22, color: s.team >= 0 ? MMColors.teams[s.team] : null),
                                ),
                                if (s.isBot)
                                  Positioned(
                                    right: -3,
                                    bottom: -3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(color: MMColors.sky, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('BOT', style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w900, color: Color(0xFF0C1A2E))),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (extra > 0) Text('+$extra', style: MMText.caption.copyWith(color: MMColors.text)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold treasure compass: real direction, distance, signal strength and
/// the zone the treasure is in. Only shown once you've picked up the signal.
class _TreasureCompass extends StatelessWidget {
  const _TreasureCompass({required this.hint, required this.depth, required this.lavaDepth});
  final TreasureHint hint;
  final int depth;
  final int lavaDepth;

  @override
  Widget build(BuildContext context) {
    final rad = hint.angle * pi / 180;
    final treasureDepth = depth + (hint.distance * sin(rad)).round();
    final zone = Zone.at(lavaDepth <= 0 ? 1 : (treasureDepth / lavaDepth).clamp(0.0, 1.0)).label;
    return IgnorePointer(
      child: GlassCard(
        radius: 18,
        color: const Color(0xB3000000),
        borderColor: MMColors.gold.withValues(alpha: 0.7),
        padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: MMColors.gold.withValues(alpha: 0.18), border: Border.all(color: MMColors.gold)),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: rad),
                duration: const Duration(milliseconds: 300),
                builder: (_, a, child) => Transform.rotate(angle: a, child: child),
                child: const Icon(CupertinoIcons.arrow_right, color: MMColors.gold, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${hint.distance} m', style: MMText.number.copyWith(fontSize: 17, color: MMColors.gold)),
                    const SizedBox(width: 8),
                    for (var i = 1; i <= 3; i++)
                      Container(
                        width: 4,
                        height: 5.0 + i * 3,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: hint.level >= i ? MMColors.gold : const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                  ],
                ),
                Text('Treasure · $zone', style: MMText.caption.copyWith(fontSize: 10.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeathBanner extends StatelessWidget {
  const _DeathBanner({required this.seconds, this.cause, this.lost = 0});
  final double seconds;
  final String? cause;
  final int lost;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (cause) {
      'lava' || 'a volcano' => (CupertinoIcons.flame_fill, 'Burned!'),
      'a long fall' || 'a crash into the rock' => (CupertinoIcons.arrow_down_circle_fill, 'Splat!'),
      'a falling boulder' => (CupertinoIcons.cube_fill, 'Crushed!'),
      'spikes' => (CupertinoIcons.exclamationmark_triangle_fill, 'Spiked!'),
      'toxic gas' => (CupertinoIcons.cloud_fill, 'Poisoned!'),
      final c? when c.contains('TNT') || c.contains('bomb') || c.contains('dynamite') => (CupertinoIcons.burst_fill, 'Blown up!'),
      final c? when c.contains('Spider') || c.contains('Golem') => (CupertinoIcons.ant_fill, 'Mauled!'),
      _ => (CupertinoIcons.xmark_octagon_fill, 'Knocked out!'),
    };
    return GlassCard(
      radius: 22,
      color: const Color(0xB3000000),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: MMColors.ember, size: 34),
          const SizedBox(height: 8),
          Text(title, style: MMText.title),
          if (cause != null) ...[
            const SizedBox(height: 2),
            Text('Killed by $cause', style: MMText.callout.copyWith(color: MMColors.text)),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 14),
              const SizedBox(width: 4),
              Text(lost > 0 ? 'Dropped $lost coins' : 'No coins lost', style: MMText.footnote),
            ],
          ),
          const SizedBox(height: 2),
          Text('Your gear is safe. Respawning at the surface in ${seconds.ceil()}s', style: MMText.caption),
        ],
      ),
    );
  }
}

class _LinkBanner extends StatelessWidget {
  const _LinkBanner({required this.hud, required this.onExit});
  final HudState hud;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final lost = hud.link == LinkStatus.lost;
    final text = switch (hud.link) {
      LinkStatus.connecting => 'Joining match…',
      LinkStatus.reconnecting => 'Connection lost. Reconnecting…',
      LinkStatus.lost => hud.linkMessage ?? 'Connection lost.',
      LinkStatus.connected => '',
    };
    return GlassCard(
      radius: 22,
      color: const Color(0xB3000000),
      padding: const EdgeInsets.all(22),
      child: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lost)
              const Icon(CupertinoIcons.wifi_exclamationmark, size: 36, color: MMColors.health)
            else
              const CupertinoActivityIndicator(radius: 14),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: MMText.headline),
            if (lost) ...[
              const SizedBox(height: 16),
              PrimaryButton(label: 'Back to Lobby', onPressed: onExit),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyHints extends StatelessWidget {
  const _KeyHints();

  @override
  Widget build(BuildContext context) {
    Widget key(String k) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: const Color(0x44FFFFFF)), borderRadius: BorderRadius.circular(5)),
      child: Text(k, style: const TextStyle(fontSize: 11, color: Color(0xAAFFFFFF), fontWeight: FontWeight.w600)),
    );
    const label = TextStyle(fontSize: 12, color: Color(0x88FFFFFF));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        key('A'), key('D'),
        const Text('  run   ', style: label),
        key('W'),
        const Text('  jump / climb   ', style: label),
        key('SHIFT'),
        const Text('  jetpack   ', style: label),
        key('S'),
        const Text('  aim down   ', style: label),
        key('SPACE'),
        const Text('  dig   ', style: label),
        key('B'),
        const Text(' throw bomb  ', style: label),
        key('N'),
        const Text(' dynamite     ', style: label),
        const Text('Beware hidden volcanoes!', style: label),
      ],
    );
  }
}

/// Positions [child] on the action-button side (right, or left when the
/// player picked left-handed controls), scaled by the control-size setting.
class _ActionSide extends StatelessWidget {
  const _ActionSide({required this.bottom, required this.inset, required this.child});
  final double bottom;
  final double inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final st = sl<GameSettings>();
    return ListenableBuilder(
      listenable: Listenable.merge([st.controlScale, st.leftHanded]),
      builder: (context, _) {
        final left = st.leftHanded.value;
        final k = st.controlScale.value;
        return Positioned(
          left: left ? inset : null,
          right: left ? null : inset,
          bottom: bottom * k,
          child: Transform.scale(scale: k, alignment: left ? Alignment.bottomLeft : Alignment.bottomRight, child: child),
        );
      },
    );
  }
}

/// Joystick on one side; dig, jump and jetpack on the other. Size and side
/// come from Settings. Every control is its own pointer target, so they all
/// work at once (multi-touch).
class _TouchControls extends StatelessWidget {
  const _TouchControls({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final st = sl<GameSettings>();
    final c = controller;
    return ListenableBuilder(
      listenable: Listenable.merge([st.controlScale, st.leftHanded]),
      builder: (context, _) {
        final k = st.controlScale.value;
        final swap = st.leftHanded.value;
        Widget at({required double side, required double bottom, required bool action, required Widget child}) {
          final onLeft = action == swap;
          return Positioned(
            left: onLeft ? side * k : null,
            right: onLeft ? null : side * k,
            bottom: bottom * k,
            child: Transform.scale(scale: k, alignment: onLeft ? Alignment.bottomLeft : Alignment.bottomRight, child: child),
          );
        }

        return Stack(
          children: [
            at(
              side: 28,
              bottom: 28,
              action: false,
              child: VirtualJoystick(onChanged: (x, y) {
                c.joyX = x;
                c.joyY = y;
              }),
            ),
            at(side: 32, bottom: 32, action: true, child: MineButton(onChanged: (v) => c.mineHeld = v)),
            at(side: 134, bottom: 24, action: true, child: JumpButton(onChanged: (v) => c.jumpHeld = v)),
            at(
              side: 134,
              bottom: 100,
              action: true,
              child: JumpButton(icon: CupertinoIcons.rocket_fill, size: 58, onChanged: (v) => c.jetHeld = v),
            ),
          ],
        );
      },
    );
  }
}

/// Big centre-screen headline that pops in and fades.
class _BannerView extends StatelessWidget {
  const _BannerView({required this.banner});
  final HudBanner banner;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(banner.id),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutBack,
    builder: (context, v, child) => Transform.scale(scale: 0.6 + 0.4 * v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xCC0C0A09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(banner.color), width: 2),
        boxShadow: [BoxShadow(color: Color(banner.color).withValues(alpha: 0.45), blurRadius: 28)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(banner.title, textAlign: TextAlign.center, style: MMText.title.copyWith(color: Color(banner.color), fontSize: 26)),
          const SizedBox(height: 4),
          Text(banner.subtitle, textAlign: TextAlign.center, style: MMText.callout.copyWith(color: MMColors.text)),
        ],
      ),
    ),
  );
}

/// Active world event with its countdown.
class _EventChip extends StatelessWidget {
  const _EventChip({required this.kind, required this.left});
  final WorldEventKind kind;
  final double left;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      WorldEventKind.goldRush || WorldEventKind.rareOreSurge || WorldEventKind.hiddenTreasure => MMColors.gold,
      WorldEventKind.earthquake || WorldEventKind.caveCollapse || WorldEventKind.lavaBreakthrough || WorldEventKind.tntChain => MMColors.lava,
      WorldEventKind.mysteryRain => MMColors.violet,
      WorldEventKind.monsterInvasion => MMColors.health,
    };
    return GlassCard(
      radius: 16,
      color: const Color(0x99000000),
      borderColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.bolt_circle_fill, size: 16, color: color),
          const SizedBox(width: 6),
          Text(kind.label, style: MMText.headline.copyWith(fontSize: 13, color: color)),
          const SizedBox(width: 8),
          Text('${left.ceil()}s', style: MMText.number.copyWith(fontSize: 13, color: MMColors.text)),
        ],
      ),
    );
  }
}
