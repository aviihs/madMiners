import 'dart:math';

import '../config/balance.dart';
import '../config/cosmetics.dart';
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
  GameSimulation({
    required this.settings,
    required int seed,
    MapGenerator generator = const MapGenerator(),
    this.disguiseBots = true,
    this.warmup = Balance.warmupSeconds,
  }) : _rng = Random(seed),
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
  final List<_Bomb> _bombs = [];

  /// Erupted lava tiles and seconds until they harden.
  final Map<int, double> _cooling = {};

  double timeLeft;
  int tick = 0;

  /// Seconds of surface lobby left. No digging until it hits 0.
  double warmup;
  bool get isWarmup => warmup > 0;

  /// Bots appear to clients as ordinary players with ordinary names.
  /// The server still knows who is a bot (persistence, analytics, moderation).
  final bool disguiseBots;
  double _botJoinIn = 0.6;
  final Map<String, double> _wanderIn = {};

  /// Clients don't learn where the treasure is until a miner's light reaches it.
  bool treasureRevealed = false;
  String? winnerId;

  bool get ended => timeLeft <= 0 || winnerId != null;
  int _botSeq = 0;

  static const _botNames = [
    'Sagar_07', 'Bikash.np', 'Aayush99', 'Pratik', 'Sandesh_K', 'Roshan123', 'Nischal', 'Suman_Dai',
    'Prabin_Gamer', 'Anish77', 'Kushal', 'Rabin_xD', 'Sujan', 'Bibek_NP', 'Saroj', 'Dipesh',
    'Nabin_09', 'Ashish', 'Kiran.B', 'Rojan', 'Samir_OP', 'Pukar', 'Sushant', 'Manish_K',
    'Sabin', 'Ujjwal', 'Aarav', 'Bishal99', 'Ramesh.np', 'Puja_07', 'Anjali', 'Srijana',
    'Kabita_K', 'Asmita', 'Sanjay', 'Prakash.ktm', 'Niraj', 'Sunil_10', 'Ritesh', 'Binod',
    'Aakash', 'Sristi', 'Rupesh', 'Hemant', 'Bipin_04', 'Santosh', 'Gaurav.np', 'Laxman',
  ];

  bool get hasTeams => settings.mode == GameMode.teamHunt;
  int get humanCount => players.values.where((p) => !p.isBot).length;
  int get botCount => _bots.length;

  /// The map as clients may see it (treasure disguised until revealed).
  GameMap publicMap() => GameMap.fromJson(map.toJson(hideTreasure: !treasureRevealed));

  // ---- roster -------------------------------------------------------------

  SimPlayer addHuman(String id, String name, {Look look = Look.standard}) {
    final existing = players[id];
    if (existing != null) return existing;
    final p = _spawnPlayer(id, name, isBot: false)..look = look.sanitized();
    _applyLoadout(p);
    _events.add(GameEvent(GameEventKind.joined, playerId: id, text: name));
    syncBots();
    _botJoinIn = min(_botJoinIn, 0.4);
    return p;
  }

  void removePlayer(String id) {
    final p = players.remove(id);
    if (p == null) return;
    _bots.remove(id);
    final kind = p.isBot && !disguiseBots ? GameEventKind.botLeft : GameEventKind.left;
    _events.add(GameEvent(kind, playerId: id, text: p.name));
    if (!p.isBot) syncBots();
  }

  int get _wantBots => botsNeeded(settings, humanCount);

  /// Removes surplus bots right away. Missing bots trickle in over the next
  /// seconds from [update] (like real players finding the room), unless
  /// [immediate] is set.
  void syncBots({bool immediate = false}) {
    while (_bots.length > _wantBots) {
      // The shallowest bot makes room for the joining human.
      final victim = _bots.keys.map((id) => players[id]!).reduce((a, b) => a.y <= b.y ? a : b);
      removePlayer(victim.id);
    }
    if (immediate) {
      while (_bots.length < _wantBots) {
        _addBot();
      }
    }
  }

  void _addBot() {
    final id = 'p-${(_rng.nextInt(1 << 30) ^ ++_botSeq).toRadixString(36)}';
    final taken = players.values.map((p) => p.name).toSet();
    final free = _botNames.where((n) => !taken.contains(n)).toList();
    final name = free.isEmpty ? 'Miner${_rng.nextInt(900) + 100}' : free[_rng.nextInt(free.length)];
    _applyLoadout(_spawnPlayer(id, name, isBot: true)..look = Look.random(_rng));
    _bots[id] = BotBrain(id, seed: _rng.nextInt(1 << 30));
    _events.add(
      GameEvent(disguiseBots ? GameEventKind.joined : GameEventKind.botJoined, playerId: id, text: name),
    );
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

  /// Miners drop in just above the camp floor.
  (double, double) _spawnPoint() =>
      (map.spawn.cx + (_rng.nextDouble() - 0.5) * 10, MapGenerator.surfaceRows - 1.6 - _rng.nextDouble() * 0.6);

  /// A Locker pickaxe is real gear: you start the match at its level.
  void _applyLoadout(SimPlayer p) {
    final power = p.look.def(CosmeticSlot.pickaxe).power.clamp(0, UpgradeKind.pickaxe.maxLevel);
    final i = UpgradeKind.pickaxe.index;
    if (p.upgrades[i] < power) p.upgrades[i] = power;
  }

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

  /// Buy a consumable at the shop.
  bool buyItem(String id, ItemKind kind) {
    final p = players[id];
    if (p == null || !p.alive || !p.inDepot || ended) return false;
    final def = itemDefs[kind]!;
    if (p.coins < def.cost || p.items[kind.index] >= Balance.maxItemStack) return false;
    p
      ..coins -= def.cost
      ..items[kind.index] += 1;
    _events.add(GameEvent(GameEventKind.itemBought, playerId: id, value: kind.index));
    return true;
  }

  /// Light a bomb and throw it the way you face (facing down drops it at
  /// your feet). Bombs fly, bounce and roll under gravity.
  bool useItem(String id, ItemKind kind) {
    final p = players[id];
    if (p == null || !p.alive || isWarmup || ended || p.items[kind.index] <= 0) return false;
    if (p.inDepot) return false; // no bombing the shop
    if (_bombs.where((b) => b.ownerId == id).length >= Balance.maxActiveBombs) return false;
    p.items[kind.index] -= 1;
    final (vx, vy) = switch ((p.fx, p.fy)) {
      (final fx, _) when fx.abs() > 0.5 => (fx.sign * 6.5 + p.vx * 0.4, -4.5),
      (_, final fy) when fy < -0.5 => (p.vx * 0.3, -9.0),
      _ => (p.vx * 0.2, 0.0),
    };
    _bombs.add(_Bomb(p.x, p.y, kind, itemDefs[kind]!.fuse, p.id)
      ..vx = vx
      ..vy = vy);
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

    // Bots trickle in, faster while the lobby is filling.
    _botJoinIn -= dt;
    if (_bots.length < _wantBots && _botJoinIn <= 0) {
      _addBot();
      _botJoinIn = isWarmup ? 0.25 + _rng.nextDouble() * 0.7 : 1.5 + _rng.nextDouble() * 4;
    }

    if (isWarmup) {
      warmup = max(0, warmup - dt);
      for (final p in players.values) {
        if (_bots.containsKey(p.id)) p.input = _lobbyWander(p, dt);
        _updatePlayer(p, dt);
      }
      return;
    }
    timeLeft = max(0, timeLeft - dt);
    _updateBombs(dt);
    _updateCooling(dt);
    _updateBoulders(dt);
    if (winnerId != null) return;

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
        if (d.buyItem != null) buyItem(p.id, d.buyItem!);
        if (d.useItem != null) useItem(p.id, d.useItem!);
        if (brain.target != null) claimed.add(brain.target!);
      }
      _updatePlayer(p, dt);
      if (winnerId != null) return; // game over the instant it's found
    }
  }

  /// Bots stroll around the camp during the lobby, like people do.
  PlayerInput _lobbyWander(SimPlayer p, double dt) {
    final t = (_wanderIn[p.id] ?? 0) - dt;
    if (t > 0) {
      _wanderIn[p.id] = t;
      return p.input;
    }
    _wanderIn[p.id] = 0.6 + _rng.nextDouble() * 1.8;
    if (_rng.nextDouble() < 0.45) return const PlayerInput();
    final dir = _rng.nextBool() ? 1.0 : -1.0;
    return PlayerInput(dx: dir * (0.4 + _rng.nextDouble() * 0.6), fx: dir, fy: 0, jump: _rng.nextDouble() < 0.25);
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
          ..vx = 0
          ..vy = 0
          ..hp = Balance.maxHealth
          ..stamina = Balance.maxStamina
          ..maxDepth = 0;
        _events.add(GameEvent(GameEventKind.respawned, playerId: p.id));
      }
      return;
    }

    final input = p.connected ? p.input : PlayerInput.idle;

    // Movement: run left/right, jump, climb shafts, fall.
    p.crushCooldown = max(0, p.crushCooldown - dt);
    final speed = Physics.speedFor(p.stamina, boots: p.boots);
    final mv = Physics.move(
      map,
      p.x,
      p.y,
      p.vx,
      p.vy,
      moveX: input.dx,
      speed: speed,
      dt: dt,
      jump: input.jump,
      up: input.up,
      jumpBoost: Physics.jumpBoostFor(p.boots),
    );
    p
      ..x = mv.x
      ..y = mv.y
      ..vx = mv.vx
      ..vy = mv.vy
      ..onGround = mv.onGround;
    if (input.fx != 0 || input.fy != 0) {
      p.fx = input.fx;
      p.fy = input.fy;
    } else if (input.dx.abs() > 0.1) {
      p.fx = input.dx.sign;
      p.fy = 0;
    }
    final fall = Physics.fallDamage(mv.impact);
    if (fall > 0) {
      _hurt(p, fall, 'a long fall', armored: false);
      if (!p.alive) return;
    }
    final depth = max(0, p.y.floor() - MapGenerator.surfaceRows + 1);
    if (depth > p.maxDepth) p.maxDepth = depth;
    if (depth > p.bestDepth) p.bestDepth = depth;

    // Reveal the treasure once someone's helmet light reaches it.
    if (!treasureRevealed) {
      final ddx = treasure.cx - p.x, ddy = treasure.cy - p.y;
      final v = p.vision;
      if (ddx * ddx + ddy * ddy <= v * v) {
        treasureRevealed = true;
        _dirtyTiles.add(map.indexOf(treasure.x, treasure.y));
        _events.add(GameEvent(GameEventKind.treasureRevealed, playerId: p.id));
      }
    }

    // Mining (server validates reach, cooldown and stamina).
    p.mineCooldown = max(0, p.mineCooldown - dt);
    var mined = false;
    if (input.mine && !isWarmup && p.mineCooldown <= 0 && p.stamina >= Balance.staminaPerHit) {
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
    if (under == TileType.lava) _hurt(p, Balance.lavaDamage * dt, 'lava', armored: false);
    if (under == TileType.gas) _hurt(p, Balance.gasDamage * dt, 'toxic gas');
  }

  /// Applies damage; kills (and respawns at the top) at 0 hp.
  void _hurt(SimPlayer p, double amount, String cause, {bool armored = true}) {
    if (!p.alive) return;
    p.hp -= armored ? amount * (1 - p.armor) : amount;
    if (p.hp > 0) return;
    p
      ..hp = 0
      ..respawnIn = Balance.respawnSeconds;
    _events.add(GameEvent(GameEventKind.died, playerId: p.id, text: cause));
  }

  void _kill(SimPlayer p, String cause) => _hurt(p, 9999, cause, armored: false);

  // ---- bombs, volcanoes, lava ------------------------------------------------

  void _updateBombs(double dt) {
    for (final b in _bombs) {
      b.fuse -= dt;
      _moveBomb(b, dt);
    }
    // Explosions can chain, so loop until nothing new goes off.
    while (true) {
      final due = _bombs.where((b) => b.fuse <= 0).toList();
      if (due.isEmpty) break;
      for (final b in due) {
        _bombs.remove(b);
        _explode(b);
      }
    }
  }

  /// Bombs are small, bouncy and fall like everything else.
  void _moveBomb(_Bomb b, double dt) {
    const r = 0.22;
    b.vy = min(b.vy + Balance.gravity * dt, Balance.maxFallSpeed);
    final steps = max(1, ((b.vx.abs() + b.vy.abs()) * dt / 0.15).ceil());
    final h = dt / steps;
    for (var i = 0; i < steps; i++) {
      final nx = b.x + b.vx * h;
      if (Physics.collides(map, nx, b.y, r)) {
        b.vx = -b.vx * 0.35;
      } else {
        b.x = nx;
      }
      final ny = b.y + b.vy * h;
      if (Physics.collides(map, b.x, ny, r)) {
        b.vy = b.vy > 2 ? -b.vy * 0.3 : 0;
        b.vx *= 0.6; // rolls to a stop
      } else {
        b.y = ny;
      }
    }
    if (b.vx.abs() < 0.05) b.vx = 0;
  }

  void _explode(_Bomb b) {
    final def = itemDefs[b.kind]!;
    final owner = players[b.ownerId];
    final r = def.radius;
    _events.add(GameEvent(GameEventKind.explosion, playerId: b.ownerId, value: b.kind.index, x: b.x, y: b.y));

    final cx = b.x.floor(), cy = b.y.floor();
    final ri = r.ceil();
    for (var dy = -ri; dy <= ri; dy++) {
      for (var dx = -ri; dx <= ri; dx++) {
        if (dx * dx + dy * dy > r * r) continue;
        final x = cx + dx, y = cy + dy;
        final t = map.tileAt(x, y);
        if (!t.isMinable) continue;
        if (t == TileType.volcano) {
          _erupt(x, y, culprit: null);
          continue;
        }
        if (t == TileType.treasure) {
          if (map.damage(x, y, 3) != null && owner != null) _treasureFound(owner);
          _dirtyTiles.add(map.indexOf(x, y));
          continue;
        }
        map.damage(x, y, 999);
        _dirtyTiles.add(map.indexOf(x, y));
        if (t.ore case final o? when owner != null) _collect(owner, o);
      }
    }
    if (winnerId != null) return;

    for (final p in players.values) {
      if (!p.alive) continue;
      final dx = p.x - b.x, dy = p.y - b.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d > r + 1.5) continue;
      // The blast throws you, even when it's too far to hurt.
      final push = Balance.blastKnockback * (1 - d / (r + 1.5)) * (b.kind == ItemKind.dynamite ? 1.25 : 1);
      final nx = d < 0.05 ? 0.0 : dx / d, ny = d < 0.05 ? -1.0 : dy / d;
      p
        ..vx += nx * push
        ..vy = min(p.vy, 0) + (ny * 0.6 - 0.5) * push;
      if (d > r + 0.5) continue;
      final falloff = 1 - (d / (r + 0.5)) * 0.5;
      _hurt(p, def.damage * falloff, b.kind == ItemKind.bomb ? 'a bomb' : 'dynamite');
    }
    // Chain reaction; bombs just outside get kicked away.
    for (final other in _bombs) {
      final dx = other.x - b.x, dy = other.y - b.y;
      final d2 = dx * dx + dy * dy;
      if (d2 <= r * r) {
        other.fuse = min(other.fuse, 0.15);
      } else if (d2 <= (r + 2) * (r + 2)) {
        final d = sqrt(d2);
        other
          ..vx += dx / d * 6
          ..vy -= 5;
      }
    }
  }

  /// A hidden volcano breaks open: lava floods the tile and its open
  /// neighbours, the miner who cracked it dies, others nearby get scorched.
  void _erupt(int x, int y, {required SimPlayer? culprit}) {
    void lava(int tx, int ty) {
      map.setTile(tx, ty, TileType.lava);
      final i = map.indexOf(tx, ty);
      _dirtyTiles.add(i);
      _cooling[i] = Balance.lavaCoolSeconds;
    }

    lava(x, y);
    for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
      if (map.tileAt(nx, ny) == TileType.empty) lava(nx, ny);
    }
    _events.add(GameEvent(GameEventKind.volcano, playerId: culprit?.id, x: x + 0.5, y: y + 0.5));
    if (culprit != null) _kill(culprit, 'a volcano');
    for (final p in players.values) {
      if (p == culprit || !p.alive) continue;
      final d = sqrt(pow(p.x - (x + 0.5), 2) + pow(p.y - (y + 0.5), 2));
      if (d <= Balance.volcanoSplashRadius) _hurt(p, Balance.volcanoSplashDamage, 'a volcano');
    }
  }

  void _updateCooling(double dt) {
    final done = <int>[];
    _cooling.updateAll((i, t) => t - dt);
    _cooling.forEach((i, t) {
      if (t > 0) return;
      final x = i % map.width, y = i ~/ map.width;
      // Don't entomb anyone standing in it.
      final occupied = players.values.any((p) => p.alive && p.x.floor() == x && p.y.floor() == y);
      if (occupied) return;
      if (map.tileAt(x, y) == TileType.lava) {
        map.setTile(x, y, TileType.hardRock);
        _dirtyTiles.add(i);
      }
      done.add(i);
    });
    done.forEach(_cooling.remove);
  }

  // ---- boulders ---------------------------------------------------------------

  double _boulderClock = 0;

  /// Unsupported boulders (tile index → seconds they've been loose).
  final Map<int, double> _loose = {};

  /// Loose boulders wobble briefly, then drop one tile per step and crush
  /// any miner below. Falling into lava melts them.
  void _updateBoulders(double dt) {
    _boulderClock += dt;
    if (_boulderClock < Balance.boulderStepSeconds) return;
    final step = _boulderClock;
    _boulderClock = 0;
    final w = map.width;
    final next = <int, double>{};
    // Bottom-up so a stack of boulders falls together.
    for (var y = map.height - 2; y >= 1; y--) {
      for (var x = 1; x < w - 1; x++) {
        if (map.tileAt(x, y) != TileType.boulder) continue;
        final i = map.indexOf(x, y);
        final below = map.tileAt(x, y + 1);
        if (below.isSolid || below == TileType.depot) continue;
        final loose = (_loose[i] ?? 0) + step;
        if (loose < Balance.boulderWobble) {
          next[i] = loose;
          continue;
        }
        if (below == TileType.lava) {
          map.setTile(x, y, TileType.empty);
          _dirtyTiles.add(i);
          continue;
        }
        // Anyone in the way gets hit; the boulder rests on them for now.
        final victims = players.values.where((p) => p.alive && _overlapsTile(p, x, y + 1)).toList();
        if (victims.isNotEmpty) {
          for (final v in victims) {
            if (v.crushCooldown > 0) continue;
            v.crushCooldown = 1.2;
            v.vy = max(v.vy, 4);
            _hurt(v, Balance.boulderDamage, 'a falling boulder', armored: false);
          }
          next[i] = loose;
          continue;
        }
        map.setTile(x, y, TileType.empty);
        map.setTile(x, y + 1, TileType.boulder);
        _dirtyTiles
          ..add(i)
          ..add(i + w);
        next[i + w] = loose;
      }
    }
    _loose
      ..clear()
      ..addAll(next);
  }

  static bool _overlapsTile(SimPlayer p, int x, int y) {
    const r = Balance.playerRadius;
    return p.x + r > x && p.x - r < x + 1 && p.y + r > y && p.y - r < y + 1;
  }

  // ---- hints ------------------------------------------------------------------

  /// Vague "treasure sense" for one miner. Better helmets sense farther.
  /// Never reveals the exact spot.
  TreasureHint hintFor(String id) {
    final p = players[id];
    if (p == null || !p.alive || isWarmup || ended) return TreasureHint.none;
    final dx = treasure.cx - p.x, dy = treasure.cy - p.y;
    final d = sqrt(dx * dx + dy * dy);
    final scale = 1 + p.upgrades[UpgradeKind.helmet.index] * 0.2;
    if (d <= Balance.hintHot * scale) return const TreasureHint(3, 0);
    if (d <= Balance.hintWarm * scale) return TreasureHint(2, dx.abs() < 2.5 ? 0 : dx.sign.toInt());
    if (d <= Balance.hintFaint * scale) return const TreasureHint(1, 0);
    return TreasureHint.none;
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

    if (broken == TileType.treasure) return _treasureFound(p);
    if (broken == TileType.volcano) return _erupt(t.x, t.y, culprit: p);
    if (broken.ore case final o?) _collect(p, o);
  }

  void _collect(SimPlayer p, OreType o) {
    final v = oreDefs[o]!.value;
    p
      ..coins += v
      ..score += v
      ..xp += v ~/ 2
      ..oresMined += 1;
    _events.add(GameEvent(GameEventKind.oreMined, playerId: p.id, value: o.index));
  }

  void _treasureFound(SimPlayer p) {
    if (winnerId != null) return;
    winnerId = p.id;
    p
      ..coins += Balance.treasureBonus
      ..score += Balance.treasureBonus
      ..xp += Balance.treasureBonus ~/ 2;
    treasureRevealed = true;
    _dirtyTiles.add(map.indexOf(treasure.x, treasure.y));
    _events.add(GameEvent(GameEventKind.treasureFound, playerId: p.id, value: Balance.treasureBonus));
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
      players: [for (final p in players.values) p.snapshot(disguise: disguiseBots)],
      tiles: tiles,
      events: events,
      teamScores: teamScores,
      warmup: warmup,
      bombs: [for (final b in _bombs) BombSnapshot(b.x, b.y, b.kind, b.fuse)],
    );
  }

  /// Winner (treasure finder) first, then by coins.
  ///
  /// Pass [forClients] for anything sent over the wire (bots disguised).
  MatchResult results({bool forClients = false}) {
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
            isBot: sorted[i].isBot && !(forClients && disguiseBots),
            team: sorted[i].team,
            rank: i + 1,
            score: sorted[i].score,
            oresMined: sorted[i].oresMined,
            xp: sorted[i].xp + (i < 3 ? (3 - i) * 25 : 0),
            maxDepth: sorted[i].bestDepth,
          ),
      ],
      teamScores: ts,
      winningTeam: winningTeam,
      winnerId: winnerId,
    );
  }
}

class _Bomb {
  _Bomb(this.x, this.y, this.kind, this.fuse, this.ownerId);
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  final ItemKind kind;
  double fuse;
  final String ownerId;
}
