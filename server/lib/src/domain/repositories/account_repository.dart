import 'package:mad_miners_core/mad_miners_core.dart';

import '../entities/match_record.dart';
import '../entities/player_account.dart';

enum PurchaseError { alreadyOwned, insufficientCoins, insufficientGems }

class PurchaseException implements Exception {
  const PurchaseException(this.error);
  final PurchaseError error;
}

/// Persistence port. Implemented by PostgreSQL (production) and an
/// in-memory adapter (tests). Every multi-step write is atomic.
abstract interface class AccountRepository {
  Future<PlayerAccount?> findById(String id);
  Future<PlayerAccount?> findBySession(String tokenHash);
  Future<String?> findUserIdByIdentity(String provider, String subject);
  Future<bool> usernameTaken(String username);

  /// Creates user + stats + wallet + identity.
  Future<PlayerAccount> createUser({required String id, required String username, required Identity identity});
  Future<void> linkIdentity(String userId, Identity identity);
  Future<void> createSession(String userId, String tokenHash, DateTime expiresAt);
  Future<void> deleteSession(String tokenHash);

  /// Match + per-player results + stats + wallet credit + transactions + daily stats.
  Future<void> recordMatch(MatchRecord match);

  /// Debits the wallet and grants the item. Idempotent per [requestId].
  /// Throws [PurchaseException].
  Future<PlayerAccount> purchase(String userId, CosmeticDef item, String requestId);
  Future<PlayerAccount> equip(String userId, CosmeticDef item);

  Future<List<PlayerAccount>> topByCoins(int limit);
  Future<List<PlayerAccount>> topToday(int limit);
  Future<List<MatchHistoryEntry>> matchHistory(String userId, {int limit = 20});
  Future<List<WalletTransaction>> transactions(String userId, {int limit = 30});
}
