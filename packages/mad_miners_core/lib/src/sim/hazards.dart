part of 'game_simulation.dart';

/// Hidden hazards and traps: TNT, launchers, pressure plates, chests, the
/// sealed treasure chamber, flowing water and lava, and what gets revealed
/// to clients when. All outcomes are decided here, on the server.
extension _Hazards on GameSimulation {
  // ---- reveals --------------------------------------------------------------------

  /// Opened tiles expose hidden neighbours; miners notice floor traps they
  /// walk close to. Emits one "hazard revealed" event per discovery.
  void _processReveals() {
    final revealed = <int>[];
    for (final i in _dirtyTiles.toList()) {
      if (!map.tileAtIndex(i).isSolid && !map.isHidden(i)) revealed.addAll(map.exposeAround(i % map.width, i ~/ map.width));
    }
    for (final p in players.values) {
      if (p.alive) revealed.addAll(map.revealNear(p.x, p.y, Balance.revealRadius));
    }
    if (revealed.isEmpty) return;
    _dirtyTiles.addAll(revealed);
    final seen = <TileType>{};
    for (final i in revealed) {
      final t = map.tileAtIndex(i);
      final notable = t == TileType.lava || t == TileType.water || t == TileType.gas || t == TileType.obsidian || t.tnt != null || t.isFloorDevice;
      if (!notable || !seen.add(t == TileType.lava || t == TileType.water ? t : (t.tnt != null ? TileType.explosive : t))) continue;
      final x = i % map.width + 0.5, y = i ~/ map.width + 0.5;
      _events.add(GameEvent(GameEventKind.hazardRevealed, playerId: _nearestPlayer(x, y)?.id, value: t.index, x: x, y: y));
    }
  }

