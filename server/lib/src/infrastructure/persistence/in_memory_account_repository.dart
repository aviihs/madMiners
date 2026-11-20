import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/match_record.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/repositories/account_repository.dart';

/// In-memory adapter with the same semantics as the PostgreSQL one.
/// Used by tests; never in production.
class InMemoryAccountRepository implements AccountRepository {
  final Map<String, _Row> _users = {};
  final Map<String, String> _identities = {}; // provider:subject -> userId
  final Map<String, (String, DateTime)> _sessions = {};
  final List<(MatchRecord, DateTime)> _matches = [];
  final List<(String, WalletTransaction, String?)> _tx = [];
  int _txSeq = 0;

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  PlayerAccount _view(_Row r) => PlayerAccount(
    id: r.id,
    username: r.username,
    createdAt: r.createdAt,
    stats: r.stats,
    coins: r.coins,
    gems: r.gems,
    owned: {...r.owned},
    look: Look.fromSlots(r.equipped),
    todayWins: r.dayKey == _today() ? r.dayWins : 0,
    todayCoins: r.dayKey == _today() ? r.dayCoins : 0,
    providers: [...r.providers],
    email: r.email,
  );

  @override
  Future<PlayerAccount?> findById(String id) async => _users[id] == null ? null : _view(_users[id]!);

  @override
  Future<PlayerAccount?> findBySession(String tokenHash) async {
    final s = _sessions[tokenHash];
    if (s == null || s.$2.isBefore(DateTime.now())) return null;
    return findById(s.$1);
  }

  @override
  Future<String?> findUserIdByIdentity(String provider, String subject) async => _identities['$provider:$subject'];

  @override
  Future<bool> usernameTaken(String username) async => _users.values.any((u) => u.username.toLowerCase() == username.toLowerCase());

  @override
  Future<PlayerAccount> createUser({required String id, required String username, required Identity identity}) async {
    if (await usernameTaken(username)) throw StateError('duplicate username');
    _users[id] = _Row(id, username, DateTime.now());
    await linkIdentity(id, identity);
    return _view(_users[id]!);
  }

  @override
  Future<void> linkIdentity(String userId, Identity identity) async {
    final key = '${identity.provider}:${identity.subject}';
    if (_identities.containsKey(key)) throw StateError('identity already linked');
    _identities[key] = userId;
    _users[userId]!
      ..providers.add(identity.provider)
      ..email ??= identity.email;
  }

  @override
  Future<void> createSession(String userId, String tokenHash, DateTime expiresAt) async => _sessions[tokenHash] = (userId, expiresAt);

  @override
  Future<void> deleteSession(String tokenHash) async => _sessions.remove(tokenHash);

  void _credit(String userId, String currency, int amount, String kind, String ref, {String? requestId}) {
    final u = _users[userId]!;
    if (currency == 'coins') {
      u.coins += amount;
    } else {
      u.gems += amount;
    }
    _tx.add((
      userId,
      WalletTransaction(
        id: ++_txSeq,
        kind: kind,
        currency: currency,
        amount: amount,
        balanceAfter: currency == 'coins' ? u.coins : u.gems,
        reference: ref,
        createdAt: DateTime.now(),
      ),
      requestId,
    ));
  }

  @override
  Future<void> recordMatch(MatchRecord m) async {
    _matches.add((m, DateTime.now()));
    for (final pr in m.players) {
      final u = _users[pr.userId];
      if (u == null) continue;
      final r = pr.result;
      u.stats = PlayerStats(
        xp: u.stats.xp + pr.reward.xp,
        gamesPlayed: u.stats.gamesPlayed + 1,
        wins: u.stats.wins + (pr.foundTreasure ? 1 : 0),
        bestScore: r.score > u.stats.bestScore ? r.score : u.stats.bestScore,
        bestDepth: r.maxDepth > u.stats.bestDepth ? r.maxDepth : u.stats.bestDepth,
        oresMined: u.stats.oresMined + r.oresMined,
        totalCoins: u.stats.totalCoins + pr.reward.coins,
      );
      if (u.dayKey != _today()) {
        u
          ..dayKey = _today()
          ..dayWins = 0
          ..dayCoins = 0;
      }
      u
        ..dayWins += pr.foundTreasure ? 1 : 0
        ..dayCoins += pr.reward.coins;
      if (pr.reward.coins > 0) _credit(u.id, 'coins', pr.reward.coins, 'match_reward', 'match:${m.id}');
      if (pr.reward.gems > 0) _credit(u.id, 'gems', pr.reward.gems, 'match_reward', 'match:${m.id}');
    }
  }

