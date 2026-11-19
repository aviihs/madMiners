import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/session_event.dart';
import '../../domain/repositories/game_session_repository.dart';
import 'hud_state.dart';

/// A miner as drawn on screen (smoothed toward the latest server state).
class RenderMiner {
  RenderMiner(this.snap) : rx = snap.x, ry = snap.y;
  PlayerSnapshot snap;
  double rx;
  double ry;
  double swing = 0; // pickaxe animation phase
}

/// Short-lived visual effect requested by gameplay events.
class FxRequest {
  const FxRequest(this.x, this.y, this.text, this.color);
  final double x;
  final double y;
  final String text;
  final int color;
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

  /// Bumped when tiles change so the map layer can repaint caches.
  int mapVersion = 0;
  final List<FxRequest> _fx = [];

  // Local prediction.
  double predX = 0, predY = 0;
  bool _hasPrediction = false;

  // Input sources.
  double joyX = 0, joyY = 0;
  bool mineHeld = false;
  double _fx0 = 0, _fy0 = 1;
  int _seq = 0;
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
        hud.value = hud.value.copyWith(
          roomCode: e.roomCode,
          mode: e.settings.mode,
          mapName: e.settings.mapId.def.name,
          oxygenDepth: e.settings.mapId.def.oxygenDepth,
        );
        if (e.reconnected) _pushFeed('Reconnected');
      case SessionSnapshot(:final snapshot):
        _applySnapshot(snapshot);
      case SessionEnded(result: final r):
        result.value = r;
      case SessionLink(:final status, :final message, :final rttMs):
        hud.value = hud.value.copyWith(link: status, linkMessage: message, rttMs: rttMs);
    }
  }

  void _applySnapshot(WorldSnapshot s) {
    final m = map;
    if (m == null) return;

    if (s.tiles.isNotEmpty) {
      for (final t in s.tiles) {
        m.applyTile(t.index, TileType.values[t.typeIndex], t.hp);
      }
      mapVersion++;
    }

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
        _hasPrediction = true;
      }
    }

    for (final ev in s.events) {
      _handleEvent(ev);
    }

    hud.value = hud.value.copyWith(
      me: mine?.snap,
      timeLeft: s.timeLeft,
      teamScores: s.teamScores,
      scoreboard: (s.players.toList()..sort((a, b) => b.score.compareTo(a.score)))
          .map(
            (p) => ScoreLine(
              id: p.id,
              name: p.name,
              score: p.score,
              isBot: p.isBot,
              isYou: p.id == youId,
              team: p.team,
              connected: p.connected,
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
          _fx.add(FxRequest(who.rx, who.ry - 0.6, '+${ore.name}', _rarityColor(ore.rarity)));
        }
        if (!isMe && ore.rarity == Rarity.legendary) _pushFeed('$name found a ${ore.name}!');
      case GameEventKind.sold:
        if (isMe && who != null) _fx.add(FxRequest(who.rx, who.ry - 0.8, '+${ev.value} coins', 0xFFF2A93B));
      case GameEventKind.died:
        _pushFeed('$name was taken by ${ev.text ?? 'the mine'}');
      case GameEventKind.upgraded:
        if (isMe) _pushFeed('Bought ${UpgradeKind.values[ev.value].levels[who?.snap.upgrades[ev.value] ?? 0].name}');
      case GameEventKind.backpackFull:
        if (isMe) _pushFeed('Backpack full — head to the depot!');
      case GameEventKind.joined:
        _pushFeed('${ev.text} joined');
      case GameEventKind.left:
        _pushFeed('${ev.text} left');
      case GameEventKind.botJoined:
        _pushFeed('${ev.text} (bot) joined');
      case GameEventKind.botLeft:
        _pushFeed('${ev.text} (bot) made room');
      case GameEventKind.chat:
        _pushFeed('$name: ${ev.text}');
      case GameEventKind.respawned:
        if (isMe) _hasPrediction = false;
    }
  }

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
    final input = _readInput();

    // Predict your own movement with the shared physics.
    if (mine.snap.alive && _hasPrediction) {
      final speed = Physics.speedFor(mine.snap.stamina);
      final (nx, ny) = Physics.step(m, predX, predY, input.dx * speed, input.dy * speed, dt);
      predX = nx;
      predY = ny;
      // Reconcile toward the authoritative position.
      final ex = mine.snap.x - predX, ey = mine.snap.y - predY;
      final err = sqrt(ex * ex + ey * ey);
      if (err > 2.5) {
        predX = mine.snap.x;
        predY = mine.snap.y;
      } else {
        final moving = input.dx != 0 || input.dy != 0;
        final rate = min(1.0, dt * (moving ? (err > 0.8 ? 4 : 1.2) : 8));
        predX += ex * rate;
        predY += ey * rate;
      }
    } else {
      predX = mine.snap.x;
      predY = mine.snap.y;
    }
    mine
      ..rx = predX
      ..ry = predY;

    _sendTimer += dt;
    final changed = input.dx != _lastSent.dx ||
        input.dy != _lastSent.dy ||
        input.mine != _lastSent.mine ||
        input.fx != _lastSent.fx ||
        input.fy != _lastSent.fy;
    if ((changed && _sendTimer >= 0.05) || _sendTimer >= 0.5) {
      _sendTimer = 0;
      _lastSent = input;
      _session.sendInput(input);
    }
  }

  PlayerInput _readInput() {
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
    if (mag > 0.25) {
      // Snap facing to the dominant axis so you dig the tile you expect.
      if (dx.abs() > dy.abs()) {
        _fx0 = dx.sign;
        _fy0 = 0;
      } else {
        _fx0 = 0;
        _fy0 = dy.sign;
      }
    }
    final mining = mineHeld || keys.contains(LogicalKeyboardKey.space) || keys.contains(LogicalKeyboardKey.keyJ);
    return PlayerInput(
      seq: ++_seq,
      dx: (dx * 100).roundToDouble() / 100,
      dy: (dy * 100).roundToDouble() / 100,
      fx: _fx0,
      fy: _fy0,
      mine: mining,
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
  void chat(String text) => _session.chat(text);

  Future<void> dispose() async {
    await _sub?.cancel();
    await _session.leave();
    hud.dispose();
    result.dispose();
  }
}
