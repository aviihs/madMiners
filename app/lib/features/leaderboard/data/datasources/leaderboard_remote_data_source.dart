import '../../../../core/network/api_client.dart';
import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardRemoteDataSource {
  LeaderboardRemoteDataSource(this._api);
  final ApiClient _api;

  Future<List<LeaderboardEntry>> global(String token) async {
    final list = await _api.get<List<dynamic>>('/api/v1/leaderboards/global', token: token);
    return [
      for (final e in list.cast<Map<String, dynamic>>())
        LeaderboardEntry(
          rank: (e['rank'] as num).toInt(),
          playerId: e['playerId'] as String,
          username: e['username'] as String,
          level: (e['level'] as num).toInt(),
          totalCoins: (e['totalCoins'] as num).toInt(),
          wins: (e['wins'] as num).toInt(),
        ),
    ];
  }
}
