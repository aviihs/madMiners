import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:mad_miners_server/mad_miners_server.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

class FakeConn implements PlayerConnection {
  final sent = <ServerMessage>[];
  bool closed = false;
  @override
  void send(String data) => sent.add(ServerMessage.decode(data)!);
  @override
  void close([int? code, String? reason]) => closed = true;
}

void main() {
  late JsonFileAccountRepository repo;
  late AuthService auth;
  late RoomService rooms;

  setUp(() async {
    repo = await JsonFileAccountRepository.open(null);
    auth = AuthService(repo);
    rooms = RoomService(repo, autoStart: false);
  });

  test('guest tokens authenticate and are stored hashed', () async {
    final r = await auth.registerGuest('Shiva');
    expect((await auth.authenticate(r.token)).id, r.account.id);
    expect(r.account.tokenHash, isNot(r.token));
    expect(() => auth.authenticate('nope'), throwsA(isA<AppException>()));
    final dup = await auth.registerGuest('shiva');
    expect(dup.account.username, isNot('shiva'));
  });

  test('room fills with bots, humans replace bots, results persist', () async {
    final a = (await auth.registerGuest('Alice')).account;
    final b = (await auth.registerGuest('Bob')).account;
    final room = rooms.create(a, const MatchSettings(durationSeconds: 30), isPrivate: false);

    final ca = FakeConn();
    room.attach(a, ca);
    expect(ca.sent.first, isA<JoinedMessage>());
    for (var i = 0; i < 30 * Balance.warmupSeconds; i++) {
      room.tick(1 / 30);
    }
    expect(room.humanCount + room.botCount, 8, reason: 'bots fill the lobby');

    room.attach(b, FakeConn());
    expect(room.humanCount, 2);
    expect(room.botCount, 6);
    final snap = ca.sent.whereType<SnapshotMessage>().last.snapshot;
    expect(snap.players.every((p) => !p.isBot), isTrue, reason: 'bots look like players');

    for (var i = 0; i < 30 * 40 && room.status == RoomStatus.playing; i++) {
      room.tick(1 / 30);
    }
    expect(room.status, RoomStatus.ended);
    final end = ca.sent.whereType<MatchEndMessage>().single.result;
    expect(end.players.every((p) => !p.isBot), isTrue);
    expect(ca.sent.whereType<SnapshotMessage>(), isNotEmpty);
    expect(ca.sent.last, isA<MatchEndMessage>());
    await Future<void>.delayed(Duration.zero);
    expect((await repo.findById(a.id))!.gamesPlayed, 1);
    expect(rooms.byId(room.id), isNull, reason: 'ended rooms are disposed');
  });

  test('store: buy with coins/gems, idempotent retries, equip', () async {
    final store = StoreService(repo);
    final a = (await auth.registerGuest('Shopper')).account
      ..wallet = 500
      ..gems = 70;
    await expectLater(store.purchase(a, 'outfit_purple', 'r1'), throwsA(isA<AppException>()), reason: '700 > 500');
    await store.purchase(a, 'outfit_forest', 'r2');
    await store.purchase(a, 'outfit_forest', 'r2'); // network retry: no double charge
    expect(a.wallet, 200);
    await store.purchase(a, 'outfit_gold', 'r3');
    expect(a.gems, 10);
    await expectLater(store.equip(a, 'helmet_crown'), throwsA(isA<AppException>()), reason: 'not owned');
    await store.equip(a, 'outfit_gold');
    await store.equip(a, 'helmet_white'.replaceAll('white', 'yellow')); // free items are always owned
    expect(a.look.outfit, 'outfit_gold');

    // The look shows up in the match.
    final room = rooms.create(a, const MatchSettings(), isPrivate: false);
    final c = FakeConn();
    room.attach(a, c);
    room.tick(1 / 30);
    room.tick(1 / 30);
    final snap = c.sent.whereType<SnapshotMessage>().last.snapshot;
    expect(snap.players.firstWhere((p) => p.id == a.id).look.outfit, 'outfit_gold');
  });

  test('daily leaderboard ranks treasure finds first', () async {
    final a = (await auth.registerGuest('Finder')).account;
    final b = (await auth.registerGuest('Grinder')).account;
    a.applyResult(const PlayerResult(playerId: 'x', name: 'A', isBot: false, team: -1, rank: 1, score: 100, oresMined: 1, xp: 10), foundTreasure: true);
    b.applyResult(const PlayerResult(playerId: 'y', name: 'B', isBot: false, team: -1, rank: 2, score: 900, oresMined: 9, xp: 10), foundTreasure: false);
    await repo.saveAll([a, b]);
    final top = await repo.topToday(10);
    expect(top.first.id, a.id);
    expect(a.gems, 10);
  });

  test('treasure hints are sent privately', () async {
    final a = (await auth.registerGuest('Alice')).account;
    final b = (await auth.registerGuest('Bobby')).account;
    final room = rooms.create(a, const MatchSettings(), isPrivate: false);
    final ca = FakeConn(), cb = FakeConn();
    room.attach(a, ca);
    room.attach(b, cb);
    room.sim.warmup = 0;
    final t = room.sim.treasure;
    room.sim.players[a.id]!
      ..x = t.cx
      ..y = t.cy - 3;
    room.tick(1 / 30);
    room.tick(1 / 30);
    expect(ca.sent.whereType<HintMessage>().last.hint.level, 3);
    expect(cb.sent.whereType<HintMessage>().any((h) => h.hint.level > 0), isFalse);
  });

  test('joined map hides the treasure', () async {
    final a = (await auth.registerGuest('Alice')).account;
    final room = rooms.create(a, const MatchSettings(), isPrivate: false);
    final c = FakeConn();
    room.attach(a, c);
    final joined = c.sent.first as JoinedMessage;
    expect(room.sim.map.treasure, isNotNull);
    expect(joined.map.treasure, isNull);
  });

  test('reconnect within window restores the same miner', () async {
    final a = (await auth.registerGuest('Alice')).account;
    final room = rooms.create(a, const MatchSettings(), isPrivate: false);
    final c1 = FakeConn();
    room.attach(a, c1);
    room.sim.players[a.id]!.coins = 123;
    room.onClosed(a.id, c1);
    expect(room.sim.players[a.id]!.connected, isFalse);

    final c2 = FakeConn();
    room.attach(a, c2);
    final joined = c2.sent.first as JoinedMessage;
    expect(joined.reconnected, isTrue);
    expect(room.sim.players[a.id]!.coins, 123);
    expect(room.humanCount, 1);
  });

  test('private rooms need the code; capacity is enforced', () async {
    final host = (await auth.registerGuest('Host')).account;
    final room = rooms.create(host, const MatchSettings(maxPlayers: 8), isPrivate: true);
    final stranger = (await auth.registerGuest('Stranger')).account;
    expect(() => room.attach(stranger, FakeConn()), throwsA(isA<AppException>()));
    rooms.joinByCode(stranger, room.code.toLowerCase());
    room.attach(stranger, FakeConn());

    room.attach(host, FakeConn());
    for (var i = 0; i < 6; i++) {
      final p = (await auth.registerGuest('Player$i')).account;
      rooms.joinByCode(p, room.code);
      room.attach(p, FakeConn());
    }
    expect(room.humanCount, 8);
    expect(room.botCount, 0);
    final late = (await auth.registerGuest('Late')).account;
    expect(() => rooms.joinByCode(late, room.code), throwsA(isA<AppException>()));
  });

  test('HTTP + WebSocket end to end', () async {
    final app = ServerApp(repo);
    final server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      app.rooms.shutdown();
      await server.close(force: true);
    });
    final base = 'http://127.0.0.1:${server.port}';
    final client = HttpClient();

    Future<Map<String, dynamic>> post(String path, Map body, [String? token]) async {
      final req = await client.postUrl(Uri.parse('$base$path'));
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      req.write(jsonEncode(body));
      final res = await req.close();
      return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    }

    final login = await post('/api/v1/auth/guest', {'username': 'Tester'});
    expect(login['success'], isTrue);
    final token = login['data']['accessToken'] as String;

    final bad = await post('/api/v1/matchmaking/quick', {});
    expect(bad['error']['code'], 'UNAUTHORIZED');

    final qp = await post('/api/v1/matchmaking/quick', {}, token);
    final wsPath = qp['data']['wsPath'] as String;

    final ws = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}$wsPath&token=$token');
    final msgs = ws.stream.map((d) => ServerMessage.decode(d as String)).asBroadcastStream();
    expect(await msgs.first.timeout(const Duration(seconds: 3)), isA<JoinedMessage>());
    ws.sink.add(const InputMessage(PlayerInput(dx: 1, dy: 0)).encode());
    final snap = await msgs
        .firstWhere((m) => m is SnapshotMessage && m.snapshot.players.length == 8)
        .timeout(const Duration(seconds: 12));
    expect((snap as SnapshotMessage).snapshot.players.any((p) => p.isBot), isFalse);
    await ws.sink.close();
    client.close(force: true);
  });
}
