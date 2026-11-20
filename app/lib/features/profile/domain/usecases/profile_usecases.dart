import '../../../../core/error/result.dart';
import '../entities/history.dart';
import '../repositories/profile_repository.dart';

class GetMatchHistory {
  const GetMatchHistory(this._repo);
  final ProfileRepository _repo;
  Future<Result<List<MatchHistoryItem>>> call(String token) => _repo.matchHistory(token);
}

class GetWalletHistory {
  const GetWalletHistory(this._repo);
  final ProfileRepository _repo;
  Future<Result<List<WalletEntry>>> call(String token) => _repo.walletHistory(token);
}
