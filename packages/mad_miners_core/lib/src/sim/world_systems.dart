part of 'game_simulation.dart';

/// A monster roaming the caves. Server-only state.
class _Monster {
  _Monster(this.id, this.kind, this.x, this.y) : hp = monsterDefs[kind]!.hp;
  final int id;
  final MonsterKind kind;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  double hp;
  double attackCd = 0;
  double attackFlash = 0;
  double fleeFor = 0;
  double idleFor = 0;
  double dir = 1;
  bool left = false;
  String? lastHitBy;

  MonsterDef get def => monsterDefs[kind]!;
}

/// A cracked Mystery Bomb counting down to its reveal.
class _Opening {
  _Opening(this.x, this.y, this.openerId, this.rarity, this.t);
  final double x;
  final double y;
  final String? openerId;
  final MysteryRarity rarity;
  double t;
}

/// Mystery Bombs, monsters and world events. Everything random here uses
/// the server's RNG: clients only ever see the outcome.
extension _WorldSystems on GameSimulation {
  // ---- setup -------------------------------------------------------------------

  void _initWorld() {
    final lavaTop = map.height - 1 - settings.mapId.def.lavaRows;
    for (var i = 0; i < map.width * map.height; i++) {
      if (map.tileAtIndex(i) != TileType.mystery) continue;
      final y = i ~/ map.width;
      _rarity[i] = _rollRarity((y - MapGenerator.surfaceRows) / (lavaTop - MapGenerator.surfaceRows));
    }
    // Monsters start on cave floors in the lower part of the mine.
    var placed = 0, tries = 0;
    while (placed < settings.mapId.def.monsters && tries++ < 4000) {
      final x = 2 + _rng.nextInt(map.width - 4);
      final y = MapGenerator.surfaceRows + 8 + _rng.nextInt(max(1, lavaTop - MapGenerator.surfaceRows - 12));
      if (map.tileAt(x, y) != TileType.empty || !map.isSolid(x, y + 1)) continue;
      final d = (y - MapGenerator.surfaceRows) / (lavaTop - MapGenerator.surfaceRows);
      _spawnMonster(d > 0.5 && _rng.nextDouble() < 0.4 ? MonsterKind.golem : MonsterKind.spider, x + 0.5, y + 0.6);
      placed++;
    }
    _nextEventIn = 45 + _rng.nextDouble() * 30;
  }

  MysteryRarity _rollRarity(double d) {
    final w = [50.0, 28 + 20 * d, 14 + 20 * d, 6 + 10 * d, 2 + 6 * d];
    var roll = _rng.nextDouble() * w.reduce((a, b) => a + b);
    for (var i = 0; i < w.length; i++) {
      roll -= w[i];
      if (roll <= 0) return MysteryRarity.values[i];
    }
    return MysteryRarity.common;
  }

  void _spawnMonster(MonsterKind kind, double x, double y) {
    if (_monsters.length >= Balance.maxMonsters) return;
    _monsters.add(_Monster(++_monsterSeq, kind, x, y)..dir = _rng.nextBool() ? 1 : -1);
  }

  // ---- mystery bombs -----------------------------------------------------------

  /// Someone broke (or blasted) a Mystery Bomb: it starts to shake.
  void _crackMystery(int x, int y, String? openerId) {
    final i = map.indexOf(x, y);
    map.setTile(x, y, TileType.empty);
    _dirtyTiles.add(i);
    final rarity = _rarity.remove(i) ?? MysteryRarity.common;
    _openings.add(_Opening(x + 0.5, y + 0.5, openerId, rarity, Balance.mysteryOpenSeconds));
    _events.add(GameEvent(GameEventKind.mysteryFound, playerId: openerId, x: x + 0.5, y: y + 0.5));
  }

  void _updateOpenings(double dt) {
    for (final o in _openings.toList()) {
      o.t -= dt;
      if (o.t > 0) continue;
      _openings.remove(o);
      _revealMystery(o);
    }
  }

  void _award(SimPlayer p, int coins) {
    p
      ..coins += coins
      ..score += coins
      ..xp += coins ~/ 2;
  }

