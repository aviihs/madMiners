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

    test('bots trickle in during the lobby and look like players', () {
      final sim = GameSimulation(settings: s, seed: 1);
      sim.addHuman('a', 'A');
      expect(sim.botCount, 0);
      for (var i = 0; i < 30 * Balance.warmupSeconds; i++) {
        sim.update(1 / 30);
      }
      expect(sim.players.length, 8);
      final snap = sim.takeSnapshot();
      expect(snap.players.every((p) => !p.isBot), isTrue, reason: 'disguised on the wire');
      expect(snap.players.map((p) => p.name).toSet().length, 8, reason: 'unique names');
      expect(snap.players.any((p) => p.name.contains('Bot')), isFalse);
      expect(sim.results(forClients: true).players.every((p) => !p.isBot), isTrue);
      expect(sim.results().players.where((p) => p.isBot).length, 7, reason: 'server still knows');
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

  test('corner assist slides a misaligned miner into a 1-wide shaft', () {
    final map = GameMap(5, 8, spawn: const TilePos(2, 1));
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 5; x++) {
        map.setTile(x, y, y <= 2 || x == 2 ? TileType.empty : TileType.rock);
      }
    }
    var (x, y) = (2.2, 2.5); // overlaps column 1
    for (var i = 0; i < 60; i++) {
      (x, y) = Physics.step(map, x, y, 0, Balance.moveSpeed, 1 / 30);
    }
    expect(y, greaterThan(4), reason: 'should have slid in and moved down the shaft');
    expect((x - 2.5).abs(), lessThan(0.2));
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
        for (var y = 19; y <= 21; y++) {
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
          expect(sim.players[sim.winnerId]!.isBot, isTrue);
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
