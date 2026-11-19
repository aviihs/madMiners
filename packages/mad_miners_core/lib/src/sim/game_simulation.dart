import 'dart:math';

import '../config/balance.dart';
import '../model/match_settings.dart';
import '../model/snapshot.dart';
import '../world/game_map.dart';
import '../world/map_generator.dart';
import '../world/tile.dart';
import 'bot_brain.dart';
import 'physics.dart';
import 'sim_player.dart';

/// Authoritative game state for one room: a race to dig down and break the
/// hidden treasure before anyone else. Falling into the lava sends you back
/// to the surface.
///
/// Pure Dart, no I/O: the server drives it from a timer and broadcasts
/// [takeSnapshot]; the client's offline mode drives the very same class.
class GameSimulation {
  GameSimulation({required this.settings, required int seed, MapGenerator generator = const MapGenerator()})
    : _rng = Random(seed),
      map = generator.generate(settings.mapId, seed),
      timeLeft = settings.durationSeconds.toDouble() {
    treasure = map.treasure!;
  }

  final MatchSettings settings;
  final GameMap map;
  final Random _rng;
  late final TilePos treasure;

  final Map<String, SimPlayer> players = {};
  final Map<String, BotBrain> _bots = {};
  final Set<int> _dirtyTiles = {};
  final List<GameEvent> _events = [];

  double timeLeft;
  int tick = 0;

  /// Clients don't learn where the treasure is until a miner's light reaches it.
  bool treasureRevealed = false;
  String? winnerId;

  bool get ended => timeLeft <= 0 || winnerId != null;
  int _botSeq = 0;

  static const _botNames = [
    'Rusty', 'Pebble', 'Dynamo', 'Grit', 'Nugget', 'Boulder', 'Flint', 'Ember',
    'Shale', 'Quartz', 'Cobalt', 'Tunnel', 'Drillbit', 'Gravel', 'Digger',
  ];

  bool get hasTeams => settings.mode == GameMode.teamHunt;
  int get humanCount => players.values.where((p) => !p.isBot).length;
  int get botCount => _bots.length;

  /// The map as clients may see it (treasure disguised until revealed).
  GameMap publicMap() => GameMap.fromJson(map.toJson(hideTreasure: !treasureRevealed));

  // ---- roster -------------------------------------------------------------

  SimPlayer addHuman(String id, String name) {
    final existing = players[id];
    if (existing != null) return existing;
    final p = _spawnPlayer(id, name, isBot: false);
    _events.add(GameEvent(GameEventKind.joined, playerId: id, text: name));
    syncBots();
    return p;
  }

  void removePlayer(String id) {
    final p = players.remove(id);
    if (p == null) return;
    _bots.remove(id);
    _events.add(GameEvent(p.isBot ? GameEventKind.botLeft : GameEventKind.left, playerId: id, text: p.name));
    if (!p.isBot) syncBots();
  }

  /// Adds or removes bots so the roster matches [botsNeeded].
  void syncBots() {
    final want = botsNeeded(settings, humanCount);
    while (_bots.length > want) {
      // The shallowest bot makes room for the joining human.
      final victim = _bots.keys.map((id) => players[id]!).reduce((a, b) => a.y <= b.y ? a : b);
      removePlayer(victim.id);
    }
    while (_bots.length < want) {
      final id = 'bot-${++_botSeq}';
      final name = '${_botNames[_rng.nextInt(_botNames.length)]} ${_botSeq.toString().padLeft(2, '0')}';
      _spawnPlayer(id, name, isBot: true);
      _bots[id] = BotBrain(id, seed: _rng.nextInt(1 << 30));
      _events.add(GameEvent(GameEventKind.botJoined, playerId: id, text: name));
    }
  }

  SimPlayer _spawnPlayer(String id, String name, {required bool isBot}) {
    var team = -1;
    if (hasTeams) {
      final counts = List.filled(Balance.teamCount, 0);
      for (final p in players.values) {
        counts[p.team]++;
      }
      team = counts.indexOf(counts.reduce(min));
    }
    final (sx, sy) = _spawnPoint();
    final p = SimPlayer(id: id, name: name, isBot: isBot, team: team, x: sx, y: sy);
    players[id] = p;
    return p;
  }

