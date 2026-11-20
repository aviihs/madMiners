import 'dart:math';

import 'package:mad_miners_core/mad_miners_core.dart';

import '../domain/entities/match_record.dart';
import '../domain/entities/player_account.dart';
import '../domain/repositories/account_repository.dart';
import 'app_exception.dart';
import 'game_room.dart';

/// Room lifecycle + matchmaking.
class RoomService {
  RoomService(this._accounts, {Random? random, this.autoStart = true}) : _rng = random ?? Random();

  final AccountRepository _accounts;
  final Random _rng;

  /// Tests drive [GameRoom.tick] manually.
  final bool autoStart;

  final Map<String, GameRoom> _rooms = {};
  int _seq = 0;

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Iterable<GameRoom> get rooms => _rooms.values;

  GameRoom? byId(String id) => _rooms[id];

  List<GameRoom> listPublic() =>
      _rooms.values.where((r) => !r.isPrivate && r.status == RoomStatus.playing).toList()
        ..sort((a, b) => b.humanCount.compareTo(a.humanCount));

  GameRoom create(PlayerAccount host, MatchSettings settings, {required bool isPrivate}) {
    if (_rooms.length >= 500) {
      throw const AppException(503, 'CAPACITY', 'Servers are full, try again shortly.');
    }
    String code;
    do {
      code = 'MM${List.generate(4, (_) => _codeChars[_rng.nextInt(_codeChars.length)]).join()}';
    } while (_rooms.values.any((r) => r.code == code));

    final room = GameRoom(
      id: 'room-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${++_seq}',
      code: code,
      settings: settings,
      isPrivate: isPrivate,
      hostId: host.id,
      seed: _rng.nextInt(1 << 31),
      onMatchEnded: _persistResults,
      onDisposed: (r) => _rooms.remove(r.id),
    );
    _rooms[room.id] = room;
    if (autoStart) room.start();
    return room;
  }

  GameRoom join(PlayerAccount player, String roomId) {
    final room = _rooms[roomId] ?? (throw AppException.notFound('Room'));
    if (room.isPrivate && !room.allowed.contains(player.id)) throw AppException.forbidden;
    if (!room.isOpen && !room.sim.players.containsKey(player.id)) {
      throw AppException.conflict('ROOM_FULL', 'Room is full or finished.');
    }
    return room;
  }

  GameRoom joinByCode(PlayerAccount player, String code) {
    final normalized = code.trim().toUpperCase();
    final room = _rooms.values.where((r) => r.code == normalized).firstOrNull;
    if (room == null) throw AppException.notFound('Room');
    if (!room.isOpen) throw AppException.conflict('ROOM_FULL', 'Room is full or finished.');
    room.allow(player.id);
    return room;
  }

  /// Puts the player into the public room with the most humans that still has
  /// space and enough time left; otherwise opens a fresh one (bots fill it).
  GameRoom quickPlay(PlayerAccount player, {MapId? mapId, GameMode? mode}) {
    final candidates = listPublic().where(
      (r) =>
          r.isOpen &&
          r.sim.timeLeft > 60 &&
          (mapId == null || r.settings.mapId == mapId) &&
          (mode == null || r.settings.mode == mode),
    );
    if (candidates.isNotEmpty) return candidates.first;
    return create(
      player,
      MatchSettings(
        mapId: mapId ?? MapId.values[_rng.nextInt(MapId.values.length)],
        mode: mode ?? GameMode.treasureHunt,
      ),
      isPrivate: false,
    );
  }

  Future<void> _persistResults(GameRoom room, MatchResult result) async {
    final humans = result.players.where((p) => !p.isBot).toList();
    if (humans.isEmpty) return;
    final winner = result.players.where((p) => p.playerId == result.winnerId).firstOrNull;
    await _accounts.recordMatch(
      MatchRecord(
        id: _uuid(),
        roomCode: room.code,
        mapId: room.settings.mapId,
        mode: room.settings.mode,
        startedAt: room.createdAt,
        durationSeconds: DateTime.now().difference(room.createdAt).inSeconds,
        playerCount: result.players.length,
        winnerUserId: winner == null || winner.isBot ? null : winner.playerId,
        winnerName: winner?.name,
        players: [
          for (final r in humans)
            MatchPlayerRecord(
              userId: r.playerId,
              result: r,
              foundTreasure: r.playerId == result.winnerId,
              reward: Reward.forResult(r, foundTreasure: r.playerId == result.winnerId),
            ),
        ],
      ),
    );
  }

  String _uuid() {
    final b = List.generate(16, (_) => _rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  void shutdown() {
    for (final r in _rooms.values.toList()) {
      r.dispose();
    }
    _rooms.clear();
  }
}
