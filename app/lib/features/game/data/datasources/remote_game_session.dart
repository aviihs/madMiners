import 'dart:async';

import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/config/server_config.dart';
import '../../domain/entities/game_target.dart';
import '../../domain/entities/session_event.dart';
import '../../domain/repositories/game_session_repository.dart';

/// WebSocket session to the authoritative server.
///
/// If the socket drops unexpectedly it keeps retrying for the server's
/// reconnect window; the server keeps our miner in place meanwhile.
class RemoteGameSession implements GameSession {
  RemoteGameSession(this.target, this._config);

  final OnlineTarget target;
  final ServerConfig _config;

  final _events = StreamController<SessionEvent>.broadcast();
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _pingTimer;
  bool _leaving = false;
  bool _ended = false;
  bool _joinedOnce = false;
  DateTime? _lostAt;

  @override
  Stream<SessionEvent> get events => _events.stream;

  Uri get _uri => _config.wsUri('${target.wsPath}&token=${Uri.encodeQueryComponent(target.token)}');

  @override
  Future<void> start() async {
    await Future<void>.delayed(Duration.zero);
    await _connect();
  }

  Future<void> _connect() async {
    if (_leaving || _ended) return;
    _emit(SessionLink(_joinedOnce ? LinkStatus.reconnecting : LinkStatus.connecting));
    try {
      final ws = WebSocketChannel.connect(_uri);
      await ws.ready.timeout(const Duration(seconds: 6));
      _ws = ws;
      _sub = ws.stream.listen(_onData, onDone: _onDropped, onError: (_) => _onDropped(), cancelOnError: true);
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _send(PingMessage(DateTime.now().millisecondsSinceEpoch)));
    } catch (_) {
      _onDropped();
    }
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    switch (ServerMessage.decode(data)) {
      case JoinedMessage m:
        _joinedOnce = true;
        _lostAt = null;
        _emit(const SessionLink(LinkStatus.connected));
        _emit(SessionJoined(youId: m.youId, roomCode: m.roomCode, settings: m.settings, map: m.map, reconnected: m.reconnected));
      case SnapshotMessage m:
        _emit(SessionSnapshot(m.snapshot));
      case MatchEndMessage m:
        _ended = true;
        _emit(SessionEnded(m.result));
      case HintMessage m:
        _emit(SessionHint(m.hint));
      case PongMessage m:
        _emit(SessionLink(LinkStatus.connected, rttMs: DateTime.now().millisecondsSinceEpoch - m.clientTime));
      case ErrorMessage m:
        _ended = true; // server refused us; don't retry
        _emit(SessionLink(LinkStatus.lost, message: m.message));
      case null:
        break;
    }
  }

  void _onDropped() {
    _pingTimer?.cancel();
    _sub?.cancel();
    _ws = null;
    if (_leaving || _ended) return;
    _lostAt ??= DateTime.now();
    if (DateTime.now().difference(_lostAt!).inSeconds >= Balance.reconnectWindowSeconds) {
      _emit(const SessionLink(LinkStatus.lost, message: 'Connection lost.'));
      return;
    }
    _emit(const SessionLink(LinkStatus.reconnecting));
    Timer(const Duration(seconds: 2), _connect);
  }

  void _emit(SessionEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _send(ClientMessage m) => _ws?.sink.add(m.encode());

  @override
  void sendInput(PlayerInput input) => _send(InputMessage(input));

  @override
  void buyUpgrade(UpgradeKind kind) => _send(UpgradeMessage(kind));

  @override
  void buyItem(ItemKind kind) => _send(ItemMessage(kind, use: false));

  @override
  void useItem(ItemKind kind) => _send(ItemMessage(kind, use: true));

  @override
  void chat(String text) => _send(ChatMessage(text));

  @override
  Future<void> leave() async {
    _leaving = true;
    _pingTimer?.cancel();
    if (!_ended) _send(const LeaveMessage());
    await _sub?.cancel();
    await _ws?.sink.close();
    await _events.close();
  }
}
