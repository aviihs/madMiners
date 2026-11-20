import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../domain/entities/session_event.dart';
import '../controller/game_controller.dart';
import '../controller/hud_state.dart';
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
                Positioned(
                  right: 12,
                  top: 10,
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
                    right: touch ? 140 : 12,
                    bottom: touch ? 20 : 44,
                    child: ShopPanel(me: me, onUpgrade: c.buy, onBuyItem: c.buyItem),
                  ),
                if (me != null && me.alive && hud.warmup <= 0 && !me.inDepot)
                  Positioned(
                    right: touch ? 30 : 12,
                    bottom: touch ? 136 : 44,
                    child: _ItemBar(me: me, onUse: c.useItem, vertical: touch),
                  ),
                if (hud.warmup > 0 && hud.link == LinkStatus.connected) Center(child: _Lobby(hud: hud)),
                if (me != null && !me.alive) Center(child: _DeathBanner(seconds: me.respawnIn)),
                if (hud.link != LinkStatus.connected) Center(child: _LinkBanner(hud: hud, onExit: widget.onExit)),
                if (!hud.ready && hud.link == LinkStatus.connected) const Center(child: CupertinoActivityIndicator(radius: 14)),
                if (touch) ...[
                  Positioned(
                    left: 28,
                    bottom: 28,
                    child: VirtualJoystick(onChanged: (x, y) {
                      c.joyX = x;
                      c.joyY = y;
                    }),
                  ),
                  Positioned(right: 32, bottom: 32, child: MineButton(onChanged: (v) => c.mineHeld = v)),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(CupertinoIcons.arrow_down, size: 13, color: nearLava ? MMColors.ember : MMColors.muted),
                const SizedBox(width: 5),
                Text('${depth}m', style: MMText.headline.copyWith(fontSize: 15).merge(MMText.number)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nearLava ? 'Lava close!' : 'lava at ${lavaDepth}m',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MMText.caption.copyWith(color: nearLava ? MMColors.ember : MMColors.muted, fontWeight: nearLava ? FontWeight.w600 : null),
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
class _Lobby extends StatelessWidget {
  const _Lobby({required this.hud});
  final HudState hud;

  @override
  Widget build(BuildContext context) {
    final count = hud.scoreboard.length;
    final countdown = hud.warmup <= 3.2;
    return IgnorePointer(
      child: GlassCard(
        radius: 24,
        color: const Color(0x99000000),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (countdown) ...[
                const Text('Get ready to dig', style: MMText.callout),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text(
                    '${hud.warmup.ceil()}',
                    key: ValueKey(hud.warmup.ceil()),
                    style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: MMColors.amber, height: 1.05),
                  ),
                ),
              ] else ...[
                const CupertinoActivityIndicator(radius: 12),
                const SizedBox(height: 12),
                const Text('Finding miners…', style: MMText.title),
                const SizedBox(height: 4),
                Text('$count / ${hud.lobbyTarget} joined · ${hud.mapName}', style: MMText.footnote),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in hud.scoreboard)
                    Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                      decoration: BoxDecoration(
                        color: s.isYou ? MMColors.amber.withValues(alpha: 0.2) : MMColors.glassStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Avatar(s.name, size: 20, color: s.team >= 0 ? MMColors.teams[s.team] : null),
                          const SizedBox(width: 6),
                          Text(s.isYou ? 'You' : s.name, style: const TextStyle(fontSize: 12, color: MMColors.text)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeathBanner extends StatelessWidget {
  const _DeathBanner({required this.seconds});
  final double seconds;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 22,
    color: const Color(0x99000000),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.flame_fill, color: MMColors.ember, size: 34),
        const SizedBox(height: 8),
        const Text('Burned!', style: MMText.title),
        const SizedBox(height: 2),
        Text('Back to the surface in ${seconds.ceil()}s', style: MMText.footnote),
      ],
    ),
  );
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
        key('W'), key('A'), key('S'), key('D'),
        const Text('  move     ', style: label),
        key('SPACE'),
        const Text('  dig     ', style: label),
        key('B'),
        const Text(' bomb  ', style: label),
        key('N'),
        const Text(' dynamite     ', style: label),
        const Text('Beware hidden volcanoes!', style: label),
      ],
    );
  }
}
