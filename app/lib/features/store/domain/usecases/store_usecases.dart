import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/player_profile.dart';
import '../repositories/store_repository.dart';

class PurchaseCosmetic {
  const PurchaseCosmetic(this._repo);
  final StoreRepository _repo;
  Future<Result<PlayerProfile>> call(String token, String itemId) => _repo.purchase(token, itemId);
}

class EquipCosmetic {
  const EquipCosmetic(this._repo);
  final StoreRepository _repo;
  Future<Result<PlayerProfile>> call(String token, String itemId) => _repo.equip(token, itemId);
}
