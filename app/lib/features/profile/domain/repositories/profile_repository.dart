import '../../../../core/error/result.dart';
import '../entities/history.dart';

abstract interface class ProfileRepository {
  Future<Result<List<MatchHistoryItem>>> matchHistory(String token);
  Future<Result<List<WalletEntry>>> walletHistory(String token);
}
