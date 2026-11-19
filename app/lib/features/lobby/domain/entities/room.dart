import 'package:equatable/equatable.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

class RoomSummary extends Equatable {
  const RoomSummary({
    required this.roomId,
    required this.mapId,
    required this.mode,
    required this.maxPlayers,
    required this.humans,
    required this.bots,
    required this.isPrivate,
    required this.timeLeft,
    this.roomCode,
  });

  final String roomId;
  final String? roomCode;
  final MapId mapId;
  final GameMode mode;
  final int maxPlayers;
  final int humans;
  final int bots;
  final bool isPrivate;
  final int timeLeft;

  bool get isFull => humans >= maxPlayers;

  @override
  List<Object?> get props => [roomId, roomCode, mapId, mode, maxPlayers, humans, bots, isPrivate, timeLeft];
}

/// Permission to connect to a room's game server.
class RoomTicket extends Equatable {
  const RoomTicket({required this.roomId, required this.roomCode, required this.wsPath});
  final String roomId;
  final String roomCode;
  final String wsPath;

  @override
  List<Object?> get props => [roomId, roomCode, wsPath];
}

class CreateRoomParams {
  const CreateRoomParams({
    required this.mapId,
    required this.mode,
    required this.maxPlayers,
    required this.isPrivate,
    this.fillWithBots = true,
  });

  final MapId mapId;
  final GameMode mode;
  final int maxPlayers;
  final bool isPrivate;
  final bool fillWithBots;
}