  (double, double) _spawnPoint() =>
      (map.spawn.cx + (_rng.nextDouble() - 0.5) * 10, map.spawn.cy + (_rng.nextDouble() - 0.5) * 1.5);

  void setConnected(String id, {required bool connected}) => players[id]?.connected = connected;

  // ---- commands -----------------------------------------------------------

  void setInput(String id, PlayerInput input) {
    final p = players[id];
    if (p == null || p.isBot) return;
    p.input = input.sanitized();
  }

  /// Validated purchase. Must stand on the surface depot with enough coins.
  bool requestUpgrade(String id, UpgradeKind kind) {
    final p = players[id];
    if (p == null || !p.alive || !p.inDepot || ended) return false;
    final lvl = p.upgrades[kind.index];
    if (lvl >= kind.maxLevel) return false;
    final cost = kind.levels[lvl + 1].cost;
    if (p.coins < cost) return false;
    p.coins -= cost;
    p.upgrades[kind.index] = lvl + 1;
    _events.add(GameEvent(GameEventKind.upgraded, playerId: id, value: kind.index));
    return true;
  }

  void chat(String id, String text) {
    final p = players[id];
    if (p == null) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    _events.add(GameEvent(GameEventKind.chat, playerId: id, text: clean.length > 120 ? clean.substring(0, 120) : clean));
  }

  // ---- tick ---------------------------------------------------------------

  void update(double dt) {
    if (ended) return;
    tick++;
    timeLeft = max(0, timeLeft - dt);

    final claimed = <TilePos>{
      for (final b in _bots.values)
        if (b.target != null) b.target!,
    };

    for (final p in players.values.toList()) {
      final brain = _bots[p.id];
      if (brain != null) {
        claimed.remove(brain.target);
        final d = brain.think(map, p, dt, claimed, treasureRevealed ? treasure : null);
        p.input = d.input;
        if (d.upgrade != null) requestUpgrade(p.id, d.upgrade!);
        if (brain.target != null) claimed.add(brain.target!);
      }
      _updatePlayer(p, dt);
      if (winnerId != null) return; // game over the instant it's found
    }
  }

  void _updatePlayer(SimPlayer p, double dt) {
    p.miningFlash = max(0, p.miningFlash - dt);

    if (!p.alive) {
      p.respawnIn -= dt;
      if (p.respawnIn <= 0) {
        final (sx, sy) = _spawnPoint();
        p
          ..respawnIn = 0
          ..x = sx
          ..y = sy
          ..hp = Balance.maxHealth
          ..stamina = Balance.maxStamina
          ..maxDepth = 0;
        _events.add(GameEvent(GameEventKind.respawned, playerId: p.id));
      }
      return;
    }

    final input = p.connected ? p.input : PlayerInput.idle;

    // Movement.
    var dx = input.dx, dy = input.dy;
    final mag = sqrt(dx * dx + dy * dy);
    if (mag > 1) {
      dx /= mag;
      dy /= mag;
    }
    final speed = Physics.speedFor(p.stamina);
    final (nx, ny) = Physics.step(map, p.x, p.y, dx * speed, dy * speed, dt);
    p
      ..x = nx
      ..y = ny;
    if (input.fx != 0 || input.fy != 0) {
      p.fx = input.fx;
      p.fy = input.fy;
    } else if (mag > 0.1) {
      p.fx = dx;
      p.fy = dy;
    }
    final depth = max(0, p.y.floor() - MapGenerator.surfaceRows + 1);
    if (depth > p.maxDepth) p.maxDepth = depth;

    // Reveal the treasure once someone's helmet light reaches it.
    if (!treasureRevealed) {
      final ddx = treasure.cx - p.x, ddy = treasure.cy - p.y;
      final v = p.vision * 0.8;
      if (ddx * ddx + ddy * ddy <= v * v) {
        treasureRevealed = true;
        _dirtyTiles.add(map.indexOf(treasure.x, treasure.y));
        _events.add(GameEvent(GameEventKind.treasureRevealed, playerId: p.id));
      }
    }

    // Mining (server validates reach, cooldown and stamina).
    p.mineCooldown = max(0, p.mineCooldown - dt);
    var mined = false;
    if (input.mine && p.mineCooldown <= 0 && p.stamina >= Balance.staminaPerHit) {
      final t = Physics.mineTarget(map, p.x, p.y, p.fx, p.fy);
      if (t != null) _hit(p, t);
      mined = t != null;
    }
    if (!mined) p.stamina = min(Balance.maxStamina, p.stamina + Balance.staminaRegen * dt);
    if (winnerId != null) return;

    // Zone effects.
    final under = map.tileAt(p.x.floor(), p.y.floor());
    p.inDepot = under == TileType.depot;
    if (p.inDepot) p.hp = min(Balance.maxHealth, p.hp + Balance.depotHeal * dt);
    if (under == TileType.lava) p.hp -= Balance.lavaDamage * dt;
    if (under == TileType.gas) p.hp -= Balance.gasDamage * dt;

    if (p.hp <= 0) {
      p
        ..hp = 0
        ..respawnIn = Balance.respawnSeconds;
      _events.add(GameEvent(GameEventKind.died, playerId: p.id, text: under == TileType.lava ? 'lava' : 'toxic gas'));
    }
  }

