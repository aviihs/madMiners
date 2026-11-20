import 'package:mad_miners_core/mad_miners_core.dart';

/// Read model of a player, assembled from several tables.
class PlayerAccount {
  const PlayerAccount({
    required this.id,
    required this.username,
    required this.createdAt,
    this.status = AccountStatus.active,
    this.stats = const PlayerStats(),
    this.coins = 0,
    this.gems = 0,
    this.owned = const {},
    this.look = Look.standard,
    this.todayWins = 0,
    this.todayCoins = 0,
    this.providers = const [],
    this.email,
  });

  final String id;
  final String username;
  final DateTime createdAt;
  final AccountStatus status;
  final PlayerStats stats;

  /// Spendable wallet.
  final int coins;
  final int gems;

  /// Purchased cosmetic ids (free items are always owned).
  final Set<String> owned;
  final Look look;
  final int todayWins;
  final int todayCoins;

  /// Sign-in methods linked to this account, e.g. ['guest', 'google'].
  final List<String> providers;
  final String? email;

  int get level => Balance.levelForXp(stats.xp);
  bool ownsItem(String id) => (cosmeticsById[id]?.isFree ?? false) || owned.contains(id);

  Map<String, dynamic> toPublicJson() => {
    'playerId': id,
    'username': username,
    'level': level,
    'xp': stats.xp,
    'totalCoins': stats.totalCoins,
    'wallet': coins,
    'gems': gems,
    'gamesPlayed': stats.gamesPlayed,
    'wins': stats.wins,
    'bestScore': stats.bestScore,
    'bestDepth': stats.bestDepth,
    'oresMined': stats.oresMined,
    'todayWins': todayWins,
    'todayCoins': todayCoins,
    'owned': owned.toList(),
    'look': look.toJson(),
    'providers': providers,
    if (email != null) 'email': email,
  };

  /// Leaderboard view: no private fields.
  Map<String, dynamic> toRankJson() => {
    'playerId': id,
    'username': username,
    'level': level,
    'totalCoins': stats.totalCoins,
    'wins': stats.wins,
    'bestScore': stats.bestScore,
    'todayWins': todayWins,
    'todayCoins': todayCoins,
    'look': look.toJson(),
  };
}

class PlayerStats {
  const PlayerStats({
    this.xp = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.bestScore = 0,
    this.bestDepth = 0,
    this.oresMined = 0,
    this.totalCoins = 0,
  });

  final int xp;
  final int gamesPlayed;
  final int wins;
  final int bestScore;
  final int bestDepth;
  final int oresMined;
  final int totalCoins;
}

enum AccountStatus { active, suspended, banned }

/// A way to sign in.
class Identity {
  const Identity(this.provider, this.subject, {this.email});
  final String provider; // guest | google
  final String subject;
  final String? email;
}
