import 'dart:async';

import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../application/app_exception.dart';
import '../../application/auth_service.dart';
import '../../application/game_room.dart';
import '../../application/room_service.dart';

/// `GET /ws/game?room=<id>&token=<accessToken>`
///
/// The token travels in the query string because browsers can't set headers
/// on WebSocket upgrades. Always serve over TLS (wss://) in production.
class GameSocketHandler {
  GameSocketHandler(this._auth, this._rooms);

  final AuthService _auth;
  final RoomService _rooms;

  Handler get handler => (Request request) {
    final roomId = request.url.queryParameters['room'];
    final token = request.url.queryParameters['token'];
    return webSocketHandler((WebSocketChannel ws, _) => _session(ws, roomId, token))(request);
  };

  Future<void> _session(WebSocketChannel ws, String? roomId, String? token) async {
    final conn = _WsConnection(ws);
    try {
      final account = await _auth.authenticate(token);
      final room = _rooms.byId(roomId ?? '') ?? (throw AppException.notFound('Room'));
      room.attach(account, conn);
      ws.stream.listen(
        (data) {
          if (data is String && data.length < 4096) room.onMessage(account.id, data);
        },
        onDone: () => room.onClosed(account.id, conn),
        onError: (_) => room.onClosed(account.id, conn),
        cancelOnError: true,
      );
    } on AppException catch (e) {
      conn.send(ErrorMessage(e.code, e.message).encode());
      conn.close(4000 + e.status, e.code);
    }
  }
}

class _WsConnection implements PlayerConnection {
  _WsConnection(this._ws);
  final WebSocketChannel _ws;
  bool _closed = false;

  @override
  void send(String data) {
    if (!_closed) _ws.sink.add(data);
  }

  @override
  void close([int? code, String? reason]) {
    if (_closed) return;
    _closed = true;
    unawaited(_ws.sink.close(code, reason));
  }
}
