import 'dart:async';
import 'dart:math';

import 'package:mad_miners_core/mad_miners_core.dart';

import '../domain/entities/player_account.dart';
import 'app_exception.dart';

/// Port for one player's real-time connection (a WebSocket in production,
/// a fake in tests).
abstract interface class PlayerConnection {
  void send(String data);
  void close([int? code, String? reason]);
}

enum RoomStatus { playing, ended }

/// One running match: owns a [GameSimulation], drives it at a fixed tick
/// rate, broadcasts snapshots, and handles disconnect/reconnect.
class GameRoom {
  GameRoom({
    required this.id,
    required this.code,
    required this.settings,
    required this.isPrivate,
    required this.hostId,
    required this.onMatchEnded,
    required this.onDisposed,
    int? seed,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now,
       sim = GameSimulation(settings: settings, seed: seed ?? Random().nextInt(1 << 31)) {
    createdAt = _now();
    _emptySince = createdAt;
    allowed.add(hostId);
  }

  final String id;
  final String code;
  final MatchSettings settings;
  final bool isPrivate;
  final String hostId;
  final GameSimulation sim;
  final Future<void> Function(GameRoom room, MatchResult result) onMatchEnded;
  final void Function(GameRoom room) onDisposed;
  final DateTime Function() _now;

  late final DateTime createdAt;
  RoomStatus status = RoomStatus.playing;

  /// Players allowed into a private room (host + people who used the code).
  final Set<String> allowed = {};

  final Map<String, PlayerConnection> _conns = {};
  final Map<String, DateTime> _disconnectedAt = {};
  final Map<String, _RateLimiter> _limits = {};
  final Map<String, TreasureHint> _hints = {};
  DateTime? _emptySince;
  Timer? _timer;

  /// Rooms with nobody in them shut down after this long.
  static const emptyTimeout = Duration(seconds: 45);

  int get humanCount => sim.humanCount;
  int get botCount => sim.botCount;
  bool get isFull => humanCount >= settings.maxPlayers;
  bool get isOpen => status == RoomStatus.playing && !isFull;

  void start() {
    _timer ??= Timer.periodic(
      Duration(microseconds: 1000000 ~/ Balance.tickRate),
      (_) => tick(1 / Balance.tickRate),
    );
  }

  void allow(String playerId) => allowed.add(playerId);

  /// Called when a player's WebSocket opens.
  void attach(PlayerAccount account, PlayerConnection conn) {
    if (status != RoomStatus.playing) {
      throw const AppException(410, 'ROOM_CLOSED', 'This match has finished.');
    }
    if (isPrivate && !allowed.contains(account.id)) throw AppException.forbidden;

    final reconnecting = sim.players.containsKey(account.id);
    if (!reconnecting && isFull) throw AppException.conflict('ROOM_FULL', 'Room is full.');

    // A newer connection replaces an older one for the same player.
    _conns.remove(account.id)?.close(4000, 'replaced');
    _conns[account.id] = conn;
    _hints.remove(account.id);
    _disconnectedAt.remove(account.id);
    _emptySince = null;

    if (reconnecting) {
      sim.setConnected(account.id, connected: true);
    } else {
      sim.addHuman(account.id, account.username, look: account.look);
    }
    conn.send(
      JoinedMessage(
        youId: account.id,
        roomId: id,
        roomCode: code,
        settings: settings,
        map: sim.publicMap(),
        reconnected: reconnecting,
      ).encode(),
    );
  }

  void onMessage(String playerId, String raw) {
    if (_conns[playerId] == null) return;
    final limiter = _limits.putIfAbsent(playerId, _RateLimiter.new);
    if (!limiter.allow(_now())) return; // flood protection: drop silently

    switch (ClientMessage.decode(raw)) {
      case InputMessage(:final input):
        sim.setInput(playerId, input);
      case UpgradeMessage(:final kind):
        sim.requestUpgrade(playerId, kind);
      case ItemMessage(:final kind, :final use):
        use ? sim.useItem(playerId, kind) : sim.buyItem(playerId, kind);
      case ChatMessage(:final text):
        if (limiter.allowChat(_now())) sim.chat(playerId, text);
      case PingMessage(:final clientTime):
        _conns[playerId]?.send(PongMessage(clientTime).encode());
      case LeaveMessage():
        _conns.remove(playerId)?.close(1000, 'left');
        _disconnectedAt.remove(playerId);
        sim.removePlayer(playerId);
      case null:
        break;
    }
  }

  /// Called when a socket closes. The miner idles in place for the
  /// reconnect window before being removed.
  void onClosed(String playerId, PlayerConnection conn) {
    if (!identical(_conns[playerId], conn)) return;
    _conns.remove(playerId);
    if (sim.players.containsKey(playerId)) {
      sim.setConnected(playerId, connected: false);
      _disconnectedAt[playerId] = _now();
    }
  }

  void tick(double dt) {
    if (status != RoomStatus.playing) return;
    sim.update(dt);

    final now = _now();
    _disconnectedAt.removeWhere((pid, at) {
      if (now.difference(at).inSeconds < Balance.reconnectWindowSeconds) return false;
      sim.removePlayer(pid);
      return true;
    });

    if (_conns.isEmpty) {
      _emptySince ??= now;
      if (now.difference(_emptySince!) > emptyTimeout) {
        _finish(notify: false);
        return;
      }
    }

    if (sim.tick % Balance.snapshotEvery == 0 || sim.ended) {
      final data = SnapshotMessage(sim.takeSnapshot()).encode();
      for (final c in _conns.values.toList()) {
        c.send(data);
      }
      // Each miner's treasure sense goes only to that miner.
      _conns.forEach((pid, c) {
        final h = sim.hintFor(pid);
        if (_hints[pid] != h) {
          _hints[pid] = h;
          c.send(HintMessage(h).encode());
        }
      });
    }
    if (sim.ended) _finish(notify: true);
  }

  Future<void> _finish({required bool notify}) async {
    if (status == RoomStatus.ended) return;
    status = RoomStatus.ended;
    _timer?.cancel();
    final result = sim.results();
    if (notify) {
      final data = MatchEndMessage(sim.results(forClients: true)).encode();
      for (final c in _conns.values.toList()) {
        c.send(data);
      }
    }
    try {
      if (result.players.any((p) => !p.isBot)) await onMatchEnded(this, result);
    } finally {
      for (final c in _conns.values.toList()) {
        c.close(1000, 'match over');
      }
      _conns.clear();
      onDisposed(this);
    }
  }

  void dispose() {
    _timer?.cancel();
    for (final c in _conns.values.toList()) {
      c.close(4001, 'server shutting down');
    }
    _conns.clear();
  }

  Map<String, dynamic> toSummaryJson() => {
    'roomId': id,
    if (isPrivate) 'roomCode': code,
    'mapId': settings.mapId.name,
    'mapName': settings.mapId.def.name,
    'gameMode': settings.mode.name,
    'maxPlayers': settings.maxPlayers,
    'humans': humanCount,
    'bots': botCount,
    'isPrivate': isPrivate,
    'status': status.name,
    'timeLeft': sim.timeLeft.round(),
  };
}

/// Token bucket: ~60 messages/s burst 90, chat 1 per 800 ms.
class _RateLimiter {
  double _tokens = 90;
  DateTime? _last;
  DateTime? _lastChat;

  bool allow(DateTime now) {
    if (_last != null) {
      final secs = now.difference(_last!).inMicroseconds / 1e6;
      _tokens = min(90, _tokens + secs * 60);
    }
    _last = now;
    if (_tokens < 1) return false;
    _tokens--;
    return true;
  }

  bool allowChat(DateTime now) {
    if (_lastChat != null && now.difference(_lastChat!).inMilliseconds < 800) return false;
    _lastChat = now;
    return true;
  }
}
