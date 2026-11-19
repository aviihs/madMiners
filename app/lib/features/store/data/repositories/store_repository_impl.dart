import '../../../../core/error/result.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../../auth/domain/entities/player_profile.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_remote_data_source.dart';

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl(this._remote);
  final StoreRemoteDataSource _remote;

  @override
  Future<Result<PlayerProfile>> purchase(String token, String itemId) => guard(() => _remote.purchase(token, itemId));

  @override
  Future<Result<PlayerProfile>> equip(String token, String itemId) => guard(() => _remote.equip(token, itemId));
}
