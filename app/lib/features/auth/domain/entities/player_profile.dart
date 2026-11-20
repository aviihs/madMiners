import 'package:equatable/equatable.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

class PlayerProfile extends Equatable {
  const PlayerProfile({
    required this.id,
    required this.username,
    this.level = 1,
    this.xp = 0,
    this.totalCoins = 0,
    this.wallet = 0,
    this.gems = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.bestScore = 0,
    this.bestDepth = 0,
    this.oresMined = 0,
    this.todayWins = 0,
    this.providers = const [],
    this.email,
    this.owned = const {},
    this.look = Look.standard,
  });

  final String id;
  final String username;
  final int level;
  final int xp;
  final int totalCoins;

  /// Spendable coins for cosmetics.
  final int wallet;

  /// Premium currency.
  final int gems;
  final int gamesPlayed;
  final int wins;
  final int bestScore;
  final int bestDepth;
  final int oresMined;
  final int todayWins;

  /// Linked sign-in methods, e.g. ['guest', 'google'].
  final List<String> providers;
  final String? email;

  bool get hasGoogle => providers.contains('google');
  final Set<String> owned;
  final Look look;

  bool owns(CosmeticDef c) => c.isFree || owned.contains(c.id);

  @override
  List<Object?> get props => [id, username, level, xp, totalCoins, wallet, gems, gamesPlayed, wins, bestScore, bestDepth, oresMined, todayWins, owned, look, providers, email];
}