  @override
  Future<PlayerAccount> purchase(String userId, CosmeticDef item, String requestId) async {
    final u = _users[userId]!;
    if (_tx.any((t) => t.$1 == userId && t.$3 == requestId)) return _view(u);
    if (item.isFree || u.owned.contains(item.id)) throw const PurchaseException(PurchaseError.alreadyOwned);
    final gems = item.currency == Currency.gems;
    if ((gems ? u.gems : u.coins) < item.price) {
      throw PurchaseException(gems ? PurchaseError.insufficientGems : PurchaseError.insufficientCoins);
    }
    _credit(userId, gems ? 'gems' : 'coins', -item.price, 'purchase', 'item:${item.id}', requestId: requestId);
    u.owned.add(item.id);
    return _view(u);
  }

  @override
  Future<PlayerAccount> equip(String userId, CosmeticDef item) async {
    _users[userId]!.equipped[item.slot.name] = item.id;
    return _view(_users[userId]!);
  }

  @override
  Future<List<PlayerAccount>> topByCoins(int limit) async =>
      (_users.values.map(_view).toList()..sort((a, b) => b.stats.totalCoins.compareTo(a.stats.totalCoins))).take(limit).toList();

  @override
  Future<List<PlayerAccount>> topToday(int limit) async {
    final list = _users.values.map(_view).where((a) => a.todayWins > 0 || a.todayCoins > 0).toList()
      ..sort((a, b) {
        final w = b.todayWins.compareTo(a.todayWins);
        return w != 0 ? w : b.todayCoins.compareTo(a.todayCoins);
      });
    return list.take(limit).toList();
  }

  @override
  Future<List<MatchHistoryEntry>> matchHistory(String userId, {int limit = 20}) async => [
    for (final (m, at) in _matches.reversed)
      for (final pr in m.players.where((p) => p.userId == userId))
        MatchHistoryEntry(
          matchId: m.id,
          mapId: m.mapId.name,
          mode: m.mode.name,
          endedAt: at,
          rank: pr.result.rank,
          score: pr.result.score,
          maxDepth: pr.result.maxDepth,
          foundTreasure: pr.foundTreasure,
          playerCount: m.playerCount,
          winnerName: m.winnerName,
          coinsAwarded: pr.reward.coins,
          gemsAwarded: pr.reward.gems,
        ),
  ].take(limit).toList();

  @override
  Future<List<WalletTransaction>> transactions(String userId, {int limit = 30}) async =>
      _tx.reversed.where((t) => t.$1 == userId).map((t) => t.$2).take(limit).toList();

  final Map<String, (DateTime, int)> _daily = {};

  @override
  Future<DailyStatus> dailyStatus(String userId, DateTime today) async {
    final d = _daily[userId];
    return DailyStatus.compute(d?.$1, d?.$2 ?? 0, today);
  }

  @override
  Future<(PlayerAccount, DailyStatus)> claimDaily(String userId, DateTime today) async {
    final st = await dailyStatus(userId, today);
    if (!st.available) throw const DailyClaimedException();
    final day = DateTime.utc(today.year, today.month, today.day);
    _daily[userId] = (day, st.streak);
    final ref = 'daily:${day.toIso8601String().substring(0, 10)}';
    _credit(userId, 'coins', st.coins, 'daily_reward', ref);
    if (st.gems > 0) _credit(userId, 'gems', st.gems, 'daily_reward', ref);
    return (_view(_users[userId]!), DailyStatus(available: false, streak: st.streak, coins: st.coins, gems: st.gems));
  }

  /// Test helper: give someone money.
  void grant(String userId, {int coins = 0, int gems = 0}) {
    if (coins != 0) _credit(userId, 'coins', coins, 'grant', 'test');
    if (gems != 0) _credit(userId, 'gems', gems, 'grant', 'test');
  }
}

class _Row {
  _Row(this.id, this.username, this.createdAt);
  final String id;
  final String username;
  final DateTime createdAt;
  PlayerStats stats = const PlayerStats();
  int coins = 0;
  int gems = 0;
  final Set<String> owned = {};
  final Map<String, String> equipped = {};
  final List<String> providers = [];
  String? email;
  String dayKey = '';
  int dayWins = 0;
  int dayCoins = 0;
}
