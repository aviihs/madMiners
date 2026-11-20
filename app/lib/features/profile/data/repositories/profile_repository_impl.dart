import '../../../../core/error/result.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/history.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);
  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<List<MatchHistoryItem>>> matchHistory(String token) => guard(() => _remote.matches(token));

  @override
  Future<Result<List<WalletEntry>>> walletHistory(String token) => guard(() => _remote.transactions(token));
}
