import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/audio.dart';
import '../../domain/entities/session_event.dart';
import '../../domain/repositories/game_session_repository.dart';
import '../flame/palette.dart';
import 'hud_state.dart';

/// A miner as drawn on screen (smoothed toward the latest server state).
class RenderMiner {
  RenderMiner(this.snap) : rx = snap.x, ry = snap.y;
  PlayerSnapshot snap;
  double rx;
  double ry;
  double swing = 0; // pickaxe animation phase
}

enum FxKind { text, chips, burst, shake }

/// Short-lived visual effect requested by gameplay events.
class FxRequest {
  const FxRequest(this.x, this.y, this.text, this.color, {this.kind = FxKind.text, this.amount = 1});
  const FxRequest.chips(this.x, this.y, this.color, {this.amount = 1}) : text = '', kind = FxKind.chips;
  const FxRequest.burst(this.x, this.y, this.color) : text = '', kind = FxKind.burst, amount = 1;
  const FxRequest.shake(this.amount) : x = 0, y = 0, text = '', color = 0, kind = FxKind.shake;

  final double x;
  final double y;
  final String text;
  final int color;
  final FxKind kind;

  /// Chips: how many. Shake: intensity.
  final double amount;
}

/// Presentation-layer brain of a match. Owns the client copy of the world,
/// applies local prediction for your own miner, smooths everyone else, turns
/// keyboard/touch into [PlayerInput], and publishes [HudState].
class GameController {
  GameController(this._session, {this.audio});

  final GameSession _session;

  /// Sound + haptics; null keeps the controller silent (tests).
  final GameAudio? audio;
  double _lastHp = Balance.maxHealth;

  /// Volume for a sound at (x, y): full next to you, silent ~16 tiles away.
  double _vol(double x, double y) {
    final dx = x - predX, dy = y - predY;
    return (1 - sqrt(dx * dx + dy * dy) / 16).clamp(0.0, 1.0);
  }
  StreamSubscription<SessionEvent>? _sub;

  GameMap? map;
  String? youId;
  MatchSettings settings = const MatchSettings();
  final Map<String, RenderMiner> miners = {};

  final hud = ValueNotifier(const HudState());
  final result = ValueNotifier<MatchResult?>(null);

  /// Lit bombs (from the latest snapshot).
  List<BombSnapshot> bombs = const [];

  /// Monsters and bursting Mystery Bombs (latest snapshot).
  List<MonsterSnapshot> monsters = const [];
  List<MysterySnapshot> mysteries = const [];

  /// Fog of war: tiles you've had in your light. Drives the mini-map.
  List<bool> explored = const [];
  final minimapTick = ValueNotifier(0);
  double _minimapClock = 0;
  int _bannerSeq = 0;
  double _bannerLeft = 0;

  /// Launcher pads that just fired (tile index → animation 1..0).
  final Map<int, double> launcherFx = {};
  final Map<String, int> _tntBeat = {};
  double _monsterWarnCd = 0;
  double _lavaWarnCd = 0;

  /// Columns of the surface shop.
  List<int> depotXs = const [];

  /// Someone's light has reached the treasure.
  bool treasureSpotted = false;

  /// Bumped when tiles change so the map layer can repaint caches.
  int mapVersion = 0;
  final List<FxRequest> _fx = [];

  // Local prediction.
  double predX = 0, predY = 0, predVx = 0, predVy = 0;
  bool _hasPrediction = false;
  bool _freshSnap = false;

  // Input sources.
  double joyX = 0, joyY = 0;
  bool mineHeld = false;

  /// Touch jump / jetpack buttons.
  bool jumpHeld = false;
  bool jetHeld = false;

  /// Keeps a quick tap "pressed" long enough for the server to see it.
  double _jumpLatch = 0;
  double _fx0 = 0, _fy0 = 1;
  int _seq = 0;
  bool _bombKey = false, _dynKey = false;
  double _sendTimer = 0;
  PlayerInput _lastSent = PlayerInput.idle;
  final List<String> _feed = [];

