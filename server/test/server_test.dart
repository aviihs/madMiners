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
    final room = rooms.create(a, const MatchSettings(durationSeconds: 60), isPrivate: false);

    final ca = FakeConn();
    room.attach(a, ca);
    expect(ca.sent.first, isA<JoinedMessage>());
    expect(room.humanCount + room.botCount, 8);

    room.attach(b, FakeConn());
    expect(room.humanCount, 2);
    expect(room.botCount, 6);

    for (var i = 0; i < 30 * 61; i++) {
      room.tick(1 / 30);
    }
    expect(room.status, RoomStatus.ended);
    expect(ca.sent.whereType<SnapshotMessage>(), isNotEmpty);
    expect(ca.sent.last, isA<MatchEndMessage>());
    await Future<void>.delayed(Duration.zero);
    expect((await repo.findById(a.id))!.gamesPlayed, 1);
    expect(rooms.byId(room.id), isNull, reason: 'ended rooms are disposed');
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
    final snap = await msgs.firstWhere((m) => m is SnapshotMessage).timeout(const Duration(seconds: 3));
    expect((snap as SnapshotMessage).snapshot.players.length, 8);
    await ws.sink.close();
    client.close(force: true);
  });
}
