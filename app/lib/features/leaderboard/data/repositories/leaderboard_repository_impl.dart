import '../../../../core/error/result.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_data_source.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  LeaderboardRepositoryImpl(this._remote);
  final LeaderboardRemoteDataSource _remote;

  @override
  Future<Result<List<LeaderboardEntry>>> global(String token) => guard(() => _remote.global(token));
}