  RenderMiner? get me => youId == null ? null : miners[youId];
  bool get ready => map != null && me != null;

  Future<void> start() async {
    _sub = _session.events.listen(_onEvent);
    await _session.start();
  }

  List<FxRequest> drainFx() {
    if (_fx.isEmpty) return const [];
    final out = List.of(_fx);
    _fx.clear();
    return out;
  }

  // ---- server events -------------------------------------------------------

  void _onEvent(SessionEvent e) {
    switch (e) {
      case SessionJoined():
        map = e.map;
        youId = e.youId;
        settings = e.settings;
        miners.clear();
        _hasPrediction = false;
        mapVersion++;
        depotXs = (e.map.depotTiles.map((t) => t.x).toSet().toList()..sort());
        // Keep what you've explored if you reconnect to the same mine.
        if (!(e.reconnected && explored.length == e.map.width * e.map.height)) {
          explored = List.filled(e.map.width * e.map.height, false);
          for (var i = 0; i < e.map.width * (MapGenerator.surfaceRows + 1); i++) {
            explored[i] = true; // the surface is common knowledge
          }
        }
        hud.value = hud.value.copyWith(
          roomCode: e.roomCode,
          mode: e.settings.mode,
          mapName: e.settings.mapId.def.name,
          lobbyTarget: e.settings.minPlayers,
          lavaDepth: e.settings.mapId.def.height - 1 - e.settings.mapId.def.lavaRows - MapGenerator.surfaceRows,
        );
        if (e.reconnected) _pushFeed('Reconnected');
      case SessionSnapshot(:final snapshot):
        _applySnapshot(snapshot);
      case SessionEnded(result: final r):
        final won = r.winnerId == youId || (r.winnerId == null && r.players.isNotEmpty && r.players.first.playerId == youId);
        audio?.play(won ? Sfx.victory : Sfx.defeat);
        result.value = r;
      case SessionHint(:final hint):
        final old = hud.value.hint;
        hud.value = hud.value.copyWith(hint: hint);
        if (old.level == 0 && hint.level >= 1) {
          _banner('TREASURE SIGNAL DETECTED!', 'Follow the gold compass: ${hint.distance} m away', 0xFFFFC233);
          audio?.play(Sfx.gem);
        }
        if (hint.level > old.level) {
          _pushFeed(switch (hint.level) {
            1 => 'You sense something glittering deep below…',
            2 => 'Warmer! The treasure is close.',
            _ => 'Very close! It\'s right around here!',
          });
          final m = me;
          if (m != null && hint.level >= 2) _fx.add(FxRequest(m.rx, m.ry - 1, hint.level == 3 ? 'HOT!' : 'Warmer…', 0xFFFFD34D));
        }
      case SessionLink(:final status, :final message, :final rttMs):
        hud.value = hud.value.copyWith(link: status, linkMessage: message, rttMs: rttMs);
    }
  }

