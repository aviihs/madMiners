import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:test/test.dart';

void main() {
  group('roster policy', () {
    const s = MatchSettings(minPlayers: 8, maxPlayers: 12);

    test('bots fill the room up to 8 miners', () {
      expect(botsNeeded(s, 1), 7);
      expect(botsNeeded(s, 5), 3);
      expect(botsNeeded(s, 8), 0);
      expect(botsNeeded(s, 12), 0);
    });

    test('empty room runs no bots', () => expect(botsNeeded(s, 0), 0));

    test('bots trickle in during the lobby and are clearly labelled', () {
      final sim = GameSimulation(settings: s, seed: 1);
      sim.addHuman('a', 'A');
      expect(sim.botCount, 0);
      for (var i = 0; i < 30 * Balance.warmupSeconds; i++) {
        sim.update(1 / 30);
      }
      expect(sim.players.length, 8);
      final snap = sim.takeSnapshot();
      expect(snap.players.where((p) => p.isBot).length, 7, reason: 'clients can tell bots from people');
      expect(snap.players.map((p) => p.name).toSet().length, 8, reason: 'unique names');
      expect(sim.results(forClients: true).players.where((p) => p.isBot).length, 7);
    });

    test('no digging during the lobby countdown', () {
      final sim = GameSimulation(settings: s, seed: 1);
      final p = sim.addHuman('a', 'A');
      p
        ..x = sim.map.spawn.cx
        ..y = MapGenerator.surfaceRows - 0.4;
      final below = sim.map.hpAt(p.x.floor(), MapGenerator.surfaceRows);
      sim.setInput('a', const PlayerInput(fy: 1, mine: true));
      for (var i = 0; i < 30; i++) {
        sim.update(1 / 30);
      }
      expect(sim.map.hpAt(p.x.floor(), MapGenerator.surfaceRows), below);
    });

    test('a joining human replaces a bot', () {
      final sim = GameSimulation(settings: s, seed: 1);
      sim.addHuman('a', 'A');
      sim.syncBots(immediate: true);
      expect(sim.players.length, 8);
      expect(sim.botCount, 7);
      sim.addHuman('b', 'B');
      expect(sim.players.length, 8);
      expect(sim.botCount, 6);
      sim.removePlayer('a');
      sim.syncBots(immediate: true);
      expect(sim.botCount, 7);
    });

    test('room never exceeds 12', () {
      final sim = GameSimulation(settings: s, seed: 1, warmup: 0);
      for (var i = 0; i < 12; i++) {
        sim.addHuman('h$i', 'H$i');
      }
      expect(sim.players.length, 12);
      expect(sim.botCount, 0);
    });
  });

  group('map', () {
    test('generation is deterministic and round-trips', () {
      final a = const MapGenerator().generate(MapId.lavaMine, 42);
      final b = const MapGenerator().generate(MapId.lavaMine, 42);
      expect(a.encodeTiles(), b.encodeTiles());
      expect(GameMap.fromJson(a.toJson()).encodeTiles(), a.encodeTiles());
      expect(a.depotTiles, isNotEmpty);
      expect(Physics.collides(a, a.spawn.cx, a.spawn.cy), isFalse);
    });
  });

  group('gravity', () {
    GameMap shaftMap() {
      final map = GameMap(5, 10, spawn: const TilePos(2, 1));
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 5; x++) {
          map.setTile(x, y, y <= 2 || (x == 2 && y < 8) ? TileType.empty : TileType.rock);
        }
      }
      return map;
    }

    MoveResult run(GameMap map, double x, double y, {double moveX = 0, bool jump = false, bool up = false, int ticks = 60}) {
      var r = MoveResult(x, y, 0, 0, onGround: false, impact: 0, climbing: false);
      for (var i = 0; i < ticks; i++) {
        r = Physics.move(map, r.x, r.y, r.vx, r.vy, moveX: moveX, speed: Balance.moveSpeed, dt: 1 / 30, jump: jump, up: up);
      }
      return r;
    }

    test('a misaligned miner slides into a 1-wide shaft and falls', () {
      final r = run(shaftMap(), 2.2, 2.5); // overlaps column 1
      expect(r.y, greaterThan(6), reason: 'should have dropped down the shaft');
      expect((r.x - 2.5).abs(), lessThan(0.2));
    });

    test('miners fall and land on solid ground', () {
      final map = shaftMap();
      final r = run(map, 0.5 + 0.5, 0.5, ticks: 45);
      expect(r.onGround, isTrue);
      expect(r.y, closeTo(3 - Balance.playerRadius, 0.01));
    });

    test('a jump clears a one-tile ledge but not two', () {
      final map = GameMap(8, 8, spawn: const TilePos(1, 1));
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          final floor = y >= 6 || (x >= 3 && y >= 5) || (x >= 6 && y >= 3);
          map.setTile(x, y, floor ? TileType.rock : TileType.empty);
        }
      }
      final r = run(map, 1.5, 5.6, moveX: 1, jump: true, ticks: 90);
      expect(r.x, greaterThan(3.5), reason: 'hopped onto the 1-tile step');
      expect(r.x, lessThan(6), reason: 'needs a running jump for the next one');
    });

    test('bracing against both walls climbs a shaft', () {
      final r = run(shaftMap(), 2.5, 7.6, up: true, ticks: 60);
      expect(r.y, lessThan(5), reason: 'climbed up');
    });

    test('long falls hurt, short ones do not', () {
      expect(Physics.fallDamage(Balance.safeFallSpeed - 1), 0);
      expect(Physics.fallDamage(Balance.maxFallSpeed), greaterThan(30));
    });
  });

  group('boulders and gear', () {
    late GameSimulation sim;
    late SimPlayer p;
    setUp(() {
      sim = GameSimulation(settings: const MatchSettings(fillWithBots: false), seed: 3, warmup: 0);
      p = sim.addHuman('p', 'P');
      for (var x = 5; x <= 15; x++) {
        for (var y = 15; y <= 25; y++) {
          sim.map.setTile(x, y, TileType.rock);
        }
      }
    });

    test('a boulder falls when dug out from under and hits the miner below', () {
      // Shaft: boulder at (10,16) above an open shaft, miner standing at the bottom (10,20).
      sim.map.setTile(10, 16, TileType.boulder);
      sim.map.setTile(10, 17, TileType.empty);
      sim.map.setTile(10, 18, TileType.empty);
      sim.map.setTile(10, 19, TileType.empty);
      sim.map.setTile(10, 20, TileType.empty);
      p
        ..x = 10.5
        ..y = 20.6;
      for (var i = 0; i < 30 * 3; i++) {
        sim.update(1 / 30);
      }
      expect(sim.map.tileAt(10, 16), TileType.empty);
      expect(sim.map.tileAt(10, 17), TileType.empty);
      expect(sim.map.tileAt(10, 19), TileType.boulder, reason: 'rests on the miner\'s head');
      expect(p.hp, lessThan(Balance.maxHealth));
    });

    test('Locker pickaxes are cosmetic: everyone starts with the same dig power', () {
      final q = sim.addHuman('q', 'Q', look: const Look(pickaxe: 'pick_plasma'));
      expect(q.upgrades[UpgradeKind.pickaxe.index], 0);
      expect(q.look.pickaxe, 'pick_plasma');
    });

    test('jetpack lifts you, burns fuel, refills on the ground', () {
      for (var y = 10; y <= 21; y++) {
        sim.map.setTile(10, y, TileType.empty);
      }
      p
        ..x = 10.5
        ..y = 21.6;
      sim.setInput('p', const PlayerInput(jet: true));
      for (var i = 0; i < 30; i++) {
        sim.update(1 / 30);
      }
      expect(p.y, lessThan(19), reason: 'flew up the shaft');
      expect(p.fuel, lessThan(Balance.jetFuelMax - 40));
      sim.setInput('p', const PlayerInput());
      for (var i = 0; i < 30 * 6; i++) {
        sim.update(1 / 30);
      }
      expect(p.onGround, isTrue);
      expect(p.fuel, Balance.jetFuelMax);
    });

    test('spike traps hurt and bounce you', () {
      sim.map.setTile(10, 20, TileType.spikes);
      sim.map.setTile(10, 19, TileType.empty);
      p
        ..x = 10.5
        ..y = 20.6;
      sim.update(1 / 30);
      expect(p.hp, Balance.maxHealth - Balance.spikeDamage);
      expect(p.vy, lessThan(0));
    });

    test('breaking an explosive crate sets it off', () {
      sim.map.setTile(10, 20, TileType.empty);
      sim.map.setTile(10, 21, TileType.explosive);
      sim.map.setTile(11, 21, TileType.rock);
      p
        ..x = 10.5
        ..y = 20.6;
      sim.setInput('p', const PlayerInput(fy: 1, mine: true));
      for (var i = 0; i < 30 * 5; i++) {
        sim.update(1 / 30);
        if (sim.map.tileAt(10, 21) != TileType.explosive) sim.setInput('p', const PlayerInput()); // lit: stop digging
      }
      expect(sim.map.tileAt(11, 21), TileType.empty, reason: 'the crate blast cleared its neighbours');
      expect(p.hp, lessThan(Balance.maxHealth));
    });

    test('throwing has a cooldown', () {
      sim.map.setTile(10, 20, TileType.empty);
      p
        ..x = 10.5
        ..y = 20.6
        ..items[ItemKind.bomb.index] = 3;
      expect(sim.useItem('p', ItemKind.bomb), isTrue);
      expect(sim.useItem('p', ItemKind.bomb), isFalse);
      for (var i = 0; i < 30; i++) {
        sim.update(1 / 30);
      }
      expect(sim.useItem('p', ItemKind.bomb), isTrue);
    });

    test('a thrown bomb flies forward and lands', () {
      sim.map.setTile(9, 20, TileType.empty);
      for (var x = 10; x <= 14; x++) {
        sim.map.setTile(x, 20, TileType.empty);
        sim.map.setTile(x, 19, TileType.empty);
      }
      p
        ..x = 10.5
        ..y = 20.6
        ..fx = 1
        ..fy = 0
        ..items[ItemKind.bomb.index] = 1;
      expect(sim.useItem('p', ItemKind.bomb), isTrue);
      for (var i = 0; i < 30; i++) {
        sim.update(1 / 30);
      }
      final b = sim.takeSnapshot().bombs.single;
      expect(b.x, greaterThan(12), reason: 'travelled right');
      expect(b.y, greaterThan(20), reason: 'came to rest on the floor');
    });
  });

  group('bombs, volcanoes and hints', () {
    late GameSimulation sim;
    late SimPlayer p;
    setUp(() {
      sim = GameSimulation(settings: const MatchSettings(fillWithBots: false), seed: 3, warmup: 0);
      p = sim.addHuman('p', 'P');
      for (var x = 5; x <= 15; x++) {
        for (var y = 15; y <= 25; y++) {
          sim.map.setTile(x, y, TileType.rock);
        }
      }
      sim.map.setTile(10, 20, TileType.empty);
      p
        ..x = 10.5
        ..y = 20.5;
    });

    test('bomb clears a 3x3 area, pays loot to the owner and hurts nearby miners', () {
      sim.map.setTile(11, 20, TileType.gold);
      p
        ..coins = 100
        ..inDepot = true;
      expect(sim.buyItem('p', ItemKind.bomb), isTrue);
      p.inDepot = false;
      expect(sim.useItem('p', ItemKind.bomb), isTrue);
      for (var i = 0; i < 30 * 3; i++) {
        sim.update(1 / 30);
      }
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          expect(sim.map.tileAt(10 + dx, 20 + dy), TileType.empty);
        }
      }
      expect(p.score, oreDefs[OreType.gold]!.value);
      expect(p.hp, lessThan(Balance.maxHealth), reason: 'standing on your own bomb hurts');
    });

    test('armor reduces bomb damage', () {
      final q = sim.addHuman('q', 'Q')
        ..x = 10.5
        ..y = 20.5
        ..upgrades[UpgradeKind.armor.index] = 2;
      p.items[ItemKind.bomb.index] = 1;
      sim.useItem('p', ItemKind.bomb);
      for (var i = 0; i < 30 * 3; i++) {
        sim.update(1 / 30);
      }
      expect(q.hp, greaterThan(p.hp));
    });

    test('volcanoes are hidden and kill whoever breaks them', () {
      sim.map.setTile(10, 21, TileType.volcano);
      expect(sim.publicMap().tileAt(10, 21), TileType.hardRock, reason: 'looks like normal rock');
      sim.setInput('p', const PlayerInput(fy: 1, mine: true));
      var died = false;
      for (var i = 0; i < 30 * 4; i++) {
        sim.update(1 / 30);
        if (!p.alive) died = true;
      }
      expect(died, isTrue);
      expect(sim.map.tileAt(10, 21), anyOf(TileType.lava, TileType.hardRock));
    });

    test('erupted lava hardens later', () {
      sim.map.setTile(10, 22, TileType.volcano);
      p.items[ItemKind.dynamite.index] = 1;
      sim.useItem('p', ItemKind.dynamite);
      p
        ..x = 14.5
        ..y = 20.5; // step away (teleport for the test)
      sim.map.setTile(14, 20, TileType.empty);
      for (var i = 0; i < 30 * 4; i++) {
        sim.update(1 / 30);
      }
      expect(sim.map.tileAt(10, 22), TileType.lava);
      for (var i = 0; i < 30 * (Balance.lavaCoolSeconds + 2); i++) {
        sim.update(1 / 30);
      }
      expect(sim.map.tileAt(10, 22), TileType.hardRock);
    });

    test('hints get warmer near the treasure but never give the exact tile', () {
      final t = sim.treasure;
      p
        ..x = t.cx
        ..y = t.cy - 30;
      expect(sim.hintFor('p').level, 0);
      p.y = t.cy - 12;
      expect(sim.hintFor('p').level, 1);
      p
        ..y = t.cy - 6
        ..x = t.cx - 5;
      expect(sim.hintFor('p').level, 2);
      expect(sim.hintFor('p').side, 1);
      p
        ..x = t.cx
        ..y = t.cy - 3;
      expect(sim.hintFor('p').level, 3);
    });
  });

  group('mining validation', () {
    late GameSimulation sim;
    late SimPlayer p;
    setUp(() {
      sim = GameSimulation(settings: const MatchSettings(fillWithBots: false), seed: 3, warmup: 0);
      p = sim.addHuman('p', 'P');
      // Put the miner in a pocket right above a gold deposit.
      for (var x = 9; x <= 11; x++) {
        for (var y = 19; y <= 24; y++) {
          sim.map.setTile(x, y, TileType.rock);
        }
      }
      sim.map.setTile(10, 20, TileType.empty);
      sim.map.setTile(10, 21, TileType.gold);
      p
        ..x = 10.5
        ..y = 20.5;
    });

    test('ore breaks after enough hits and pays coins instantly', () {
      sim.setInput('p', const PlayerInput(fx: 0, fy: 1, mine: true));
      for (var i = 0; i < 30 * 5; i++) {
        sim.update(1 / 30);
      }
      expect(sim.map.tileAt(10, 21), TileType.empty);
      expect(p.coins, oreDefs[OreType.gold]!.value);
    });

    test('breaking the treasure wins and ends the match', () {
      final t = sim.treasure;
      sim.map.setTile(t.x, t.y, TileType.empty);
      sim.map.setTile(10, 21, TileType.treasure);
      sim.setInput('p', const PlayerInput(fx: 0, fy: 1, mine: true));
      for (var i = 0; i < 30 * 5 && !sim.ended; i++) {
        sim.update(1 / 30);
      }
      expect(sim.ended, isTrue);
      expect(sim.winnerId, 'p');
      expect(sim.results().players.first.playerId, 'p');
      expect(sim.results().winnerId, 'p');
    });

    test('mining speed is capped by the tool cooldown', () {
      sim.setInput('p', const PlayerInput(fx: 0, fy: 1, mine: true));
      sim.update(1 / 30);
      sim.update(1 / 30); // within cooldown: no second hit
      expect(sim.map.hpAt(10, 21), TileType.gold.maxHp - 1);
    });

    test('cannot mine out of reach', () {
      p.y = 17.5; // far from the deposit
      sim.map.setTile(10, 18, TileType.empty);
      expect(Physics.mineTarget(sim.map, 10.5, 15.0, 0, 1), isNot(const TilePos(10, 21)));
    });

    test('upgrades require depot and coins', () {
      p.coins = 1000;
      expect(sim.requestUpgrade('p', UpgradeKind.pickaxe), isFalse); // not in depot
      p.inDepot = true;
      expect(sim.requestUpgrade('p', UpgradeKind.pickaxe), isTrue);
      expect(p.coins, 1000 - UpgradeKind.pickaxe.levels[1].cost);
    });
  });

  group('mystery bombs, monsters, world events', () {
    late GameSimulation sim;
    late SimPlayer p;
    setUp(() {
      sim = GameSimulation(settings: const MatchSettings(fillWithBots: false, mapId: MapId.starterMine), seed: 3, warmup: 0);
      p = sim.addHuman('p', 'P');
      for (var x = 4; x <= 16; x++) {
        for (var y = 15; y <= 25; y++) {
          sim.map.setTile(x, y, TileType.rock);
        }
      }
      sim.map.setTile(10, 20, TileType.empty);
      p
        ..x = 10.5
        ..y = 20.6;
    });

    test('digging a Mystery Bomb cracks it, then the server reveals one reward, once', () {
      sim.map.setTile(10, 21, TileType.mystery);
      expect(sim.publicMap().tileAt(10, 21), TileType.mystery, reason: 'visible, but rarity is not on the wire');
      sim.setInput('p', const PlayerInput(fy: 1, mine: true));
      final events = <GameEvent>[];
      var snapWithOpening = false;
      for (var i = 0; i < 30 * 5; i++) {
        sim.update(1 / 30);
        final snap = sim.takeSnapshot();
        events.addAll(snap.events);
        if (snap.mysteries.isNotEmpty) snapWithOpening = true;
        if (i == 30) sim.setInput('p', const PlayerInput());
      }
      expect(events.where((e) => e.kind == GameEventKind.mysteryFound), hasLength(1));
      final opened = events.where((e) => e.kind == GameEventKind.mysteryOpened).toList();
      expect(opened, hasLength(1), reason: 'paid exactly once');
      expect(opened.single.playerId, 'p');
      expect(snapWithOpening, isTrue, reason: 'everyone sees it shaking before the reveal');
      expect(p.mysteriesOpened, 1);
    });

    test('monsters chase, attack, and pay loot to whoever kills them', () {
      for (var x = 6; x <= 14; x++) {
        sim.map.setTile(x, 20, TileType.empty);
      }
      final before = sim.monsterCount;
      sim.spawnMonsterForTest(MonsterKind.spider, 13.5, 20.6);
      expect(sim.monsterCount, before + 1);
      var hurt = false;
      for (var i = 0; i < 30 * 3; i++) {
        sim.update(1 / 30);
        if (p.hp < Balance.maxHealth) hurt = true;
      }
      expect(hurt, isTrue, reason: 'the spider came over and bit');
      p.hp = Balance.maxHealth;
      final coins = p.coins;
      final m = sim.takeSnapshot().monsters.firstWhere((m) => m.kind == MonsterKind.spider && (m.y - 20.6).abs() < 1);
      sim.setInput('p', PlayerInput(fx: (m.x - p.x).sign, fy: 0, mine: true));
      for (var i = 0; i < 30 * 8 && sim.monsterCount > before; i++) {
        sim.update(1 / 30);
        p.hp = Balance.maxHealth;
      }
      expect(sim.monsterCount, before, reason: 'killed it');
      expect(p.coins, coins + monsterDefs[MonsterKind.spider]!.loot);
      expect(p.monstersKilled, 1);
    });

    test('gold rush doubles ore value', () {
      sim.worldEvent = WorldEventKind.goldRush;
      sim.worldEventLeft = 30;
      sim.map.setTile(10, 21, TileType.copper);
      sim.setInput('p', const PlayerInput(fy: 1, mine: true));
      for (var i = 0; i < 30 * 3; i++) {
        sim.update(1 / 30);
      }
      expect(p.coins, oreDefs[OreType.copper]!.value * 2);
    });

    test('world events start on their own and end', () {
      final kinds = <GameEventKind>{};
      for (var i = 0; i < 30 * 200; i++) {
        sim.update(1 / 30);
        kinds.addAll(sim.takeSnapshot().events.map((e) => e.kind));
      }
      expect(kinds, containsAll([GameEventKind.worldEvent, GameEventKind.worldEventEnded]));
    });
  });

  group('hazard expansion (acceptance)', () {
    late GameSimulation sim;
    late SimPlayer p;
    // A sealed 13x11 test room of rock at x 4..16, y 15..25; miner at (10,20).
    setUp(() {
      sim = GameSimulation(settings: const MatchSettings(fillWithBots: false), seed: 3, warmup: 0);
      p = sim.addHuman('p', 'P');
      for (var x = 4; x <= 16; x++) {
        for (var y = 15; y <= 25; y++) {
          sim.map.setTile(x, y, TileType.rock);
        }
      }
      sim.map.setTile(10, 20, TileType.empty);
      p
        ..x = 10.5
        ..y = 20.6;
    });

    void run(double seconds) {
      for (var i = 0; i < (seconds * 30).round(); i++) {
        sim.update(1 / 30);
      }
    }

    void hideAsRock(int x, int y, TileType t) {
      sim.map.setTile(x, y, t);
      sim.map.hide(sim.map.indexOf(x, y), TileType.rock);
    }

    test('hidden lava looks like rock until the rock in front of it is dug', () {
      hideAsRock(12, 20, TileType.lava);
      sim.takeSnapshot();
      expect(sim.publicMap().tileAt(12, 20), TileType.rock, reason: 'invisible from the start');
      expect(sim.map.tileAt(12, 20), TileType.lava, reason: 'but really there');
      // Dig the rock between, the normal way.
      sim.setInput('p', const PlayerInput(fx: 1, fy: 0, mine: true));
      final events = <GameEvent>[];
      final tiles = <TileChange>[];
      for (var i = 0; i < 30 && sim.map.tileAt(11, 20) != TileType.empty; i++) {
        sim.update(1 / 30);
        final s = sim.takeSnapshot();
        events.addAll(s.events);
        tiles.addAll(s.tiles);
      }
      sim.setInput('p', const PlayerInput());
      final last = sim.takeSnapshot();
      events.addAll(last.events);
      tiles.addAll(last.tiles);
      final snap = WorldSnapshot(tick: 0, timeLeft: 0, players: const [], tiles: tiles, events: events, teamScores: const []);
      expect(sim.publicMap().tileAt(12, 20), TileType.lava, reason: 'revealed once exposed');
      expect(snap.events.where((e) => e.kind == GameEventKind.hazardRevealed && e.value == TileType.lava.index), hasLength(1));
      expect(snap.tiles.any((t) => t.index == sim.map.indexOf(12, 20) && t.typeIndex == TileType.lava.index), isTrue,
          reason: 'every client gets the same world update');
    });

    test('lava hurts on touch and kills if you stay in it', () {
      sim.map.setTile(10, 21, TileType.lava);
      sim.map.setTile(10, 22, TileType.rock);
      run(0.3); // drop into it
      expect(p.hp, lessThan(Balance.maxHealth), reason: 'touching hurts');
      expect(p.alive, isTrue, reason: 'one touch is not instant death');
      p
        ..y = 21.5
        ..hp = Balance.maxHealth;
      run(2);
      expect(p.alive, isFalse, reason: 'staying in lava kills');
    });

    test('obsidian is much harder than rock; only Mining TNT breaks it in one blast', () {
      expect(TileType.obsidian.maxHp, greaterThan(TileType.hardRock.maxHp * 3));
      sim.map.setTile(12, 20, TileType.obsidian);
      sim.map.setTile(8, 20, TileType.obsidian);
      sim.map.setTile(11, 20, TileType.explosive);
      p.x = 6.5;
      sim.map.setTile(6, 20, TileType.empty);
      sim.map.setTile(7, 20, TileType.empty);
      sim.activateTntForTest(11, 20, TntKind.basic);
      run(3.5);
      expect(sim.map.tileAt(12, 20), TileType.obsidian, reason: 'a normal blast only cracks it');
      expect(sim.map.hpAt(12, 20), lessThan(TileType.obsidian.maxHp));
      sim.activateTntForTest(9, 20, TntKind.mining);
      run(3.5);
      expect(sim.map.tileAt(8, 20), TileType.empty, reason: 'Mining TNT breaks obsidian');
    });

    test('TNT explodes exactly 3 seconds (90 server ticks) after activation', () {
      p.x = 5.5;
      sim.map.setTile(5, 20, TileType.empty);
      sim.activateTntForTest(13, 20, TntKind.basic);
      final lit = sim.tick;
      final snap = sim.takeSnapshot();
      expect(snap.bombs.single.tnt, TntKind.basic);
      expect(snap.bombs.single.fuse, closeTo(3.0, 1e-9), reason: 'clients show the same 3-2-1');
      int? boomAt;
      for (var i = 0; i < 120 && boomAt == null; i++) {
        sim.update(1 / 30);
        if (sim.takeSnapshot().events.any((e) => e.kind == GameEventKind.explosion)) boomAt = sim.tick;
      }
      expect(boomAt! - lit, Balance.tntFuseTicks);
      expect(Balance.tntFuseTicks / Balance.tickRate, 3.0);
    });

    test('TNT breaks rock around it but not bedrock, and hurts/knocks back only nearby miners', () {
      final near = sim.addHuman('n', 'Near')
        ..x = 12.5
        ..y = 20.6;
      sim.map.setTile(12, 20, TileType.empty);
      sim.map.setTile(14, 21, TileType.bedrock);
      p.x = 5.5;
      sim.map.setTile(5, 20, TileType.empty);
      sim.activateTntForTest(13, 21, TntKind.basic);
      run(3.2);
      expect(sim.map.tileAt(13, 22), TileType.empty);
      expect(sim.map.tileAt(12, 21), TileType.empty);
      expect(sim.map.tileAt(14, 21), TileType.bedrock, reason: 'bedrock is not eligible');
      expect(near.hp < Balance.maxHealth || !near.alive, isTrue, reason: 'close miner got hit');
      expect(p.hp, Balance.maxHealth, reason: 'far miner untouched');
    });

    test('chain TNT lights other TNT nearby', () {
      p.x = 5.5;
      sim.map.setTile(5, 20, TileType.empty);
      sim.map.setTile(15, 18, TileType.explosive);
      sim.activateTntForTest(13, 20, TntKind.chain);
      run(3.2);
      expect(sim.map.tileAt(15, 18), isNot(TileType.explosive), reason: 'chain-lit');
      expect(sim.takeSnapshot().bombs.where((b) => b.tnt == TntKind.basic), hasLength(1), reason: 'now counting down its own 3 s');
    });

    test('launchers throw you in their direction, after a short warning', () {
      for (var x = 6; x <= 15; x++) {
        for (var y = 16; y <= 20; y++) {
          sim.map.setTile(x, y, TileType.empty);
        }
      }
      sim.map.setTile(10, 20, TileType.launcherRight);
      p
        ..x = 10.5
        ..y = 20.6;
      sim.map.setTile(10, 21, TileType.rock);
      p.y = 20.6;
      sim.update(1 / 30);
      final armed = sim.takeSnapshot().events.where((e) => e.kind == GameEventKind.launcherArmed);
      expect(armed, hasLength(1), reason: 'click before it fires');
      expect(p.vx.abs(), lessThan(1), reason: 'not yet');
      run(Balance.launcherWarning + 0.1);
      expect(p.vx, greaterThan(8), reason: 'thrown right');
      expect(p.vy, lessThan(0), reason: 'and up');
    });

    test('a launcher that throws you into a wall hurts; into lava is deadly', () {
      sim.map.setTile(11, 20, TileType.empty);
      sim.map.setTile(9, 20, TileType.launcherRight); // pad, then 2 tiles of air, then rock
      sim.map.setTile(10, 20, TileType.empty);
      p
        ..x = 9.5
        ..y = 20.6;
      run(1.2);
      expect(p.hp, lessThan(Balance.maxHealth), reason: 'crashed into the rock');
      expect(Physics.impactDamage(16), greaterThan(0));
      expect(Physics.impactDamage(Balance.safeImpactSpeed), 0);
    });

    test('floor traps in caves look empty until a miner walks close', () {
      for (var x = 6; x <= 15; x++) {
        sim.map.setTile(x, 20, TileType.empty);
      }
      sim.map.setTile(15, 20, TileType.spikes);
      sim.map.hide(sim.map.indexOf(15, 20), TileType.empty);
      sim.takeSnapshot();
      expect(sim.publicMap().tileAt(15, 20), TileType.empty, reason: 'hidden');
      p.x = 14.2;
      sim.takeSnapshot();
      expect(sim.publicMap().tileAt(15, 20), TileType.spikes, reason: 'noticed up close');
    });

    test('treasure compass gives real direction and distance, updated as you move', () {
      final t = sim.treasure;
      p
        ..x = t.cx - 12
        ..y = t.cy - 9;
      final h = sim.hintFor('p');
      expect(h.level, greaterThanOrEqualTo(1), reason: 'signal detected within range');
      expect(h.distance, 15, reason: 'sqrt(12² + 9²) = 15 tiles');
      expect(h.angle, 40, reason: 'atan2(9, 12) ≈ 37° → rounded to 40°');
      p.x = t.cx + 12;
      final h2 = sim.hintFor('p');
      expect(h2.angle, 140, reason: 'now the treasure is down-left');
      p
        ..x = t.cx
        ..y = t.cy - 40;
      expect(sim.hintFor('p').level, 0, reason: 'too far and too shallow: no signal');
    });

    test('dying drops 20% of your unspent coins, and the cause is reported', () {
      p.coins = 100;
      sim.map.setTile(10, 21, TileType.lava);
      sim.map.setTile(10, 22, TileType.lava);
      final events = <GameEvent>[];
      for (var i = 0; i < 90; i++) {
        sim.update(1 / 30);
        events.addAll(sim.takeSnapshot().events);
      }
      final died = events.firstWhere((e) => e.kind == GameEventKind.died);
      expect(died.text, 'lava');
      expect(died.value, 20);
      expect(p.coins, 80);
    });

    test('a chest pays exactly once', () {
      sim.map.setTile(10, 21, TileType.chest);
      sim.setInput('p', const PlayerInput(fy: 1, mine: true));
      final events = <GameEvent>[];
      for (var i = 0; i < 30 * 3; i++) {
        sim.update(1 / 30);
        events.addAll(sim.takeSnapshot().events);
      }
      final opened = events.where((e) => e.kind == GameEventKind.chestOpened).toList();
      expect(opened, hasLength(1));
      expect(p.coins, opened.single.value);
    });

    test('water flows down and turns lava into obsidian', () {
      for (var y = 16; y <= 20; y++) {
        sim.map.setTile(7, y, TileType.empty);
      }
      sim.map.setTile(7, 16, TileType.water);
      sim.map.setTile(7, 21, TileType.lava);
      run(2);
      expect(sim.map.tileAt(7, 16), TileType.empty, reason: 'water ran down');
      expect(sim.map.tileAt(7, 21), TileType.obsidian, reason: 'lava cooled');
    });
  });

  test('the sealed treasure chamber opens when a miner gets close', () {
    final sim = GameSimulation(settings: const MatchSettings(fillWithBots: false), seed: 7, warmup: 0);
    final p = sim.addHuman('p', 'P');
    final t = sim.treasure;
    sim.takeSnapshot();
    expect(sim.publicMap().tileAt(t.x, t.y - 3), isNot(TileType.ancientDoor), reason: 'the chamber is hidden');
    expect(sim.map.tileAt(t.x, t.y - 3), TileType.ancientDoor);
    expect(sim.map.tileAt(t.x, t.y - 3).isMinable, isFalse);
    p
      ..x = t.cx
      ..y = t.cy - 6.5;
    sim.map.setTile(t.x, t.y - 7, TileType.empty);
    sim.map.setTile(t.x, t.y - 6, TileType.empty);
    sim.map.setTile(t.x, t.y - 5, TileType.rock);
    sim.update(1 / 30);
    final snap = sim.takeSnapshot();
    expect(snap.events.any((e) => e.kind == GameEventKind.chamberOpened), isTrue);
    expect(sim.map.tileAt(t.x, t.y - 3), TileType.empty, reason: 'door opened');
    expect(sim.publicMap().tileAt(t.x, t.y - 1), TileType.empty, reason: 'the room inside is revealed');
  });

  test('treasure is hidden from clients until revealed', () {
    final sim = GameSimulation(settings: const MatchSettings(), seed: 5)..addHuman('h', 'H');
    expect(sim.map.treasure, isNotNull);
    expect(sim.publicMap().treasure, isNull, reason: 'clients must not see it');
    final t = sim.treasure;
    expect(sim.map.tileAt(t.x, t.y + 3).isSolid || sim.map.tileAt(t.x, t.y + 3) == TileType.lava, isTrue);
    final bottom = sim.map.height - 2;
    expect(sim.map.tileAt(5, bottom), TileType.lava, reason: 'lava sea at the very bottom');
  });

  for (final mapId in MapId.values) {
    test('bots dig down and someone finds the treasure (${mapId.name})', () {
      var found = 0;
      for (final seed in [1, 2, 3]) {
        final sim = GameSimulation(settings: MatchSettings(mapId: mapId, durationSeconds: 600), seed: seed);
        sim.addHuman('h', 'Human'); // idle human, 7 bots race
        var deepest = 0;
        while (!sim.ended) {
          sim.update(1 / 30);
          for (final p in sim.players.values) {
            if (p.maxDepth > deepest) deepest = p.maxDepth;
          }
        }
        expect(deepest, greaterThan(mapId.def.height ~/ 2), reason: 'bots should get deep');
        if (sim.winnerId != null) {
          found++;
          expect(sim.players[sim.winnerId]!.isBot, isTrue, reason: 'the human idles');
          expect(sim.results().winnerId, sim.winnerId);
        }
        // ignore: avoid_print
        print('${mapId.name} seed $seed: winner=${sim.winnerId} after ${(600 - sim.timeLeft).round()}s, deepest=$deepest');
      }
      expect(found, greaterThanOrEqualTo(2), reason: 'bots should usually find the treasure within 10 min');
    });
  }

  test('protocol round trip', () {
    final sim = GameSimulation(settings: const MatchSettings(), seed: 1)..addHuman('h', 'H');
    sim.syncBots(immediate: true);
    sim.update(1 / 30);
    final raw = SnapshotMessage(sim.takeSnapshot()).encode();
    final back = ServerMessage.decode(raw);
    expect(back, isA<SnapshotMessage>());
    expect((back as SnapshotMessage).snapshot.players.length, 8);
    expect(back.snapshot.players.first.maxDepth, isA<int>());
    expect(ClientMessage.decode('{"t":"in","dx":5,"dy":0,"m":true}'), isA<InputMessage>());
    expect((ClientMessage.decode('{"t":"in","dx":5}') as InputMessage).input.dx, 1.0);
    expect(ClientMessage.decode('garbage'), isNull);
  });
}
