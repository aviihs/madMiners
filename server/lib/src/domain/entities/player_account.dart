import 'package:mad_miners_core/mad_miners_core.dart';

/// Persistent player profile (survives across matches).
class PlayerAccount {
  PlayerAccount({
    required this.id,
    required this.username,
    required this.tokenHash,
    required this.createdAt,
    this.totalCoins = 0,
    this.xp = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.bestScore = 0,
    this.oresMined = 0,
    this.status = AccountStatus.active,
  });

  final String id;
  final String username;

  /// SHA-256 of the bearer token; the raw token is never stored.
  final String tokenHash;
  final DateTime createdAt;
  int totalCoins;
  int xp;
  int gamesPlayed;
  int wins;
  int bestScore;
  int oresMined;
  AccountStatus status;

  int get level => Balance.levelForXp(xp);

  void applyResult(PlayerResult r) {
    gamesPlayed++;
    totalCoins += r.score;
    xp += r.xp;
    oresMined += r.oresMined;
    if (r.rank == 1) wins++;
    if (r.score > bestScore) bestScore = r.score;
  }

  /// Public view (no secrets).
  Map<String, dynamic> toPublicJson() => {
    'playerId': id,
    'username': username,
    'level': level,
    'xp': xp,
    'totalCoins': totalCoins,
    'gamesPlayed': gamesPlayed,
    'wins': wins,
    'bestScore': bestScore,
    'oresMined': oresMined,
  };

  Map<String, dynamic> toJson() => {
    ...toPublicJson(),
    'tokenHash': tokenHash,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory PlayerAccount.fromJson(Map<String, dynamic> j) => PlayerAccount(
    id: j['playerId'] as String,
    username: j['username'] as String,
    tokenHash: j['tokenHash'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    totalCoins: j['totalCoins'] as int? ?? 0,
    xp: j['xp'] as int? ?? 0,
    gamesPlayed: j['gamesPlayed'] as int? ?? 0,
    wins: j['wins'] as int? ?? 0,
    bestScore: j['bestScore'] as int? ?? 0,
    oresMined: j['oresMined'] as int? ?? 0,
    status: AccountStatus.values.asNameMap()[j['status']] ?? AccountStatus.active,
  );
}

enum AccountStatus { active, suspended, banned }
