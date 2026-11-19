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

    test('a joining human replaces a bot', () {
      final sim = GameSimulation(settings: s, seed: 1);
      sim.addHuman('a', 'A');
      expect(sim.players.length, 8);
      expect(sim.botCount, 7);
      sim.addHuman('b', 'B');
      expect(sim.players.length, 8);
      expect(sim.botCount, 6);
      sim.removePlayer('a');
      expect(sim.botCount, 7);
    });

    test('room never exceeds 12', () {
      final sim = GameSimulation(settings: s, seed: 1);
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

  group('mining validation', () {
    late GameSimulation sim;
    late SimPlayer p;
    setUp(() {
      sim = GameSimulation(settings: const MatchSettings(fillWithBots: false), seed: 3);
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

    test('ore breaks after enough hits and lands in the backpack', () {
      sim.setInput('p', const PlayerInput(fx: 0, fy: 1, mine: true));
      for (var i = 0; i < 30 * 5; i++) {
        sim.update(1 / 30);
      }
      expect(sim.map.tileAt(10, 21), TileType.empty);
      expect(p.backpack[OreType.gold.index], 1);
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

  test('bots mine and sell on their own', () {
    final sim = GameSimulation(settings: const MatchSettings(durationSeconds: 240), seed: 7);
    sim.addHuman('h', 'Human');
    var mined = 0, sold = 0;
    for (var i = 0; i < 30 * 180; i++) {
      sim.update(1 / 30);
      if (i % 2 == 0) {
        final snap = sim.takeSnapshot();
        mined += snap.events.where((e) => e.kind == GameEventKind.oreMined).length;
        sold += snap.events.where((e) => e.kind == GameEventKind.sold).length;
      }
    }
    expect(mined, greaterThan(20), reason: 'bots should find ore');
    expect(sold, greaterThan(3), reason: 'bots should come back to sell');
  });

  test('protocol round trip', () {
    final sim = GameSimulation(settings: const MatchSettings(), seed: 1)..addHuman('h', 'H');
    sim.update(1 / 30);
    final raw = SnapshotMessage(sim.takeSnapshot()).encode();
    final back = ServerMessage.decode(raw);
    expect(back, isA<SnapshotMessage>());
    expect((back as SnapshotMessage).snapshot.players.length, 8);
    expect(ClientMessage.decode('{"t":"in","dx":5,"dy":0,"m":true}'), isA<InputMessage>());
    expect((ClientMessage.decode('{"t":"in","dx":5}') as InputMessage).input.dx, 1.0);
    expect(ClientMessage.decode('garbage'), isNull);
  });
}
