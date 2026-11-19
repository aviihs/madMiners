import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/room.dart';

abstract final class RoomMapper {
  static RoomSummary summary(Map<String, dynamic> j) => RoomSummary(
    roomId: j['roomId'] as String,
    roomCode: j['roomCode'] as String?,
    mapId: MapId.parse(j['mapId'] as String?),
    mode: GameMode.parse(j['gameMode'] as String?),
    maxPlayers: (j['maxPlayers'] as num).toInt(),
    humans: (j['humans'] as num).toInt(),
    bots: (j['bots'] as num).toInt(),
    isPrivate: j['isPrivate'] == true,
    timeLeft: (j['timeLeft'] as num?)?.toInt() ?? 0,
  );

  static RoomTicket ticket(Map<String, dynamic> j) => RoomTicket(
    roomId: j['roomId'] as String,
    roomCode: j['roomCode'] as String,
    wsPath: j['wsPath'] as String,
  );

  static Map<String, dynamic> createBody(CreateRoomParams p) => {
    'mapId': p.mapId.name,
    'gameMode': p.mode.name,
    'maxPlayers': p.maxPlayers,
    'isPrivate': p.isPrivate,
    'fillWithBots': p.fillWithBots,
  };
}