  SimPlayer? _nearestPlayer(double x, double y) {
    SimPlayer? best;
    var bd = double.infinity;
    for (final p in players.values) {
      if (!p.alive) continue;
      final d = pow(p.x - x, 2) + pow(p.y - y, 2).toDouble();
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }

  void _revealTile(int x, int y) {
    final i = map.indexOf(x, y);
    if (map.reveal(i)) _dirtyTiles.add(i);
  }

  // ---- TNT ---------------------------------------------------------------------------

  /// Lights a TNT block. It goes off exactly [Balance.tntFuseTicks] server
  /// ticks later, whatever happens in between.
  void _activateTnt(int x, int y, TntKind kind, String? by) {
    final i = map.indexOf(x, y);
    if (map.tileAtIndex(i).tnt != null) {
      map.setTile(x, y, TileType.empty);
      _dirtyTiles.add(i);
    }
    _bombs.add(_Bomb(x + 0.5, y + 0.5, ItemKind.dynamite, Balance.tntFuseTicks / Balance.tickRate, by ?? '', kind.blast)
      ..tnt = kind
      ..dueTick = tick + Balance.tntFuseTicks);
    _events.add(GameEvent(GameEventKind.tntActivated, playerId: by, value: kind.index, x: x + 0.5, y: y + 0.5));
  }

  /// Unstable TNT goes off when a miner even walks next to it.
  void _checkUnstable(SimPlayer p) {
    final cx = p.x.floor(), cy = p.y.floor();
    for (var y = cy - 1; y <= cy + 1; y++) {
      for (var x = cx - 1; x <= cx + 1; x++) {
        if (map.tileAt(x, y) == TileType.tntUnstable) _activateTnt(x, y, TntKind.unstable, p.id);
      }
    }
  }

  /// After a TNT blast: chain TNT lights its neighbours, treasure TNT leaves
  /// rare ore in the walls.
  void _afterTnt(_Bomb b) {
    final kind = b.tnt;
    if (kind == null) return;
    final cx = b.x.floor(), cy = b.y.floor();
    if (kind == TntKind.chain) {
      final reach = (kind.blast.radius + 2.5).ceil();
      for (var y = cy - reach; y <= cy + reach; y++) {
        for (var x = cx - reach; x <= cx + reach; x++) {
          final t = map.tileAt(x, y);
          if (t.tnt != null) _activateTnt(x, y, t.tnt!, b.ownerId.isEmpty ? null : b.ownerId);
        }
      }
    }
    if (kind == TntKind.treasure) {
      const loot = [TileType.gold, TileType.emerald, TileType.ruby, TileType.diamond, TileType.moneyBag, TileType.silver];
      var placed = 0;
      for (var tries = 0; tries < 60 && placed < 4; tries++) {
        final x = cx + _rng.nextInt(7) - 3, y = cy + _rng.nextInt(7) - 3;
        final t = map.tileAt(x, y);
        if (t != TileType.rock && t != TileType.hardRock && t != TileType.dirt) continue;
        map.setTile(x, y, loot[_rng.nextInt(loot.length)]);
        _dirtyTiles.add(map.indexOf(x, y));
        placed++;
      }
    }
  }

  // ---- launchers and pressure plates -----------------------------------------------

  /// Tiles a miner is standing in or on.
  Iterable<int> _touching(SimPlayer p) sync* {
    final x = p.x.floor();
    yield map.indexOf(x, p.y.floor());
    final feet = (p.y + Balance.playerRadius - 0.05).floor();
    if (feet != p.y.floor()) yield map.indexOf(x, feet);
  }

  void _checkTraps(SimPlayer p) {
    for (final i in _touching(p)) {
      if (!map.inBounds(i % map.width, i ~/ map.width)) continue;
      final t = map.tileAtIndex(i);
      final x = i % map.width, y = i ~/ map.width;
      if (t.isLauncher && !_launchArm.containsKey(i) && (_launchCd[i] ?? 0) <= 0) {
        _revealTile(x, y);
        _launchArm[i] = Balance.launcherWarning;
        _events.add(GameEvent(GameEventKind.launcherArmed, playerId: p.id, value: t.launch!.index, x: x + 0.5, y: y + 0.5));
      } else if (t == TileType.plate && (_plateCd[i] ?? 0) <= 0) {
        _revealTile(x, y);
        _plateCd[i] = Balance.plateCooldown;
        _springPlate(x, y, p);
      } else if (t == TileType.spikes) {
        _revealTile(x, y);
      }
    }
  }

  void _updateTraps(double dt) {
    _launchCd.updateAll((_, v) => v - dt);
    _launchCd.removeWhere((_, v) => v <= 0);
    _plateCd.updateAll((_, v) => v - dt);
    _plateCd.removeWhere((_, v) => v <= 0);
    for (final i in _launchArm.keys.toList()) {
      final left = _launchArm[i]! - dt;
      if (left > 0) {
        _launchArm[i] = left;
        continue;
      }
      _launchArm.remove(i);
      _fireLauncher(i);
    }
    // The sealed treasure chamber opens when a miner gets close.
    final door = _chamberDoor;
    if (door != null && map.tileAtIndex(door) == TileType.ancientDoor) {
      final dx = door % map.width + 0.5, dy = door ~/ map.width + 0.5;
      final near = players.values.where((p) => p.alive && pow(p.x - dx, 2) + pow(p.y - dy, 2) <= pow(Balance.chamberOpenRadius, 2)).firstOrNull;
      if (near != null) {
        map.setTile(door % map.width, door ~/ map.width, TileType.empty);
        _dirtyTiles.add(door);
        _events.add(GameEvent(GameEventKind.chamberOpened, playerId: near.id, x: dx, y: dy));
      }
    }
  }

  void _fireLauncher(int i) {
    final t = map.tileAtIndex(i);
    var kind = t.launch;
    if (kind == null) return; // destroyed while clicking
    if (kind == LaunchKind.random) kind = LaunchKind.values[_rng.nextInt(LaunchKind.values.length - 1)];
    _launchCd[i] = Balance.launcherCooldown;
    final x = i % map.width, y = i ~/ map.width;
    // Straight-up pads add a sideways kick so you don't land back on them.
    final drift = kind.vx == 0 ? (_rng.nextBool() ? 1.0 : -1.0) * (4 + _rng.nextDouble() * 2) : 0.0;
    bool onPad(double px, double py) => px > x - 0.2 && px < x + 1.2 && py > y - 0.6 && py < y + 1.2;
    for (final p in players.values) {
      if (!p.alive || !onPad(p.x, p.y)) continue;
      p
        ..vx = kind.vx + drift
        ..vy = kind.vy
        ..launched = 2;
    }
    for (final m in _monsters) {
      if (!onPad(m.x, m.y)) continue;
      m
        ..vx = kind.vx
        ..vy = kind.vy;
    }
    _events.add(GameEvent(GameEventKind.launcherFired, value: kind.index, x: x + 0.5, y: y + 0.5));
  }

  void _springPlate(int x, int y, SimPlayer p) {
    final trap = _plateTrap.putIfAbsent(map.indexOf(x, y), () => PlateTrap.values[_rng.nextInt(PlateTrap.values.length)]);
    _events.add(GameEvent(GameEventKind.plateTriggered, playerId: p.id, value: trap.index, x: x + 0.5, y: y + 0.5));
    switch (trap) {
      case PlateTrap.collapse:
        _collapse(x, y, 3);
      case PlateTrap.spikes:
        for (var ty = y - 1; ty <= y + 1; ty++) {
          for (var tx = x - 3; tx <= x + 3; tx++) {
            if (tx == x && ty == y) continue;
            if (map.tileAt(tx, ty) == TileType.empty && map.isSolid(tx, ty + 1)) {
              map.setTile(tx, ty, TileType.spikes);
              _dirtyTiles.add(map.indexOf(tx, ty));
            }
          }
        }
      case PlateTrap.tnt:
        // A TNT block drops from the ceiling.
        var ty = y;
        while (ty > y - 3 && !map.isSolid(x, ty - 1)) {
          ty--;
        }
        _activateTnt(x, ty, TntKind.basic, null);
    }
  }

  /// Ceilings above columns x-r..x+r turn into falling rocks.
  void _collapse(int x, int y, int r) {
    for (var cx = x - r; cx <= x + r; cx++) {
      for (var cy = y - 1; cy > y - 7 && cy > MapGenerator.surfaceRows; cy--) {
        if (!map.isSolid(cx, cy)) continue;
        final t = map.tileAt(cx, cy);
        if (t == TileType.rock || t == TileType.dirt || t == TileType.hardRock) {
          map.setTile(cx, cy, TileType.boulder);
          _dirtyTiles.add(map.indexOf(cx, cy));
        }
        break;
      }
    }
  }

  // ---- chests ---------------------------------------------------------------------------

  void _openChest(int x, int y, SimPlayer? p) {
    final coins = 40 + _rng.nextInt(81);
    final gems = _rng.nextDouble() < 0.15 ? 2 : 0;
    if (p != null) {
      _award(p, coins);
      p.bonusGems += gems;
    }
    _events.add(GameEvent(GameEventKind.chestOpened, playerId: p?.id, value: coins, text: gems > 0 ? '+$gems gems' : null, x: x + 0.5, y: y + 0.5));
  }

  // ---- fluids -----------------------------------------------------------------------------

  /// Water and lava (above the lava sea) run downhill one tile per step and
  /// spread out when piled up. Where they meet, lava turns into obsidian.
  void _updateFluids(double dt) {
    _fluidClock += dt;
    if (_fluidClock < Balance.fluidStepSeconds) return;
    _fluidClock = 0;
    final lavaTop = map.height - 1 - settings.mapId.def.lavaRows;
    final moved = <int>{};
    final leftFirst = tick.isEven;
    bool open(TileType t) => t == TileType.empty || t == TileType.gas;

    void move(int from, int to, TileType f) {
      map.setTile(from % map.width, from ~/ map.width, TileType.empty);
      map.setTile(to % map.width, to ~/ map.width, f);
      _dirtyTiles
        ..add(from)
        ..add(to);
      moved.add(to);
      final c = _cooling.remove(from);
      if (c != null) _cooling[to] = c;
    }

    for (var y = lavaTop - 1; y > MapGenerator.surfaceRows; y--) {
      for (var k = 1; k < map.width - 1; k++) {
        final x = leftFirst ? k : map.width - 1 - k;
        final i = map.indexOf(x, y);
        final f = map.tileAtIndex(i);
        if (!f.isFluid || moved.contains(i) || map.isHidden(i)) continue;
        if (open(map.tileAt(x, y + 1))) {
          move(i, i + map.width, f);
          continue;
        }
        // Spread sideways off a ledge, or when more fluid presses from above.
        final pressed = map.tileAt(x, y - 1).isFluid;
        for (final dx in leftFirst ? const [-1, 1] : const [1, -1]) {
          if (!open(map.tileAt(x + dx, y))) continue;
          if (pressed || open(map.tileAt(x + dx, y + 1))) {
            move(i, map.indexOf(x + dx, y), f);
            break;
          }
        }
      }
    }
    // Water meets lava: the lava cools to obsidian, the water boils away.
    for (final i in moved) {
      final x = i % map.width, y = i ~/ map.width;
      final f = map.tileAtIndex(i);
      if (!f.isFluid) continue;
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        final n = map.tileAt(nx, ny);
        if (!n.isFluid || n == f || ny >= lavaTop) continue;
        final lavaAt = f == TileType.lava ? (x, y) : (nx, ny);
        final waterAt = f == TileType.water ? (x, y) : (nx, ny);
        map.setTile(lavaAt.$1, lavaAt.$2, TileType.obsidian);
        map.setTile(waterAt.$1, waterAt.$2, TileType.empty);
        _dirtyTiles
          ..add(map.indexOf(lavaAt.$1, lavaAt.$2))
          ..add(map.indexOf(waterAt.$1, waterAt.$2));
        break;
      }
    }
  }

