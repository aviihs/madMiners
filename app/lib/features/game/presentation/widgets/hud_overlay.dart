import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/session_event.dart';
import '../controller/game_controller.dart';
import '../controller/hud_state.dart';
import '../flame/components/miners_component.dart';
import 'shop_panel.dart';
import 'touch_controls.dart';

bool get _isTouchPlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Gameplay HUD (SRS §9.3): vitals, tool, backpack, timer, scoreboard,
/// connection status, depot shop and touch controls.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.controller, required this.onExit});
  final GameController controller;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HudState>(
      valueListenable: controller.hud,
      builder: (context, hud, _) {
        final me = hud.me;
        final wide = MediaQuery.sizeOf(context).width > 700;
        return SafeArea(
          child: Stack(
            children: [
              if (me != null) Positioned(left: 12, top: 12, child: _Vitals(me: me, deep: hud.deep)),
              Positioned(top: 12, left: 0, right: 0, child: Center(child: _TopBar(hud: hud, onExit: onExit))),
              if (wide || !_isTouchPlatform) Positioned(right: 12, top: 12, child: _Scoreboard(hud: hud)),
              Positioned(left: 12, bottom: _isTouchPlatform ? 170 : 12, child: _Feed(lines: hud.feed)),
              if (me != null && me.inDepot && me.alive)
                Positioned(right: 12, bottom: _isTouchPlatform ? 130 : 12, child: ShopPanel(me: me, onBuy: controller.buy)),
              if (me != null && !me.alive) _DeathBanner(seconds: me.respawnIn),
              if (hud.link != LinkStatus.connected) _LinkBanner(hud: hud, onExit: onExit),
              if (!hud.ready && hud.link == LinkStatus.connected) const Center(child: CircularProgressIndicator()),
              if (_isTouchPlatform) ...[
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: VirtualJoystick(onChanged: (x, y) {
                    controller.joyX = x;
                    controller.joyY = y;
                  }),
                ),
                Positioned(right: 28, bottom: 28, child: MineButton(onChanged: (v) => controller.mineHeld = v)),
              ] else
                const Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'WASD / Arrows move  ·  Space / J mine  ·  Sell & shop at the depot',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(10)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10)),
    child: child,
  );
}

class _Vitals extends StatelessWidget {
  const _Vitals({required this.me, required this.deep});
  final PlayerSnapshot me;
  final bool deep;

  @override
  Widget build(BuildContext context) {
    final pick = me.gear(UpgradeKind.pickaxe);
    final full = me.carried >= me.capacity;
    return _Panel(
      child: SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Bar(icon: Icons.favorite, value: me.hp / Balance.maxHealth, color: MMColors.health),
            _Bar(icon: Icons.bolt, value: me.stamina / Balance.maxStamina, color: MMColors.stamina),
            _Bar(
              icon: Icons.air,
              value: me.oxygen / me.maxOxygen,
              color: MMColors.oxygen,
              warn: deep && me.oxygen < me.maxOxygen * 0.3,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.hardware, size: 14, color: MMColors.muted),
                const SizedBox(width: 6),
                Text(pick.name, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.backpack, size: 14, color: full ? MMColors.ember : MMColors.muted),
                const SizedBox(width: 6),
                Text(
                  '${me.carried}/${me.capacity}',
                  style: TextStyle(fontSize: 12, color: full ? MMColors.ember : null, fontWeight: full ? FontWeight.w800 : null),
                ),
                const Spacer(),
                Text('${me.coins} ¢', style: const TextStyle(fontSize: 12, color: MMColors.amber, fontWeight: FontWeight.w700)),
              ],
            ),
            if (me.carried > 0) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (final o in OreType.values)
                    if (me.backpack[o.index] > 0)
                      Text('${oreDefs[o]!.name.split(' ').first} ×${me.backpack[o.index]}',
                          style: const TextStyle(fontSize: 10, color: MMColors.muted)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.icon, required this.value, required this.color, this.warn = false});
  final IconData icon;
  final double value;
  final Color color;
  final bool warn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 14, color: warn ? MMColors.health : color),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 8,
              color: color,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
      ],
    ),
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
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: t < 30 ? MMColors.health : MMColors.muted),
          const SizedBox(width: 4),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
          if (hud.teamScores.length == 2) ...[
            const SizedBox(width: 12),
            Text('${hud.teamScores[0]}', style: TextStyle(color: MMColors.teams[0], fontWeight: FontWeight.w800)),
            const Text('  vs  ', style: TextStyle(color: MMColors.muted)),
            Text('${hud.teamScores[1]}', style: TextStyle(color: MMColors.teams[1], fontWeight: FontWeight.w800)),
          ],
          const SizedBox(width: 12),
          Text(hud.roomCode, style: const TextStyle(color: MMColors.muted, fontSize: 12)),
          if (rtt != null && rtt > 0) ...[
            const SizedBox(width: 8),
            Icon(Icons.network_cell, size: 14, color: rtt < 100 ? MMColors.stamina : rtt < 200 ? MMColors.amber : MMColors.health),
            Text(' ${rtt}ms', style: const TextStyle(fontSize: 11, color: MMColors.muted)),
          ],
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onExit,
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Leave match',
          ),
        ],
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.hud});
  final HudState hud;

  @override
  Widget build(BuildContext context) => _Panel(
    child: SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hud.mode.label.toUpperCase(), style: const TextStyle(fontSize: 10, color: MMColors.muted, letterSpacing: 1)),
          const SizedBox(height: 4),
          for (final (i, s) in hud.scoreboard.take(12).indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  SizedBox(width: 18, child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: MMColors.muted))),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: MinersComponent.colorFor(s.id, s.team)),
                  ),
                  Expanded(
                    child: Text(
                      s.isBot ? '${s.name} 🤖' : s.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: s.isYou ? FontWeight.w800 : FontWeight.w400,
                        color: s.isYou ? MMColors.amber : (s.connected ? null : MMColors.muted),
                      ),
                    ),
                  ),
                  Text('${s.score}', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Feed extends StatelessWidget {
  const _Feed({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final l in lines)
          Text(
            l,
            style: const TextStyle(fontSize: 12, color: Colors.white70, shadows: [Shadow(blurRadius: 4)]),
          ),
      ],
    ),
  );
}

class _DeathBanner extends StatelessWidget {
  const _DeathBanner({required this.seconds});
  final double seconds;

  @override
  Widget build(BuildContext context) => Center(
    child: _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('YOU BLACKED OUT', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MMColors.health)),
          const SizedBox(height: 4),
          Text('Carried ore lost · respawning in ${seconds.ceil()}s', style: const TextStyle(color: MMColors.muted)),
        ],
      ),
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
      LinkStatus.connecting => 'Connecting to mine…',
      LinkStatus.reconnecting => 'Connection interrupted — reconnecting…',
      LinkStatus.lost => hud.linkMessage ?? 'Connection lost.',
      LinkStatus.connected => '',
    };
    return Center(
      child: _Panel(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!lost) const CircularProgressIndicator() else const Icon(Icons.wifi_off, size: 36, color: MMColors.health),
            const SizedBox(height: 12),
            Text(text),
            if (lost) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onExit, child: const Text('BACK TO LOBBY')),
            ],
          ],
        ),
      ),
    );
  }
}
