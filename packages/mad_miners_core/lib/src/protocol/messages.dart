import 'dart:convert';

import '../config/balance.dart';
import '../model/match_settings.dart';
import '../model/snapshot.dart';
import '../world/game_map.dart';

/// Real-time protocol carried over the game WebSocket as JSON text frames.
/// Every message has a `t` (type) field.

// ---------------------------------------------------------------------------
// Client -> Server
// ---------------------------------------------------------------------------

sealed class ClientMessage {
  const ClientMessage();

  Map<String, dynamic> toJson();
  String encode() => jsonEncode(toJson());

  static ClientMessage? decode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return null;
      return switch (j['t']) {
        'in' => InputMessage(PlayerInput.fromJson(j)),
        'up' => UpgradeMessage(UpgradeKind.values.byName(j['k'] as String)),
        'chat' => ChatMessage((j['text'] as String?) ?? ''),
        'ping' => PingMessage((j['c'] as num).toInt()),
        'leave' => const LeaveMessage(),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

class InputMessage extends ClientMessage {
  const InputMessage(this.input);
  final PlayerInput input;
  @override
  Map<String, dynamic> toJson() => {'t': 'in', ...input.toJson()};
}

class UpgradeMessage extends ClientMessage {
  const UpgradeMessage(this.kind);
  final UpgradeKind kind;
  @override
  Map<String, dynamic> toJson() => {'t': 'up', 'k': kind.name};
}

class ChatMessage extends ClientMessage {
  const ChatMessage(this.text);
  final String text;
  @override
  Map<String, dynamic> toJson() => {'t': 'chat', 'text': text};
}

class PingMessage extends ClientMessage {
  const PingMessage(this.clientTime);
  final int clientTime;
  @override
  Map<String, dynamic> toJson() => {'t': 'ping', 'c': clientTime};
}

class LeaveMessage extends ClientMessage {
  const LeaveMessage();
  @override
  Map<String, dynamic> toJson() => {'t': 'leave'};
}

// ---------------------------------------------------------------------------
// Server -> Client
// ---------------------------------------------------------------------------

sealed class ServerMessage {
  const ServerMessage();

  Map<String, dynamic> toJson();
  String encode() => jsonEncode(toJson());

  static ServerMessage? decode(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return switch (j['t']) {
        'joined' => JoinedMessage(
          youId: j['you'] as String,
          roomId: j['room'] as String,
          roomCode: j['code'] as String,
          settings: MatchSettings.fromJson(j['settings'] as Map<String, dynamic>),
          map: GameMap.fromJson(j['map'] as Map<String, dynamic>),
          reconnected: j['re'] == true,
        ),
        'snap' => SnapshotMessage(WorldSnapshot.fromJson(j['s'] as Map<String, dynamic>)),
        'end' => MatchEndMessage(MatchResult.fromJson(j['r'] as Map<String, dynamic>)),
        'pong' => PongMessage((j['c'] as num).toInt()),
        'err' => ErrorMessage(j['code'] as String, j['message'] as String),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

class JoinedMessage extends ServerMessage {
  const JoinedMessage({
    required this.youId,
    required this.roomId,
    required this.roomCode,
    required this.settings,
    required this.map,
    this.reconnected = false,
  });

  final String youId;
  final String roomId;
  final String roomCode;
  final MatchSettings settings;
  final GameMap map;
  final bool reconnected;

  @override
  Map<String, dynamic> toJson() => {
    't': 'joined',
    'you': youId,
    'room': roomId,
    'code': roomCode,
    'settings': settings.toJson(),
    'map': map.toJson(),
    're': reconnected,
  };
}

class SnapshotMessage extends ServerMessage {
  const SnapshotMessage(this.snapshot);
  final WorldSnapshot snapshot;
  @override
  Map<String, dynamic> toJson() => {'t': 'snap', 's': snapshot.toJson()};
}

class MatchEndMessage extends ServerMessage {
  const MatchEndMessage(this.result);
  final MatchResult result;
  @override
  Map<String, dynamic> toJson() => {'t': 'end', 'r': result.toJson()};
}

class PongMessage extends ServerMessage {
  const PongMessage(this.clientTime);
  final int clientTime;
  @override
  Map<String, dynamic> toJson() => {'t': 'pong', 'c': clientTime};
}

class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.code, this.message);
  final String code;
  final String message;
  @override
  Map<String, dynamic> toJson() => {'t': 'err', 'code': code, 'message': message};
}
