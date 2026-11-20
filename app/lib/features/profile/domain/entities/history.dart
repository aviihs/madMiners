import 'package:equatable/equatable.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

class MatchHistoryItem extends Equatable {
  const MatchHistoryItem({
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
  final MapId mapId;
  final GameMode mode;
  final DateTime endedAt;
  final int rank;
  final int score;
  final int maxDepth;
  final bool foundTreasure;
  final int playerCount;
  final String? winnerName;
  final int coinsAwarded;
  final int gemsAwarded;

  @override
  List<Object?> get props => [matchId];
}

enum WalletCurrency { coins, gems }

class WalletEntry extends Equatable {
  const WalletEntry({
    required this.id,
    required this.kind,
    required this.currency,
    required this.amount,
    required this.balanceAfter,
    required this.reference,
    required this.createdAt,
  });

  final int id;

  /// match_reward | purchase | grant
  final String kind;
  final WalletCurrency currency;
  final int amount;
  final int balanceAfter;
  final String? reference;
  final DateTime createdAt;

  /// Human label, e.g. "Bought Old Bahadur" or "Match reward".
  String get label {
    if (kind == 'purchase') {
      final id = reference?.replaceFirst('item:', '');
      return 'Bought ${cosmeticsById[id]?.name ?? 'item'}';
    }
    if (kind == 'match_reward') return 'Match reward';
    return 'Bonus';
  }

  @override
  List<Object?> get props => [id];
}
