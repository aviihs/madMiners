import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/history.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._api);
  final ApiClient _api;

  Future<List<MatchHistoryItem>> matches(String token) async {
    final list = await _api.get<List<dynamic>>('/api/v1/players/me/matches', token: token);
    return [
      for (final m in list.cast<Map<String, dynamic>>())
        MatchHistoryItem(
          matchId: m['matchId'] as String,
          mapId: MapId.parse(m['mapId'] as String?),
          mode: GameMode.parse(m['mode'] as String?),
          endedAt: DateTime.parse(m['endedAt'] as String).toLocal(),
          rank: (m['rank'] as num).toInt(),
          score: (m['score'] as num).toInt(),
          maxDepth: (m['maxDepth'] as num).toInt(),
          foundTreasure: m['foundTreasure'] == true,
          playerCount: (m['playerCount'] as num).toInt(),
          winnerName: m['winnerName'] as String?,
          coinsAwarded: (m['coinsAwarded'] as num).toInt(),
          gemsAwarded: (m['gemsAwarded'] as num).toInt(),
        ),
    ];
  }

  Future<List<WalletEntry>> transactions(String token) async {
    final list = await _api.get<List<dynamic>>('/api/v1/economy/transactions', token: token);
    return [
      for (final t in list.cast<Map<String, dynamic>>())
        WalletEntry(
          id: (t['id'] as num).toInt(),
          kind: t['kind'] as String,
          currency: t['currency'] == 'gems' ? WalletCurrency.gems : WalletCurrency.coins,
          amount: (t['amount'] as num).toInt(),
          balanceAfter: (t['balanceAfter'] as num).toInt(),
          reference: t['reference'] as String?,
          createdAt: DateTime.parse(t['createdAt'] as String).toLocal(),
        ),
    ];
  }
}
