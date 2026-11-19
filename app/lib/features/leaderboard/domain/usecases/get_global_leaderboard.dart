import '../../../../core/error/result.dart';
import '../entities/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';

class GetGlobalLeaderboard {
  const GetGlobalLeaderboard(this._repo);
  final LeaderboardRepository _repo;
  Future<Result<List<LeaderboardEntry>>> call(String token) => _repo.global(token);
}

class GetTodayLeaderboard {
  const GetTodayLeaderboard(this._repo);
  final LeaderboardRepository _repo;
  Future<Result<List<LeaderboardEntry>>> call(String token) => _repo.today(token);
}
