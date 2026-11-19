import '../../../../core/error/result.dart';
import '../entities/leaderboard_entry.dart';

abstract interface class LeaderboardRepository {
  Future<Result<List<LeaderboardEntry>>> global(String token);
}
