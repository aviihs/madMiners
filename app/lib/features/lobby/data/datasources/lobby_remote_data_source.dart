import '../../../../core/network/api_client.dart';
import '../../domain/entities/room.dart';
import '../models/room_models.dart';

class LobbyRemoteDataSource {
  LobbyRemoteDataSource(this._api);
  final ApiClient _api;

  Future<List<RoomSummary>> rooms(String token) async {
    final list = await _api.get<List<dynamic>>('/api/v1/rooms', token: token);
    return list.map((e) => RoomMapper.summary(e as Map<String, dynamic>)).toList();
  }

  Future<RoomTicket> create(String token, CreateRoomParams p) async => RoomMapper.ticket(
    await _api.post<Map<String, dynamic>>('/api/v1/rooms', body: RoomMapper.createBody(p), token: token),
  );

  Future<RoomTicket> join(String token, String roomId) async => RoomMapper.ticket(
    await _api.post<Map<String, dynamic>>('/api/v1/rooms/${Uri.encodeComponent(roomId)}/join', token: token),
  );

  Future<RoomTicket> joinByCode(String token, String code) async => RoomMapper.ticket(
    await _api.post<Map<String, dynamic>>('/api/v1/rooms/join-by-code', body: {'roomCode': code}, token: token),
  );

  Future<RoomTicket> quick(String token) async =>
      RoomMapper.ticket(await _api.post<Map<String, dynamic>>('/api/v1/matchmaking/quick', body: const {}, token: token));
}
