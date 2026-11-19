import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardRemoteDataSource {
  LeaderboardRemoteDataSource(this._api);
  final ApiClient _api;

  Future<List<LeaderboardEntry>> global(String token) => _fetch('/api/v1/leaderboards/global', token);
  Future<List<LeaderboardEntry>> today(String token) => _fetch('/api/v1/leaderboards/daily', token);

  Future<List<LeaderboardEntry>> _fetch(String path, String token) async {
    final list = await _api.get<List<dynamic>>(path, token: token);
    return [
      for (final e in list.cast<Map<String, dynamic>>())
        LeaderboardEntry(
          rank: (e['rank'] as num).toInt(),
          playerId: e['playerId'] as String,
          username: e['username'] as String,
          level: (e['level'] as num).toInt(),
          totalCoins: (e['totalCoins'] as num).toInt(),
          wins: (e['wins'] as num).toInt(),
          todayWins: (e['todayWins'] as num?)?.toInt() ?? 0,
          todayCoins: (e['todayCoins'] as num?)?.toInt() ?? 0,
          look: Look.fromJson(e['look']),
        ),
    ];
  }
}
