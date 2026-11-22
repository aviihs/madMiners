import '../../../../core/error/result.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/lobby_repository.dart';
import '../datasources/lobby_remote_data_source.dart';

class LobbyRepositoryImpl implements LobbyRepository {
  LobbyRepositoryImpl(this._remote);
  final LobbyRemoteDataSource _remote;

  @override
  Future<Result<List<RoomSummary>>> listRooms(String token) => guard(() => _remote.rooms(token));

  @override
  Future<Result<RoomTicket>> createRoom(String token, CreateRoomParams params) => guard(() => _remote.create(token, params));

  @override
  Future<Result<RoomTicket>> joinRoom(String token, String roomId) => guard(() => _remote.join(token, roomId));

  @override
  Future<Result<RoomTicket>> joinByCode(String token, String code) => guard(() => _remote.joinByCode(token, code));

  @override
  Future<Result<RoomTicket>> quickPlay(String token) => guard(() => _remote.quick(token));
}