  void _applySnapshot(WorldSnapshot s) {
    final m = map;
    if (m == null) return;

    if (s.tiles.isNotEmpty) {
      final lavaTop = m.height - 1 - settings.mapId.def.lavaRows;
      // A boulder moving down a tile is not a broken tile: no rock chips.
      final boulderNow = {for (final t in s.tiles) if (t.typeIndex == TileType.boulder.index) t.index};
      for (final t in s.tiles) {
        final old = m.tileAtIndex(t.index);
        final oldHp = m.hpAtIndex(t.index);
        final nt = TileType.values[t.typeIndex];
        m.applyTile(t.index, nt, t.hp);
        final x = t.index % m.width + 0.5, y = t.index ~/ m.width + 0.5;
        final d = ((y - MapGenerator.surfaceRows) / max(1, lavaTop - MapGenerator.surfaceRows)).clamp(0.0, 1.0);
        final color = MinePalette.chip(old, d).toARGB32();
        if (old == TileType.boulder && boulderNow.contains(t.index + m.width)) continue;
        if (old.isSolid && !nt.isSolid) {
          audio?.play(Sfx.rockBreak, volume: _vol(x, y) * 0.8);
          _fx.add(FxRequest.chips(x, y, color, amount: 10));
          if (old.ore != null) _fx.add(FxRequest.burst(x, y, MinePalette.chip(old, d).toARGB32()));
        } else if (nt == old && t.hp < oldHp) {
          audio?.play(Sfx.dig, volume: _vol(x, y) * 0.7);
          _fx.add(FxRequest.chips(x, y, color, amount: 4));
        }
      }
      mapVersion++;
    }

    bombs = s.bombs;
    // TNT countdown beeps, one per second, for TNT near you.
    final live = <String>{};
    for (final b in bombs.where((b) => b.tnt != null)) {
      final key = '${b.x.toStringAsFixed(1)},${b.y.floor()}';
      live.add(key);
      final n = b.fuse.ceil();
      if (_tntBeat[key] != n) {
        _tntBeat[key] = n;
        audio?.play(Sfx.tick, volume: _vol(b.x, b.y));
      }
    }
    _tntBeat.removeWhere((k, _) => !live.contains(k));
    // Monster warning.
    if (_monsterWarnCd <= 0 && me != null && me!.snap.alive) {
      final close = s.monsters.where((m) => pow(m.x - predX, 2) + pow(m.y - predY, 2) < 25).firstOrNull;
      if (close != null) {
        _monsterWarnCd = 20;
        _banner('MONSTER NEARBY!', '${monsterDefs[close.kind]!.name}: fight with your pickaxe or run', 0xFFFF4D6A);
        audio?.play(Sfx.alarm, volume: 0.6);
      }
    }
    monsters = s.monsters;
    mysteries = s.mysteries;
    final ev = s.worldEvent;
    hud.value = ev == null
        ? hud.value.copyWith(clearEvent: true, worldEventLeft: 0)
        : hud.value.copyWith(worldEvent: ev, worldEventLeft: s.worldEventLeft);
    if (ev == WorldEventKind.earthquake) _fx.add(const FxRequest.shake(3));
    final seen = <String>{};
    for (final p in s.players) {
      seen.add(p.id);
      final rm = miners[p.id];
      if (rm == null) {
        miners[p.id] = RenderMiner(p);
      } else {
        final jumped = (rm.snap.alive != p.alive) || (pow(rm.rx - p.x, 2) + pow(rm.ry - p.y, 2) > 9);
        rm.snap = p;
        if (jumped) {
          rm.rx = p.x;
          rm.ry = p.y;
        }
      }
    }
    miners.removeWhere((id, _) => !seen.contains(id));

    final mine = me;
    if (mine != null) {
      // Got hurt (spikes, falls, blasts…): sting + buzz.
      if (mine.snap.alive && mine.snap.hp < _lastHp - 3) {
        audio?.play(Sfx.hurt);
        audio?.buzz(Haptic.medium);
      }
      _lastHp = mine.snap.alive ? mine.snap.hp : Balance.maxHealth;
      if (!_hasPrediction || !mine.snap.alive) {
        predX = mine.snap.x;
        predY = mine.snap.y;
        predVx = mine.snap.vx;
        predVy = mine.snap.vy;
        _hasPrediction = true;
      }
      _freshSnap = true;
    }

    for (final ev in s.events) {
      _handleEvent(ev);
    }

    hud.value = hud.value.copyWith(
      me: mine?.snap,
      timeLeft: s.timeLeft,
      warmup: s.warmup,
      teamScores: s.teamScores,
      scoreboard: (s.players.toList()..sort((a, b) => b.y.compareTo(a.y)))
          .map(
            (p) => ScoreLine(
              id: p.id,
              name: p.name,
              score: p.score,
              isBot: p.isBot,
              isYou: p.id == youId,
              team: p.team,
              connected: p.connected,
              depth: p.alive ? (p.y.floor() - MapGenerator.surfaceRows + 1).clamp(0, 9999) : 0,
            ),
          )
          .toList(),
      feed: List.unmodifiable(_feed),
    );
  }

