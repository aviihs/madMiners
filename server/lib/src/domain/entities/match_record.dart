import 'package:mad_miners_core/mad_miners_core.dart';

/// Rewards for one human player, decided by the server.
class Reward {
  const Reward({required this.coins, required this.gems, required this.xp});
  final int coins;
  final int gems;
  final int xp;

  /// Coins = match score; gems for finding the treasure or a podium finish.
  factory Reward.forResult(PlayerResult r, {required bool foundTreasure}) =>
      Reward(coins: r.score, gems: foundTreasure ? 10 : (r.rank <= 3 ? 2 : 0), xp: r.xp);
}

class MatchPlayerRecord {
  const MatchPlayerRecord({required this.userId, required this.result, required this.foundTreasure, required this.reward});
  final String userId;
  final PlayerResult result;
  final bool foundTreasure;
  final Reward reward;
}

/// Everything persisted when a match finishes, in one transaction.
class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.roomCode,
    required this.mapId,
    required this.mode,
    required this.startedAt,
    required this.durationSeconds,
    required this.playerCount,
    required this.winnerUserId,
    required this.winnerName,
    required this.players,
  });

  final String id;
  final String roomCode;
  final MapId mapId;
  final GameMode mode;
  final DateTime startedAt;
  final int durationSeconds;
  final int playerCount;
  final String? winnerUserId;
  final String? winnerName;
  final List<MatchPlayerRecord> players;
}

/// One row of a player's match history.
class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.matchId,
    required this.mapId,
    required this.mode,
    required this.endedAt,
    required this.rank,
    required this.score,
    required this.maxDepth,
    required this.foundTreasure,
    required this.playerCount,
    required this.winnerName,
    required this.coinsAwarded,
    required this.gemsAwarded,
  });

  final String matchId;
  final String mapId;
  final String mode;
  final DateTime endedAt;
  final int rank;
  final int score;
  final int maxDepth;
  final bool foundTreasure;
  final int playerCount;
  final String? winnerName;
  final int coinsAwarded;
  final int gemsAwarded;

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mapId': mapId,
    'mode': mode,
    'endedAt': endedAt.toUtc().toIso8601String(),
    'rank': rank,
    'score': score,
    'maxDepth': maxDepth,
    'foundTreasure': foundTreasure,
    'playerCount': playerCount,
    'winnerName': winnerName,
    'coinsAwarded': coinsAwarded,
    'gemsAwarded': gemsAwarded,
  };
}

/// Audit row for any coin/gem movement.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.kind,
    required this.currency,
    required this.amount,
    required this.balanceAfter,
    required this.reference,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final String currency;
  final int amount;
  final int balanceAfter;
  final String? reference;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'currency': currency,
    'amount': amount,
    'balanceAfter': balanceAfter,
    'reference': reference,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