  void _revealMystery(_Opening o) {
    final p = o.openerId == null ? null : players[o.openerId];
    final r = o.rarity;
    final weights = <MysteryReward, double>{
      MysteryReward.goldShower: 26,
      MysteryReward.diamondBurst: 14,
      MysteryReward.crystals: 12,
      MysteryReward.jackpot: 2 + r.index * 2.5,
      MysteryReward.energy: 10,
      MysteryReward.explosives: 10,
      MysteryReward.monster: max(2, 9 - r.index * 2).toDouble(),
      MysteryReward.prank: 8,
      MysteryReward.cursed: 7,
    };
    var roll = _rng.nextDouble() * weights.values.reduce((a, b) => a + b);
    var reward = MysteryReward.goldShower;
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll <= 0) {
        reward = e.key;
        break;
      }
    }

    var text = reward.label;
    int coins = 0, gems = 0;
    switch (reward) {
      case MysteryReward.goldShower:
        coins = ((40 + _rng.nextInt(60)) * r.mult).round();
      case MysteryReward.diamondBurst:
        coins = ((90 + _rng.nextInt(90)) * r.mult).round();
      case MysteryReward.crystals:
        gems = ((2 + _rng.nextInt(3)) * r.mult).round();
      case MysteryReward.jackpot:
        coins = (400 * r.mult).round();
        gems = (10 * r.mult).round();
      case MysteryReward.energy:
        if (p != null) {
          p
            ..hp = Balance.maxHealth
            ..stamina = Balance.maxStamina
            ..fuel = Balance.jetFuelMax;
        }
        text = 'Energy Refill: full health, stamina and fuel';
      case MysteryReward.explosives:
        if (p != null) {
          p.items[ItemKind.bomb.index] = min(Balance.maxItemStack, p.items[ItemKind.bomb.index] + 2);
          p.items[ItemKind.dynamite.index] = min(Balance.maxItemStack, p.items[ItemKind.dynamite.index] + 1);
        }
        text = 'Explosives Cache: +2 bombs, +1 dynamite';
      case MysteryReward.monster:
        // Readable warning: it pops out where the bomb was, not on top of you.
        _spawnMonster(r.index >= MysteryRarity.epic.index ? MonsterKind.golem : MonsterKind.spider, o.x, o.y);
        coins = (20 * r.mult).round();
      case MysteryReward.prank:
        if (p != null) {
          p
            ..slimed = 5
            ..vy = min(p.vy, -5);
        }
        text = 'Slime Prank! (slow for 5s, no harm done)';
      case MysteryReward.cursed:
        coins = (150 * r.mult).round();
        if (p != null) p.cursed = 20;
    }
    if (p != null) {
      if (coins > 0) _award(p, coins);
      p
        ..bonusGems += gems
        ..mysteriesOpened += 1
        ..xp += (20 * r.mult).round();
    }
    if (coins > 0 || gems > 0) {
      text = '${reward.label}: ${[if (coins > 0) '+$coins coins', if (gems > 0) '+$gems gems'].join(', ')}';
      if (reward == MysteryReward.cursed) text += ' (cursed: slow digging for 20s)';
    }
    _events.add(GameEvent(
      GameEventKind.mysteryOpened,
      playerId: p?.id,
      value: r.index * 100 + reward.index,
      text: text,
      x: o.x,
      y: o.y,
    ));
  }

  // ---- monsters ------------------------------------------------------------------

  void _updateMonsters(double dt) {
    for (final m in _monsters.toList()) {
      final def = m.def;
      m
        ..attackCd = max(0, m.attackCd - dt)
        ..attackFlash = max(0, m.attackFlash - dt)
        ..fleeFor = max(0, m.fleeFor - dt)
        ..idleFor = max(0, m.idleFor - dt);

      SimPlayer? target;
      var best = def.sense;
      for (final p in players.values) {
        if (!p.alive || (p.y - m.y).abs() > 3) continue;
        final d = sqrt(pow(p.x - m.x, 2) + pow(p.y - m.y, 2));
        if (d < best) {
          best = d;
          target = p;
        }
      }

      var moveX = 0.0;
      var jump = false;
      final grounded = Physics.onGround(map, m.x, m.y);
      if (target != null && m.fleeFor > 0) {
        moveX = -(target.x - m.x).sign; // retreat
      } else if (target != null) {
        final dx = target.x - m.x;
        final reach = m.kind == MonsterKind.golem ? 1.15 : 0.95;
        if (best < reach) {
          if (m.attackCd <= 0) {
            m
              ..attackCd = def.attackEvery
              ..attackFlash = 0.3;
            target
              ..vx += dx.sign * (m.kind == MonsterKind.golem ? 8 : 4)
              ..vy = min(target.vy, -3.5);
            _hurt(target, def.damage, 'a ${def.name}');
          }
        } else {
          moveX = dx.sign;
        }
      } else if (m.idleFor <= 0) {
        // Patrol: walk, turn at walls and ledges, sometimes stop and look around.
        final ahead = (m.x + m.dir * 0.6).floor(), row = m.y.floor();
        if (map.isSolid(ahead, row) || !map.isSolid(ahead, row + 1)) m.dir = -m.dir;
        moveX = m.dir * 0.45;
        if (_rng.nextDouble() < dt * 0.15) m.idleFor = 1 + _rng.nextDouble() * 2;
      }
      if (moveX != 0 && grounded && Physics.collides(map, m.x + moveX.sign * 0.4, m.y)) jump = m.kind == MonsterKind.spider || _rng.nextDouble() < 0.3;
      if (moveX != 0) m.left = moveX < 0;

      final mv = Physics.move(map, m.x, m.y, m.vx, m.vy, moveX: moveX, speed: def.speed, dt: dt, jump: jump);
      m
        ..x = mv.x
        ..y = mv.y
        ..vx = mv.vx
        ..vy = mv.vy;
      if (map.tileAt(m.x.floor(), m.y.floor()) == TileType.lava) _monsters.remove(m); // melts, no loot
    }
  }

  /// A swing at whatever monster is in front of [p]. True if it connected.
  bool _swingAtMonster(SimPlayer p) {
    final hx = p.x + p.fx * 0.8, hy = p.y + p.fy * 0.8;
    for (final m in _monsters) {
      if ((m.x - hx).abs() < 0.75 && (m.y - hy).abs() < 0.85) {
        final pick = p.gear(UpgradeKind.pickaxe);
        p
          ..mineCooldown = pick.cooldown * (p.cursed > 0 ? 1.6 : 1)
          ..stamina -= Balance.staminaPerHit
          ..miningFlash = 0.25;
        m
          ..vx += p.fx * 5
          ..vy = min(m.vy, -2.5);
        _damageMonster(m, Balance.monsterHitBase + pick.stat * Balance.monsterHitPerStat, p.id);
        return true;
      }
    }
    return false;
  }

  void _damageMonster(_Monster m, double amount, String? by) {
    if (!_monsters.contains(m)) return;
    m.hp -= amount;
    if (by != null) m.lastHitBy = by;
    if (m.kind == MonsterKind.spider && m.hp > 0 && m.hp < m.def.hp * 0.35) m.fleeFor = 2;
    if (m.hp > 0) return;
    _monsters.remove(m);
    final killer = m.lastHitBy == null ? null : players[m.lastHitBy];
    if (killer != null) {
      _award(killer, m.def.loot);
      killer.monstersKilled++;
    }
    _events.add(GameEvent(GameEventKind.monsterKilled, playerId: killer?.id, value: m.kind.index, x: m.x, y: m.y));
  }

  /// Bots defend themselves: a monster in arm's reach gets the pickaxe.
  PlayerInput? _botSelfDefence(SimPlayer p) {
    for (final m in _monsters) {
      if ((m.x - p.x).abs() < 1.4 && (m.y - p.y).abs() < 0.9) {
        return PlayerInput(fx: (m.x - p.x).sign, fy: 0, mine: true);
      }
    }
    return null;
  }

  // ---- world events ----------------------------------------------------------------

  void _updateWorldEvent(double dt) {
    final ev = worldEvent;
    if (ev != null) {
      worldEventLeft -= dt;
      if (ev == WorldEventKind.earthquake) {
        _quakeClock += dt;
        if (_quakeClock >= 0.5) {
          _quakeClock = 0;
          for (final p in players.values) {
            if (p.alive && p.y > MapGenerator.surfaceRows + 2 && _rng.nextDouble() < 0.3) _dropRockAbove(p);
          }
        }
      }
      if (worldEventLeft <= 0) {
        worldEvent = null;
        _events.add(GameEvent(GameEventKind.worldEventEnded, value: ev.index));
      }
      return;
    }
    _nextEventIn -= dt;
    if (_nextEventIn > 0 || timeLeft < 30) return;
    _nextEventIn = Balance.eventGapMin + _rng.nextDouble() * (Balance.eventGapMax - Balance.eventGapMin);
    final kind = WorldEventKind.values[_rng.nextInt(WorldEventKind.values.length)];
    worldEvent = kind;
    worldEventLeft = kind.seconds;
    _events.add(GameEvent(GameEventKind.worldEvent, value: kind.index, text: kind.label));
    if (kind == WorldEventKind.mysteryRain) {
      _mysteryRain();
    } else {
      _startHazardEvent(kind);
    }
  }

  /// Earthquake: a chunk of ceiling above a miner turns into a falling rock.
  void _dropRockAbove(SimPlayer p) {
    final x = p.x.floor();
    for (var y = p.y.floor() - 2; y > p.y.floor() - 7 && y > MapGenerator.surfaceRows; y--) {
      if (map.isSolid(x, y)) {
        final t = map.tileAt(x, y);
        if (t == TileType.rock || t == TileType.dirt || t == TileType.hardRock) {
          map.setTile(x, y, TileType.boulder);
          _dirtyTiles.add(map.indexOf(x, y));
        }
        return;
      }
    }
  }

  void _mysteryRain() {
    final lavaTop = map.height - 1 - settings.mapId.def.lavaRows;
    final alive = players.values.where((p) => p.alive).toList();
    var placed = 0, tries = 0;
    while (placed < 4 && tries++ < 400 && alive.isNotEmpty) {
      final p = alive[_rng.nextInt(alive.length)];
      final x = (p.x + _rng.nextInt(17) - 8).floor(), y = (p.y + _rng.nextInt(11) - 3).floor();
      if (y <= MapGenerator.surfaceRows + 1 || y >= lavaTop - 1 || (x - p.x).abs() + (y - p.y).abs() < 3) continue;
      final t = map.tileAt(x, y);
      if (t != TileType.rock && t != TileType.hardRock && t != TileType.dirt) continue;
      map.setTile(x, y, TileType.mystery);
      final i = map.indexOf(x, y);
      _dirtyTiles.add(i);
      _rarity[i] = _rollRarity((y - MapGenerator.surfaceRows) / (lavaTop - MapGenerator.surfaceRows));
      placed++;
    }
  }
}