  void _handleEvent(GameEvent ev) {
    final who = ev.playerId == null ? null : miners[ev.playerId];
    final name = who?.snap.name ?? ev.text ?? 'Someone';
    final isMe = ev.playerId == youId;
    switch (ev.kind) {
      case GameEventKind.oreMined:
        final ore = oreDefs[OreType.values[ev.value]]!;
        if (who != null && (isMe || ore.rarity.index >= Rarity.epic.index)) {
          _fx.add(FxRequest(who.rx, who.ry - 0.6, '+${ore.value} ${ore.name}', _rarityColor(ore.rarity)));
        }
        if (!isMe && ore.type == OreType.moneyBag) _pushFeed('$name found a ${ore.name}!');
        if (isMe) audio?.play(ore.rarity.index >= Rarity.epic.index ? Sfx.gem : Sfx.coin);
      case GameEventKind.treasureRevealed:
        _pushFeed(isMe ? 'You spotted the TREASURE! Dig it out!' : 'Someone spotted the treasure near $name!');
        treasureSpotted = true;
      case GameEventKind.treasureFound:
        _pushFeed(isMe ? 'YOU FOUND THE TREASURE!' : '$name found the treasure!');
        if (who != null) {
          _fx
            ..add(FxRequest(who.rx, who.ry - 0.8, '${Balance.treasureName}! +${ev.value}', 0xFFFFD34D))
            ..add(FxRequest.burst(who.rx, who.ry, 0xFFFFD34D))
            ..add(const FxRequest.shake(14));
        }
      case GameEventKind.died:
        _pushFeed(isMe ? 'You were killed by ${_cause(ev.text)}!' : '$name was killed by ${_cause(ev.text)}');
        if (isMe) hud.value = hud.value.copyWith(deathCause: _cause(ev.text), deathLost: ev.value);
        if (isMe) {
          _fx.add(const FxRequest.shake(10));
          audio?.buzz(Haptic.heavy);
        }
      case GameEventKind.upgraded:
        if (isMe) _pushFeed('Equipped ${UpgradeKind.values[ev.value].levels[who?.snap.upgrades[ev.value] ?? 0].name}');
      case GameEventKind.joined:
        _pushFeed('${ev.text} joined');
      case GameEventKind.left:
        _pushFeed('${ev.text} left');
      case GameEventKind.botJoined:
        _pushFeed('${ev.text} (bot) joined');
      case GameEventKind.botLeft:
        _pushFeed('${ev.text} (bot) left');
      case GameEventKind.chat:
        _pushFeed('$name: ${ev.text}');
      case GameEventKind.explosion:
        if (ev.x != null) {
          final v = _vol(ev.x!, ev.y!);
          audio?.play(ev.value == ItemKind.dynamite.index ? Sfx.explosion : Sfx.smallBlast, volume: 0.3 + 0.7 * v);
          if (v > 0.5) audio?.buzz(Haptic.heavy);
          _fx
            ..add(FxRequest.burst(ev.x!, ev.y!, 0xFFFFB13B))
            ..add(FxRequest.chips(ev.x!, ev.y!, 0xFF6E655E, amount: 24))
            ..add(FxRequest.shake(ev.value == ItemKind.dynamite.index ? 12 : 7));
        }
      case GameEventKind.volcano:
        if (ev.x != null) {
          audio?.play(Sfx.lava, volume: _vol(ev.x!, ev.y!));
          audio?.play(Sfx.smallBlast, volume: _vol(ev.x!, ev.y!) * 0.8);
          _fx
            ..add(FxRequest.burst(ev.x!, ev.y!, 0xFFFF5A1F))
            ..add(FxRequest.chips(ev.x!, ev.y!, 0xFFFF7A1F, amount: 30))
            ..add(const FxRequest.shake(9));
        }
        if (isMe) _pushFeed('You cracked a hidden VOLCANO!');
      case GameEventKind.itemBought:
        if (isMe) _pushFeed('Bought ${itemDefs[ItemKind.values[ev.value]]!.name}');
      case GameEventKind.respawned:
        if (isMe) _hasPrediction = false;
      case GameEventKind.mysteryFound:
        final near = ev.x != null && _vol(ev.x!, ev.y!) > 0.2;
        if (isMe || near) {
          _banner('MYSTERY BOMB DISCOVERED!', isMe ? 'Rarity: UNKNOWN… stand back!' : '$name cracked one open nearby', 0xFFB06BFF);
          _fx.add(const FxRequest.shake(5));
          audio?.play(Sfx.gem, volume: isMe ? 1 : 0.6);
          audio?.buzz(Haptic.medium);
        } else {
          _pushFeed('$name found a Mystery Bomb!');
        }
      case GameEventKind.mysteryOpened:
        final rarity = MysteryRarity.values[(ev.value ~/ 100).clamp(0, MysteryRarity.values.length - 1)];
        final reward = MysteryReward.values[(ev.value % 100).clamp(0, MysteryReward.values.length - 1)];
        final color = _mysteryColor(rarity);
        if (ev.x != null) {
          _fx
            ..add(FxRequest.burst(ev.x!, ev.y!, color))
            ..add(FxRequest.burst(ev.x!, ev.y!, 0xFFFFFFFF))
            ..add(FxRequest.chips(ev.x!, ev.y!, color, amount: 26))
            ..add(FxRequest(ev.x!, ev.y! - 0.8, '${rarity.label.toUpperCase()}!', color))
            ..add(FxRequest.shake(rarity.index >= MysteryRarity.legendary.index ? 12 : 6));
        }
        final high = rarity.index >= MysteryRarity.legendary.index;
        if (isMe) {
          _banner('${rarity.label.toUpperCase()} MYSTERY BOMB', ev.text ?? reward.label, color);
          audio?.play(high || reward == MysteryReward.jackpot ? Sfx.victory : (reward == MysteryReward.monster ? Sfx.hurt : Sfx.gem));
        } else {
          audio?.play(Sfx.smallBlast, volume: ev.x == null ? 0 : _vol(ev.x!, ev.y!) * 0.7);
        }
        if (high || reward == MysteryReward.jackpot) {
          _pushFeed('$name opened a ${rarity.label.toUpperCase()} Mystery Bomb: ${reward.label}!');
        }
      case GameEventKind.monsterKilled:
        final def = monsterDefs[MonsterKind.values[ev.value.clamp(0, MonsterKind.values.length - 1)]]!;
        if (ev.x != null) {
          _fx
            ..add(FxRequest.chips(ev.x!, ev.y!, ev.value == MonsterKind.golem.index ? 0xFF8A8079 : 0xFF3A2F45, amount: 18))
            ..add(FxRequest(ev.x!, ev.y! - 0.6, isMe ? '+${def.loot} ${def.name}' : def.name, 0xFFFF8A5B));
          audio?.play(Sfx.rockBreak, volume: _vol(ev.x!, ev.y!));
        }
        _pushFeed(isMe ? 'You defeated a ${def.name}!' : '$name defeated a ${def.name}');
      case GameEventKind.worldEvent:
        final k = WorldEventKind.values[ev.value.clamp(0, WorldEventKind.values.length - 1)];
        _banner(k.label.toUpperCase(), k.blurb, k == WorldEventKind.earthquake ? 0xFFFF8A5B : (k == WorldEventKind.goldRush ? 0xFFFFD34D : 0xFFB06BFF));
        _pushFeed('EVENT: ${k.label}! ${k.blurb}');
        audio?.play(k == WorldEventKind.earthquake ? Sfx.explosion : Sfx.victory, volume: 0.7);
        if (k == WorldEventKind.earthquake) _fx.add(const FxRequest.shake(12));
      case GameEventKind.hazardRevealed:
        final t = TileType.values[ev.value.clamp(0, TileType.values.length - 1)];
        final near = ev.x != null && _vol(ev.x!, ev.y!) > 0.45;
        if (near && t == TileType.lava && _lavaWarnCd <= 0) {
          _lavaWarnCd = 12;
          _banner('LAVA DISCOVERED!', 'Hot rock ahead, don\'t touch it', 0xFFFF6A3D);
          audio?.play(Sfx.lava);
        } else if (near && t.isLauncher) {
          _pushFeed('A launcher pad! Step on it and you fly.');
        } else if (near && t.tnt != null) {
          _pushFeed('You uncovered ${t.tnt!.label}. Careful!');
        } else if (near && t == TileType.water) {
          _pushFeed('Underground water broke loose!');
        }
      case GameEventKind.tntActivated:
        final kind = TntKind.values[ev.value.clamp(0, TntKind.values.length - 1)];
        if (ev.x != null && _vol(ev.x!, ev.y!) > 0.35) {
          _banner('TNT ACTIVATED!', '${kind.label}: 3 seconds, get clear!', 0xFFFF453A);
          audio?.play(Sfx.alarm, volume: _vol(ev.x!, ev.y!));
          audio?.buzz(Haptic.medium);
        }
      case GameEventKind.launcherArmed:
        if (ev.x != null) audio?.play(Sfx.dig, volume: _vol(ev.x!, ev.y!));
      case GameEventKind.launcherFired:
        final m = map;
        if (ev.x != null && m != null) {
          launcherFx[m.indexOf(ev.x!.floor(), ev.y!.floor())] = 1;
          audio?.play(Sfx.spring, volume: _vol(ev.x!, ev.y!));
          _fx.add(FxRequest.chips(ev.x!, ev.y! + 0.3, 0xFFC9D1D9, amount: 8));
        }
      case GameEventKind.plateTriggered:
        final trap = PlateTrap.values[ev.value.clamp(0, PlateTrap.values.length - 1)];
        if (ev.x != null && _vol(ev.x!, ev.y!) > 0.35) {
          final (title, sub) = switch (trap) {
            PlateTrap.collapse => ('CAVE COLLAPSE!', 'A pressure plate brought the ceiling down'),
            PlateTrap.spikes => ('SPIKE TRAP!', 'Spikes shot up from the floor'),
            PlateTrap.tnt => ('TNT TRAP!', 'Something dropped from the ceiling…'),
          };
          _banner(title, sub, 0xFFFF8A5B);
          audio?.play(Sfx.alarm);
          _fx.add(const FxRequest.shake(6));
        }
      case GameEventKind.chestOpened:
        if (ev.x != null) {
          _fx
            ..add(FxRequest(ev.x!, ev.y! - 0.6, isMe ? '+${ev.value} coins${ev.text != null ? ' ${ev.text}' : ''}' : 'Chest!', 0xFFFFC233))
            ..add(FxRequest.burst(ev.x!, ev.y!, 0xFFFFC233));
          audio?.play(Sfx.chest, volume: _vol(ev.x!, ev.y!));
        }
      case GameEventKind.chamberOpened:
        _banner('SECRET CHAMBER OPENED!', isMe ? 'An ancient door slid open below you' : '$name opened the treasure chamber!', 0xFFFFC233);
        _pushFeed('The sealed treasure chamber is open!');
        audio?.play(Sfx.victory, volume: 0.8);
        _fx.add(const FxRequest.shake(8));
      case GameEventKind.worldEventEnded:
        _pushFeed('${WorldEventKind.values[ev.value.clamp(0, WorldEventKind.values.length - 1)].label} is over');
    }
  }

