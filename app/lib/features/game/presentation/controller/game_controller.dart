import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

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
  GameController(this._session);

  final GameSession _session;
  StreamSubscription<SessionEvent>? _sub;

  GameMap? map;
  String? youId;
  MatchSettings settings = const MatchSettings();
  final Map<String, RenderMiner> miners = {};

  final hud = ValueNotifier(const HudState());
  final result = ValueNotifier<MatchResult?>(null);

  /// Lit bombs (from the latest snapshot).
  List<BombSnapshot> bombs = const [];

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

  /// Touch jump button.
  bool jumpHeld = false;

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
        result.value = r;
      case SessionHint(:final hint):
        final old = hud.value.hint;
        hud.value = hud.value.copyWith(hint: hint);
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
          _fx.add(FxRequest.chips(x, y, color, amount: 10));
          if (old.ore != null) _fx.add(FxRequest.burst(x, y, MinePalette.chip(old, d).toARGB32()));
        } else if (nt == old && t.hp < oldHp) {
          _fx.add(FxRequest.chips(x, y, color, amount: 4));
        }
      }
      mapVersion++;
    }

    bombs = s.bombs;
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
        if (isMe) _fx.add(const FxRequest.shake(10));
      case GameEventKind.upgraded:
        if (isMe) _pushFeed('Equipped ${UpgradeKind.values[ev.value].levels[who?.snap.upgrades[ev.value] ?? 0].name}');
      case GameEventKind.joined:
        _pushFeed('${ev.text} joined');
      case GameEventKind.left:
        _pushFeed('${ev.text} left');
      case GameEventKind.botJoined:
        _pushFeed('${ev.text} joined');
      case GameEventKind.botLeft:
        _pushFeed('${ev.text} left');
      case GameEventKind.chat:
        _pushFeed('$name: ${ev.text}');
      case GameEventKind.explosion:
        if (ev.x != null) {
          _fx
            ..add(FxRequest.burst(ev.x!, ev.y!, 0xFFFFB13B))
            ..add(FxRequest.chips(ev.x!, ev.y!, 0xFF6E655E, amount: 24))
            ..add(FxRequest.shake(ev.value == ItemKind.dynamite.index ? 12 : 7));
        }
      case GameEventKind.volcano:
        if (ev.x != null) {
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
        jumpBoost: Physics.jumpBoostFor(boots),
      );
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
  }
}