  // ---- new world events -----------------------------------------------------------------

  SimPlayer? _randomDeepPlayer() {
    final deep = players.values.where((p) => p.alive && p.y > MapGenerator.surfaceRows + 4).toList();
    return deep.isEmpty ? null : deep[_rng.nextInt(deep.length)];
  }

  void _startHazardEvent(WorldEventKind kind) {
    final p = _randomDeepPlayer();
    if (p == null) return;
    final px = p.x.floor(), py = p.y.floor();
    final lavaTop = map.height - 1 - settings.mapId.def.lavaRows;
    bool plain(TileType t) => t == TileType.rock || t == TileType.hardRock || t == TileType.dirt;

    switch (kind) {
      case WorldEventKind.caveCollapse:
        _collapse(px, py, 4);
      case WorldEventKind.lavaBreakthrough:
        // A pocket of lava bursts out of the wall a few tiles above-side.
        final side = _rng.nextBool() ? 1 : -1;
        for (var dy = 0; dy < 2; dy++) {
          for (var dx = 0; dx < 2; dx++) {
            final x = px + side * (3 + dx), y = py - 4 + dy;
            if (y > MapGenerator.surfaceRows + 1 && y < lavaTop && plain(map.tileAt(x, y))) {
              map.setTile(x, y, TileType.lava);
              _dirtyTiles.add(map.indexOf(x, y));
            }
          }
        }
        // Break the rock between it and the tunnel so it actually flows.
        final x = px + side * 2, y = py - 3;
        if (plain(map.tileAt(x, y))) {
          map.setTile(x, y, TileType.empty);
          _dirtyTiles.add(map.indexOf(x, y));
        }
      case WorldEventKind.rareOreSurge:
        const ores = [TileType.gold, TileType.emerald, TileType.ruby, TileType.diamond, TileType.silver];
        var n = 0;
        for (var tries = 0; tries < 200 && n < 7; tries++) {
          final x = px + _rng.nextInt(13) - 6, y = py + _rng.nextInt(9) - 4;
          if (y >= lavaTop - 1 || !plain(map.tileAt(x, y))) continue;
          map.setTile(x, y, ores[_rng.nextInt(ores.length)]);
          _dirtyTiles.add(map.indexOf(x, y));
          n++;
        }
      case WorldEventKind.monsterInvasion:
        var n = 0;
        for (var tries = 0; tries < 400 && n < 4; tries++) {
          final x = px + _rng.nextInt(21) - 10, y = py + _rng.nextInt(9) - 4;
          if ((x - px).abs() < 5 || map.tileAt(x, y) != TileType.empty || !map.isSolid(x, y + 1)) continue;
          _spawnMonster(_rng.nextDouble() < 0.3 ? MonsterKind.golem : MonsterKind.spider, x + 0.5, y + 0.6);
          n++;
        }
      case WorldEventKind.tntChain:
        var n = 0;
        for (var r = 4; r <= 12 && n < 3; r++) {
          for (var y = py - r; y <= py + r && n < 3; y++) {
            for (var x = px - r; x <= px + r && n < 3; x++) {
              if ((x - px).abs() != r && (y - py).abs() != r) continue;
              final t = map.tileAt(x, y);
              if (t.tnt != null) {
                _activateTnt(x, y, t.tnt!, null);
                n++;
              }
            }
          }
        }
        // No TNT around? Some appears in the rock and lights up anyway.
        for (var tries = 0; tries < 200 && n < 2; tries++) {
          final x = px + _rng.nextInt(15) - 7, y = py + _rng.nextInt(9) - 4;
          if ((x - px).abs() + (y - py).abs() < 5 || !plain(map.tileAt(x, y))) continue;
          _activateTnt(x, y, TntKind.basic, null);
          n++;
        }
      case WorldEventKind.hiddenTreasure:
        var n = 0;
        for (var tries = 0; tries < 200 && n < 2; tries++) {
          final x = px + _rng.nextInt(17) - 8, y = py + _rng.nextInt(9) - 4;
          if ((x - px).abs() + (y - py).abs() < 4 || y >= lavaTop - 1 || !plain(map.tileAt(x, y))) continue;
          map.setTile(x, y, TileType.chest);
          _dirtyTiles.add(map.indexOf(x, y));
          n++;
        }
      default:
        break;
    }
  }
}
