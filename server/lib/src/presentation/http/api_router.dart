import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../application/app_exception.dart';
import '../../application/auth_service.dart';
import '../../application/game_room.dart';
import '../../application/room_service.dart';
import '../../application/store_service.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/repositories/account_repository.dart';
import 'middleware.dart';

/// REST API under /api/v1 (SRS §8). Real-time play goes over /ws/game.
class ApiRouter {
  ApiRouter(this._auth, this._rooms, this._accounts, this._store);

  final AuthService _auth;
  final StoreService _store;
  final RoomService _rooms;
  final AccountRepository _accounts;

  Router get router {
    final r = Router()
      ..get('/', _home)
      ..get('/health', (Request _) => ok({'status': 'ok', 'rooms': _rooms.rooms.length}))
      ..post('/api/v1/auth/guest', _guest)
      ..post('/api/v1/auth/google', _google)
      ..post('/api/v1/auth/logout', _logout)
      ..get('/api/v1/players/me/matches', _matches)
      ..get('/api/v1/economy/transactions', _transactions)
      ..get('/api/v1/players/me', _me)
      ..get('/api/v1/rooms', _listRooms)
      ..post('/api/v1/rooms', _createRoom)
      ..post('/api/v1/rooms/join-by-code', _joinByCode)
      ..get('/api/v1/rooms/<id>', _getRoom)
      ..post('/api/v1/rooms/<id>/join', _joinRoom)
      ..post('/api/v1/matchmaking/quick', _quickPlay)
      ..get('/api/v1/leaderboards/global', _leaderboard)
      ..get('/api/v1/leaderboards/daily', _daily)
      ..get('/api/v1/store/catalog', (Request _) => ok(_store.catalog()))
      ..post('/api/v1/store/purchase', _purchase)
      ..post('/api/v1/players/me/equip', _equip)
      ..get('/api/v1/catalog', _catalog);
    return r;
  }

  /// Friendly status page for people who open the server URL in a browser.
  Response _home(Request _) {
    final rooms = _rooms.rooms.toList();
    final players = rooms.fold<int>(0, (a, r) => a + r.humanCount);
    final rows = rooms.isEmpty
        ? '<p class="muted">No matches running right now.</p>'
        : rooms
              .map(
                (r) =>
                    '<li><b>${r.settings.mapId.def.name}</b> · ${r.settings.mode.label} · '
                    '${r.humanCount + r.botCount}/${r.settings.maxPlayers} miners · ${r.sim.timeLeft.round()}s left</li>',
              )
              .join();
    return Response.ok(
      '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mad Miners Server</title><style>
body{margin:0;font-family:-apple-system,system-ui,Segoe UI,Roboto,sans-serif;background:#0c0a09;color:#f5f5f7;display:flex;justify-content:center;padding:48px 16px}
.card{max-width:440px;width:100%;background:#1c1917;border:1px solid #2b2623;border-radius:20px;padding:28px}
h1{margin:0 0 4px;font-size:26px}.ok{color:#30d158;font-weight:600}.muted{color:#98989f}
ul{padding-left:18px;line-height:1.7}code{background:#2b2623;padding:2px 6px;border-radius:6px}
</style></head><body><div class="card">
<h1>Mad Miners</h1><p class="ok">Server is running</p>
<p class="muted">${rooms.length} match(es) · $players player(s) online</p>${rooms.isEmpty ? rows : '<ul>$rows</ul>'}
<p class="muted">Open the Mad Miners app and use this address as the server. API lives under <code>/api/v1</code>, health check at <code>/health</code>.</p>
</div></body></html>''',
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
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

  Future<Response> _google(Request req) async {
    final body = await readJson(req);
    final idToken = body['idToken'] as String? ?? '';
    if (idToken.isEmpty) throw AppException.badRequest('MISSING_ID_TOKEN', 'idToken is required.');
    final r = await _auth.signInWithGoogle(idToken, linkToToken: bearerToken(req));
    return ok({'accessToken': r.token, 'isNew': r.isNew, ...r.account.toPublicJson()}, status: r.isNew ? 201 : 200);
  }

  Future<Response> _logout(Request req) async {
    final token = bearerToken(req);
    if (token != null) await _auth.signOut(token);
    return ok({'signedOut': true});
  }

  Future<Response> _matches(Request req) async {
    final user = await _user(req);
    return ok([for (final m in await _accounts.matchHistory(user.id, limit: 30)) m.toJson()]);
  }

  Future<Response> _transactions(Request req) async {
    final user = await _user(req);
    return ok([for (final t in await _accounts.transactions(user.id, limit: 50)) t.toJson()]);
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

  Future<Response> _daily(Request req) async {
    await _user(req);
    final top = await _accounts.topToday(50);
    return ok([
      for (var i = 0; i < top.length; i++) {'rank': i + 1, ...top[i].toRankJson()},
    ]);
  }

  Future<Response> _purchase(Request req) async {
    final user = await _user(req);
    final b = await readJson(req);
    final acc = await _store.purchase(user, b['itemId'] as String? ?? '', b['requestId'] as String? ?? '');
    return ok(acc.toPublicJson());
  }

  Future<Response> _equip(Request req) async {
    final user = await _user(req);
    final b = await readJson(req);
    return ok((await _store.equip(user, b['itemId'] as String? ?? '')).toPublicJson());
  }

  Future<Response> _leaderboard(Request req) async {
    await _user(req);
    final top = await _accounts.topByCoins(50);
    return ok([
      for (var i = 0; i < top.length; i++) {'rank': i + 1, ...top[i].toRankJson()},
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