  void _hit(SimPlayer p, TilePos t) {
    final pick = p.gear(UpgradeKind.pickaxe);
    p.mineCooldown = pick.cooldown;
    p.stamina -= Balance.staminaPerHit;
    p.miningFlash = 0.25;

    final broken = map.damage(t.x, t.y, pick.stat.toInt());
    final idx = map.indexOf(t.x, t.y);
    _dirtyTiles.add(idx);
    if (broken == null) return;

    if (broken == TileType.treasure) {
      winnerId = p.id;
      p.coins += Balance.treasureBonus;
      p.score += Balance.treasureBonus;
      p.xp += Balance.treasureBonus ~/ 2;
      treasureRevealed = true;
      _events.add(GameEvent(GameEventKind.treasureFound, playerId: p.id, value: Balance.treasureBonus));
      return;
    }
    if (broken.ore case final o?) {
      final v = oreDefs[o]!.value;
      p
        ..coins += v
        ..score += v
        ..xp += v ~/ 2
        ..oresMined += 1;
      _events.add(GameEvent(GameEventKind.oreMined, playerId: p.id, value: o.index));
    }
  }

  // ---- output -------------------------------------------------------------

  List<int> get teamScores {
    if (!hasTeams) return const [];
    final s = List.filled(Balance.teamCount, 0);
    for (final p in players.values) {
      s[p.team] += p.score;
    }
    return s;
  }

  /// Snapshot since the previous call: drains tile changes and events.
  WorldSnapshot takeSnapshot() {
    final hide = !treasureRevealed;
    final tiles = [
      for (final i in _dirtyTiles)
        TileChange(i, map.publicTypeAt(i, hideTreasure: hide).index, map.publicHpAt(i, hideTreasure: hide)),
    ];
    _dirtyTiles.clear();
    final events = List.of(_events);
    _events.clear();
    return WorldSnapshot(
      tick: tick,
      timeLeft: timeLeft,
      players: [for (final p in players.values) p.snapshot()],
      tiles: tiles,
      events: events,
      teamScores: teamScores,
    );
  }

  /// Winner (treasure finder) first, then by coins.
  MatchResult results() {
    final sorted = players.values.toList()
      ..sort((a, b) {
        if (a.id == winnerId) return -1;
        if (b.id == winnerId) return 1;
        return b.score.compareTo(a.score);
      });
    final ts = teamScores;
    var winningTeam = -1;
    final winner = winnerId == null ? null : players[winnerId];
    if (hasTeams) {
      if (winner != null) {
        winningTeam = winner.team;
      } else if (ts.length == 2 && ts[0] != ts[1]) {
        winningTeam = ts[0] > ts[1] ? 0 : 1;
      }
    }
    return MatchResult(
      players: [
        for (var i = 0; i < sorted.length; i++)
          PlayerResult(
            playerId: sorted[i].id,
            name: sorted[i].name,
            isBot: sorted[i].isBot,
            team: sorted[i].team,
            rank: i + 1,
            score: sorted[i].score,
            oresMined: sorted[i].oresMined,
            xp: sorted[i].xp + (i < 3 ? (3 - i) * 25 : 0),
          ),
      ],
      teamScores: ts,
      winningTeam: winningTeam,
      winnerId: winnerId,
    );
  }
}