  void _banner(String title, String subtitle, int color) {
    _bannerLeft = 3.2;
    hud.value = hud.value.copyWith(banner: HudBanner(title, subtitle, color, ++_bannerSeq));
  }

  static int _mysteryColor(MysteryRarity r) => switch (r) {
    MysteryRarity.common => 0xFF7EE08A,
    MysteryRarity.rare => 0xFF4DA3FF,
    MysteryRarity.epic => 0xFFB06BFF,
    MysteryRarity.legendary => 0xFFFFC233,
    MysteryRarity.mythic => 0xFFFF4D6A,
  };

  /// Marks tiles inside your helmet light as explored.
  void _explore(GameMap m, double x, double y, double radius) {
    final r = radius.ceil();
    final cx = x.floor(), cy = y.floor();
    for (var ty = cy - r; ty <= cy + r; ty++) {
      for (var tx = cx - r; tx <= cx + r; tx++) {
        if (!m.inBounds(tx, ty)) continue;
        if ((tx - cx) * (tx - cx) + (ty - cy) * (ty - cy) > r * r) continue;
        explored[m.indexOf(tx, ty)] = true;
      }
    }
  }

  static String _cause(String? c) => switch (c) {
    'lava' => 'lava',
    null => 'the mine',
    final x => x,
  };

