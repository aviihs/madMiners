import '../entities/player_account.dart';

/// Persistence port. Swap the JSON-file adapter for PostgreSQL without
/// touching application code.
abstract interface class AccountRepository {
  Future<PlayerAccount?> findById(String id);
  Future<PlayerAccount?> findByTokenHash(String tokenHash);
  Future<bool> usernameTaken(String username);
  Future<void> save(PlayerAccount account);

  /// Saves several accounts atomically (end-of-match rewards).
  Future<void> saveAll(Iterable<PlayerAccount> accounts);
  Future<List<PlayerAccount>> topByCoins(int limit);

  /// Today's ranking: most treasure finds, then most coins.
  Future<List<PlayerAccount>> topToday(int limit);
}
