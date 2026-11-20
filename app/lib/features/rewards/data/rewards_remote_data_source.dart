import '../../../core/network/api_client.dart';
import '../../auth/data/models/player_profile_model.dart';
import '../../auth/domain/entities/player_profile.dart';

/// Today's login reward as the server sees it.
class DailyRewardStatus {
  const DailyRewardStatus({required this.available, required this.streak, required this.coins, required this.gems});

  factory DailyRewardStatus.fromJson(Map<String, dynamic> j) => DailyRewardStatus(
    available: j['available'] == true,
    streak: (j['streak'] as num?)?.toInt() ?? 1,
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    gems: (j['gems'] as num?)?.toInt() ?? 0,
  );

  final bool available;
  final int streak;
  final int coins;
  final int gems;
}

/// The server picks the day and the amount; the app only asks.
class RewardsRemoteDataSource {
  RewardsRemoteDataSource(this._api);
  final ApiClient _api;

  Future<DailyRewardStatus> status(String token) async =>
      DailyRewardStatus.fromJson(await _api.get<Map<String, dynamic>>('/api/v1/rewards/daily', token: token));

  Future<(DailyRewardStatus, PlayerProfile)> claim(String token) async {
    final j = await _api.post<Map<String, dynamic>>('/api/v1/rewards/daily', body: const {}, token: token);
    return (
      DailyRewardStatus.fromJson(j['reward'] as Map<String, dynamic>),
      PlayerProfileModel.fromJson(j['profile'] as Map<String, dynamic>) as PlayerProfile,
    );
  }
}