  void _pushFeed(String s) {
    _feed.add(s);
    if (_feed.length > 5) _feed.removeAt(0);
  }

  static int _rarityColor(Rarity r) => switch (r) {
    Rarity.common => 0xFFE6D3BE,
    Rarity.rare => 0xFFFFD34D,
    Rarity.epic => 0xFF7FE7FF,
    Rarity.legendary => 0xFFE08BFF,
  };

  // ---- per frame -----------------------------------------------------------

  void update(double dt) {
    final m = map;
    if (m == null) return;

    // Smooth remote miners.
    final k = min(1.0, dt * 12);
    for (final rm in miners.values) {
      if (rm.snap.mining) rm.swing += dt * 18;
      if (rm.snap.id == youId) continue;
      rm.rx += (rm.snap.x - rm.rx) * k;
      rm.ry += (rm.snap.y - rm.ry) * k;
    }

    final mine = me;
    if (mine == null) return;
    final input = _readInput(dt);

    launcherFx.updateAll((_, v) => v - dt * 2.5);
    launcherFx.removeWhere((_, v) => v <= 0);
    _monsterWarnCd = max(0, _monsterWarnCd - dt);
    _lavaWarnCd = max(0, _lavaWarnCd - dt);
    if (_bannerLeft > 0) {
      _bannerLeft -= dt;
      if (_bannerLeft <= 0) hud.value = hud.value.copyWith(clearBanner: true);
    }
    _minimapClock += dt;
    if (_minimapClock > 0.25 && explored.isNotEmpty) {
      _minimapClock = 0;
      if (mine.snap.alive) _explore(m, predX, predY, mine.snap.vision * 0.8);
      minimapTick.value++;
    }

    // Predict your own movement with the shared gravity physics.
    final s = mine.snap;
    if (s.alive && _hasPrediction) {
      final boots = s.gear(UpgradeKind.boots).stat;
      final mv = Physics.move(
        m,
        predX,
        predY,
        predVx,
        predVy,
        moveX: input.dx,
        speed: Physics.speedFor(s.stamina, boots: boots),
        dt: dt,
        jump: input.jump,
        up: input.up,
        jet: input.jet && s.fuel > 1,
        jumpBoost: Physics.jumpBoostFor(boots),
      );
      if (input.jump && !input.jet && predVy >= -0.01 && mv.vy < -5) audio?.play(Sfx.jump, volume: 0.6);
      if (mv.impact > 10) {
        audio?.play(Sfx.land, volume: (mv.impact / 20).clamp(0.3, 1.0));
        if (mv.impact > Balance.safeFallSpeed) audio?.buzz(Haptic.medium);
      }
      if (input.jet && s.fuel > 1) audio?.play(Sfx.jet, volume: 0.5);
      predX = mv.x;
      predY = mv.y;
      predVx = mv.vx;
      predVy = mv.vy;
      // A blast or boulder shoved us on the server: take its velocity.
      if (_freshSnap && (s.vx - predVx).abs() + (s.vy - predVy).abs() > 7) {
        predVx = s.vx;
        predVy = s.vy;
      }
      _freshSnap = false;
      // Reconcile toward the authoritative position.
      final ex = s.x - predX, ey = s.y - predY;
      final err = sqrt(ex * ex + ey * ey);
      if (err > 2.5) {
        predX = s.x;
        predY = s.y;
        predVx = s.vx;
        predVy = s.vy;
      } else {
        final rate = min(1.0, dt * (err > 0.6 ? 6 : 2.5));
        final nx = predX + ex * rate, ny = predY + ey * rate;
        if (!Physics.collides(m, nx, ny)) {
          predX = nx;
          predY = ny;
        }
      }
    } else {
      predX = s.x;
      predY = s.y;
      predVx = predVy = 0;
    }
    mine
      ..rx = predX
      ..ry = predY;

    _sendTimer += dt;
    final changed = input.dx != _lastSent.dx ||
        input.dy != _lastSent.dy ||
        input.mine != _lastSent.mine ||
        input.jump != _lastSent.jump ||
        input.jet != _lastSent.jet ||
        input.fx != _lastSent.fx ||
        input.fy != _lastSent.fy;
    if ((changed && _sendTimer >= 0.05) || _sendTimer >= 0.5) {
      _sendTimer = 0;
      _lastSent = input;
      _session.sendInput(input);
    }
  }

