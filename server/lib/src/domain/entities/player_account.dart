import 'package:mad_miners_core/mad_miners_core.dart';

/// Persistent player profile (survives across matches).
class PlayerAccount {
  PlayerAccount({
    required this.id,
    required this.username,
    required this.tokenHash,
    required this.createdAt,
    this.totalCoins = 0,
    this.wallet = 0,
    this.gems = 0,
    this.xp = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.bestScore = 0,
    this.oresMined = 0,
    this.status = AccountStatus.active,
    Set<String>? owned,
    this.look = Look.standard,
    this.dayKey = '',
    this.dayWins = 0,
    this.dayCoins = 0,
    List<String>? processedRequests,
  }) : owned = owned ?? {},
       processedRequests = processedRequests ?? [];

  final String id;
  final String username;

  /// SHA-256 of the bearer token; the raw token is never stored.
  final String tokenHash;
  final DateTime createdAt;

  /// Lifetime coins earned (stats / leaderboard).
  int totalCoins;

  /// Spendable coins for cosmetics.
  int wallet;

  /// Premium currency.
  int gems;
  int xp;
  int gamesPlayed;
  int wins;
  int bestScore;
  int oresMined;
  AccountStatus status;

  /// Purchased cosmetic ids (free items are always owned).
  final Set<String> owned;
  Look look;

  /// "Today" stats for the daily leaderboard.
  String dayKey;
  int dayWins;
  int dayCoins;

  /// Recent purchase request ids, so retries never double-charge.
  final List<String> processedRequests;

  int get level => Balance.levelForXp(xp);

  bool ownsItem(String id) => (cosmeticsById[id]?.isFree ?? false) || owned.contains(id);

  static String todayKey([DateTime? now]) {
    final d = (now ?? DateTime.now()).toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _rollDay() {
    final k = todayKey();
    if (dayKey != k) {
      dayKey = k;
      dayWins = 0;
      dayCoins = 0;
    }
  }

  int get todayWins => dayKey == todayKey() ? dayWins : 0;
  int get todayCoins => dayKey == todayKey() ? dayCoins : 0;

  /// Rewards for one finished match. A treasure find counts as a win.
  void applyResult(PlayerResult r, {required bool foundTreasure}) {
    _rollDay();
    gamesPlayed++;
    totalCoins += r.score;
    wallet += r.score;
    dayCoins += r.score;
    xp += r.xp;
    oresMined += r.oresMined;
    gems += foundTreasure ? 10 : (r.rank <= 3 ? 2 : 0);
    if (foundTreasure) {
      wins++;
      dayWins++;
    }
    if (r.score > bestScore) bestScore = r.score;
  }

  /// Public view (no secrets).
  Map<String, dynamic> toPublicJson() => {
    'playerId': id,
    'username': username,
    'level': level,
    'xp': xp,
    'totalCoins': totalCoins,
    'wallet': wallet,
    'gems': gems,
    'gamesPlayed': gamesPlayed,
    'wins': wins,
    'bestScore': bestScore,
    'oresMined': oresMined,
    'todayWins': todayWins,
    'todayCoins': todayCoins,
    'owned': owned.toList(),
    'look': look.toJson(),
  };

  Map<String, dynamic> toJson() => {
    ...toPublicJson(),
    'tokenHash': tokenHash,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'dayKey': dayKey,
    'dayWins': dayWins,
    'dayCoins': dayCoins,
    'processed': processedRequests,
  };

  factory PlayerAccount.fromJson(Map<String, dynamic> j) => PlayerAccount(
    id: j['playerId'] as String,
    username: j['username'] as String,
    tokenHash: j['tokenHash'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    totalCoins: j['totalCoins'] as int? ?? 0,
    wallet: j['wallet'] as int? ?? (j['totalCoins'] as int? ?? 0),
    gems: j['gems'] as int? ?? 0,
    xp: j['xp'] as int? ?? 0,
    gamesPlayed: j['gamesPlayed'] as int? ?? 0,
    wins: j['wins'] as int? ?? 0,
    bestScore: j['bestScore'] as int? ?? 0,
    oresMined: j['oresMined'] as int? ?? 0,
    status: AccountStatus.values.asNameMap()[j['status']] ?? AccountStatus.active,
    owned: {...(j['owned'] as List? ?? const []).cast<String>()},
    look: Look.fromJson(j['look']),
    dayKey: j['dayKey'] as String? ?? '',
    dayWins: j['dayWins'] as int? ?? 0,
    dayCoins: j['dayCoins'] as int? ?? 0,
    processedRequests: (j['processed'] as List? ?? const []).cast<String>().toList(),
  );
}

enum AccountStatus { active, suspended, banned }
