import 'package:mad_miners_core/mad_miners_core.dart';

import '../entities/match_record.dart';
import '../entities/player_account.dart';

enum PurchaseError { alreadyOwned, insufficientCoins, insufficientGems }

/// Result of looking at (or claiming) the daily reward.
class DailyStatus {
  const DailyStatus({required this.available, required this.streak, required this.coins, required this.gems});

  /// Can be claimed now.
  final bool available;

  /// The streak day that is (or was just) claimed.
  final int streak;
  final int coins;
  final int gems;

  Map<String, dynamic> toJson() => {'available': available, 'streak': streak, 'coins': coins, 'gems': gems};

  /// What [lastDay]/[lastStreak] mean for [today] (all UTC dates).
  static DailyStatus compute(DateTime? lastDay, int lastStreak, DateTime today) {
    final t = DateTime.utc(today.year, today.month, today.day);
    if (lastDay != null && lastDay == t) {
      final r = dailyReward(lastStreak);
      return DailyStatus(available: false, streak: lastStreak, coins: r.coins, gems: r.gems);
    }
    final continues = lastDay != null && lastDay == t.subtract(const Duration(days: 1));
    final next = continues ? lastStreak + 1 : 1;
    final r = dailyReward(next);
    return DailyStatus(available: true, streak: next, coins: r.coins, gems: r.gems);
  }
}

class DailyClaimedException implements Exception {
  const DailyClaimedException();
}

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

  /// Daily reward state for [today] (UTC).
  Future<DailyStatus> dailyStatus(String userId, DateTime today);

  /// Credits today's reward once. Throws [DailyClaimedException] if already
  /// claimed today. Atomic: the wallet and the claim change together.
  Future<(PlayerAccount, DailyStatus)> claimDaily(String userId, DateTime today);

  Future<List<PlayerAccount>> topByCoins(int limit);
  Future<List<PlayerAccount>> topToday(int limit);
  Future<List<MatchHistoryEntry>> matchHistory(String userId, {int limit = 20});
  Future<List<WalletTransaction>> transactions(String userId, {int limit = 30});
}
