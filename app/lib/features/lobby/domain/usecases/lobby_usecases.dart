import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/room.dart';
import '../repositories/lobby_repository.dart';

class ListRooms {
  const ListRooms(this._repo);
  final LobbyRepository _repo;
  Future<Result<List<RoomSummary>>> call(String token) => _repo.listRooms(token);
}

class CreateRoom {
  const CreateRoom(this._repo);
  final LobbyRepository _repo;

  Future<Result<RoomTicket>> call(String token, CreateRoomParams p) {
    if (p.maxPlayers < 8 || p.maxPlayers > 12) {
      return Future.value(const Err(ServerFailure('Rooms hold 8–12 miners.')));
    }
    return _repo.createRoom(token, p);
  }
}

class JoinRoom {
  const JoinRoom(this._repo);
  final LobbyRepository _repo;
  Future<Result<RoomTicket>> call(String token, String roomId) => _repo.joinRoom(token, roomId);
}

class JoinRoomByCode {
  const JoinRoomByCode(this._repo);
  final LobbyRepository _repo;

  Future<Result<RoomTicket>> call(String token, String code) {
    final c = code.trim().toUpperCase();
    if (c.length < 4) return Future.value(const Err(ServerFailure('Enter a valid room code.')));
    return _repo.joinByCode(token, c);
  }
}

class QuickPlay {
  const QuickPlay(this._repo);
  final LobbyRepository _repo;
  Future<Result<RoomTicket>> call(String token) => _repo.quickPlay(token);
}
