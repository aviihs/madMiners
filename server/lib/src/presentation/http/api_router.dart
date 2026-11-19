import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../application/app_exception.dart';
import '../../application/auth_service.dart';
import '../../application/game_room.dart';
import '../../application/room_service.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/repositories/account_repository.dart';
import 'middleware.dart';

/// REST API under /api/v1 (SRS §8). Real-time play goes over /ws/game.
class ApiRouter {
  ApiRouter(this._auth, this._rooms, this._accounts);

  final AuthService _auth;
  final RoomService _rooms;
  final AccountRepository _accounts;

  Router get router {
    final r = Router()
      ..get('/health', (Request _) => ok({'status': 'ok', 'rooms': _rooms.rooms.length}))
      ..post('/api/v1/auth/guest', _guest)
      ..get('/api/v1/players/me', _me)
      ..get('/api/v1/rooms', _listRooms)
      ..post('/api/v1/rooms', _createRoom)
      ..post('/api/v1/rooms/join-by-code', _joinByCode)
      ..get('/api/v1/rooms/<id>', _getRoom)
      ..post('/api/v1/rooms/<id>/join', _joinRoom)
      ..post('/api/v1/matchmaking/quick', _quickPlay)
      ..get('/api/v1/leaderboards/global', _leaderboard)
      ..get('/api/v1/catalog', _catalog);
    return r;
  }

  Future<PlayerAccount> _user(Request req) => _auth.authenticate(bearerToken(req));

  Map<String, dynamic> _joinPayload(GameRoom room) => {
    ...room.toSummaryJson(),
    'roomCode': room.code,
    'wsPath': '/ws/game?room=${room.id}',
  };

  Future<Response> _guest(Request req) async {
    final body = await readJson(req);
    final result = await _auth.registerGuest((body['username'] as String?) ?? '');
    return ok({'accessToken': result.token, ...result.account.toPublicJson()}, status: 201);
  }

  Future<Response> _me(Request req) async => ok((await _user(req)).toPublicJson());

  Future<Response> _listRooms(Request req) async {
    await _user(req);
    return ok(_rooms.listPublic().map((r) => r.toSummaryJson()).toList());
  }

  Future<Response> _createRoom(Request req) async {
    final user = await _user(req);
    final b = await readJson(req);
    final settings = MatchSettings.sanitized(
      mapId: b['mapId'] as String?,
      mode: b['gameMode'] as String?,
      maxPlayers: (b['maxPlayers'] as num?)?.toInt(),
      durationSeconds: (b['durationSeconds'] as num?)?.toInt(),
      fillWithBots: b['fillWithBots'] as bool? ?? true,
    );
    final room = _rooms.create(user, settings, isPrivate: b['isPrivate'] == true);
    return ok(_joinPayload(room), status: 201);
  }

  Future<Response> _getRoom(Request req, String id) async {
    final user = await _user(req);
    final room = _rooms.byId(id) ?? (throw AppException.notFound('Room'));
    if (room.isPrivate && !room.allowed.contains(user.id)) throw AppException.forbidden;
    return ok(room.toSummaryJson());
  }

  Future<Response> _joinRoom(Request req, String id) async =>
      ok(_joinPayload(_rooms.join(await _user(req), id)));

  Future<Response> _joinByCode(Request req) async {
    final user = await _user(req);
    final code = (await readJson(req))['roomCode'] as String? ?? '';
    return ok(_joinPayload(_rooms.joinByCode(user, code)));
  }

  Future<Response> _quickPlay(Request req) async {
    final user = await _user(req);
    final b = await readJson(req);
    final room = _rooms.quickPlay(
      user,
      mapId: b['mapId'] == null ? null : MapId.parse(b['mapId'] as String),
      mode: b['gameMode'] == null ? null : GameMode.parse(b['gameMode'] as String),
    );
    return ok(_joinPayload(room));
  }

  Future<Response> _leaderboard(Request req) async {
    await _user(req);
    final top = await _accounts.topByCoins(50);
    return ok([
      for (var i = 0; i < top.length; i++) {'rank': i + 1, ...top[i].toPublicJson()},
    ]);
  }

  Response _catalog(Request _) => ok({
    'ores': [
      for (final o in oreDefs.values)
        {'id': o.type.name, 'name': o.name, 'rarity': o.rarity.name, 'value': o.value},
    ],
    'upgrades': {
      for (final k in UpgradeKind.values)
        k.name: [for (final l in k.levels) {'name': l.name, 'cost': l.cost}],
    },
    'maps': [
      for (final m in MapId.values) {'id': m.name, 'name': m.def.name, 'description': m.def.description},
    ],
    'modes': [
      for (final m in GameMode.values) {'id': m.name, 'name': m.label, 'description': m.description},
    ],
  });
}