  PlayerInput _readInput(double dt) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    var dx = joyX, dy = joyY;
    if (keys.contains(LogicalKeyboardKey.keyA) || keys.contains(LogicalKeyboardKey.arrowLeft)) dx -= 1;
    if (keys.contains(LogicalKeyboardKey.keyD) || keys.contains(LogicalKeyboardKey.arrowRight)) dx += 1;
    if (keys.contains(LogicalKeyboardKey.keyW) || keys.contains(LogicalKeyboardKey.arrowUp)) dy -= 1;
    if (keys.contains(LogicalKeyboardKey.keyS) || keys.contains(LogicalKeyboardKey.arrowDown)) dy += 1;
    final mag = sqrt(dx * dx + dy * dy);
    if (mag > 1) {
      dx /= mag;
      dy /= mag;
    }
    // Aim along the dominant axis so you dig the tile you expect. Up/down
    // only take over when clearly pushed; running keeps aiming sideways.
    if (dy.abs() > 0.45 && dy.abs() > dx.abs() * 0.8) {
      _fx0 = 0;
      _fy0 = dy.sign;
    } else if (dx.abs() > 0.25) {
      _fx0 = dx.sign;
      _fy0 = 0;
    }
    final mining = mineHeld || keys.contains(LogicalKeyboardKey.space) || keys.contains(LogicalKeyboardKey.keyJ);
    // Up jumps, unless you're digging upward.
    if (jumpHeld || (dy < -0.5 && !mining)) _jumpLatch = 0.15;
    final jump = _jumpLatch > 0;
    _jumpLatch = max(0, _jumpLatch - dt);
    // B = bomb, N = dynamite (on key-down only).
    final bomb = keys.contains(LogicalKeyboardKey.keyB), dyn = keys.contains(LogicalKeyboardKey.keyN);
    if (bomb && !_bombKey) useItem(ItemKind.bomb);
    if (dyn && !_dynKey) useItem(ItemKind.dynamite);
    _bombKey = bomb;
    _dynKey = dyn;
    return PlayerInput(
      seq: ++_seq,
      dx: (dx * 100).roundToDouble() / 100,
      dy: (dy * 100).roundToDouble() / 100,
      fx: _fx0,
      fy: _fy0,
      mine: mining,
      jump: jump,
      jet: jetHeld || keys.contains(LogicalKeyboardKey.shiftLeft) || keys.contains(LogicalKeyboardKey.shiftRight) || keys.contains(LogicalKeyboardKey.keyK),
    );
  }

  /// The tile your pickaxe would hit right now (for the highlight).
  TilePos? get aimTile {
    final m = map, mine = me;
    if (m == null || mine == null || !mine.snap.alive) return null;
    return Physics.mineTarget(m, predX, predY, _fx0, _fy0);
  }

  // ---- commands ------------------------------------------------------------

  void buy(UpgradeKind k) => _session.buyUpgrade(k);
  void buyItem(ItemKind k) => _session.buyItem(k);
  void useItem(ItemKind k) => _session.useItem(k);
  void chat(String text) => _session.chat(text);

  Future<void> dispose() async {
    await _sub?.cancel();
    await _session.leave();
    hud.dispose();
    result.dispose();
    minimapTick.dispose();
  }
}
