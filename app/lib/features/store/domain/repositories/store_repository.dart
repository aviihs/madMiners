import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/player_profile.dart';

/// Cosmetics store. The server validates every purchase; we only send intent.
abstract interface class StoreRepository {
  Future<Result<PlayerProfile>> purchase(String token, String itemId);
  Future<Result<PlayerProfile>> equip(String token, String itemId);
}
