import '../../../../core/error/result.dart';
import '../entities/room.dart';

abstract interface class LobbyRepository {
  Future<Result<List<RoomSummary>>> listRooms(String token);
  Future<Result<RoomTicket>> createRoom(String token, CreateRoomParams params);
  Future<Result<RoomTicket>> joinRoom(String token, String roomId);
  Future<Result<RoomTicket>> joinByCode(String token, String code);
  Future<Result<RoomTicket>> quickPlay(String token);
}
