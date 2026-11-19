// Plays an online session against a running server to surface errors.
import 'dart:convert';
import 'dart:io';

import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:web_socket_channel/io.dart';

Future<void> main(List<String> args) async {
  final base = args.isEmpty ? 'http://127.0.0.1:8080' : args.first;
  final http = HttpClient();
  Future<Map<String, dynamic>> post(String path, Object body, [String? token]) async {
    final req = await http.postUrl(Uri.parse('$base$path'));
    req.headers.contentType = ContentType.json;
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    req.write(jsonEncode(body));
    final res = await req.close();
    return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }

  for (var round = 0; round < 3; round++) {
    final login = await post('/api/v1/auth/guest', {'username': 'Smoke$round'});
    final token = login['data']['accessToken'] as String;
    final room = await post('/api/v1/matchmaking/quick', {}, token);
    final ws = IOWebSocketChannel.connect('${base.replaceFirst('http', 'ws')}${room['data']['wsPath']}&token=$token');
    var snaps = 0;
    final sub = ws.stream.listen((d) {
      final m = ServerMessage.decode(d as String);
      if (m is SnapshotMessage) snaps++;
      if (m == null) stderr.writeln('UNDECODABLE: ${(d).substring(0, 80)}');
    });
    for (var i = 0; i < 40; i++) {
      ws.sink.add(InputMessage(PlayerInput(dx: i.isEven ? 1 : -1, dy: 1, fy: 1, mine: true)).encode());
      ws.sink.add(const UpgradeMessage(UpgradeKind.pickaxe).encode());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    print('round $round: $snaps snapshots');
    if (round == 1) {
      await sub.cancel(); // abrupt drop -> reconnect window
    } else {
      ws.sink.add(const LeaveMessage().encode());
      await ws.sink.close();
    }
  }
  http.close(force: true);
}
