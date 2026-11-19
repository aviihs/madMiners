import 'package:equatable/equatable.dart';

class PlayerProfile extends Equatable {
  const PlayerProfile({
    required this.id,
    required this.username,
    this.level = 1,
    this.xp = 0,
    this.totalCoins = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.bestScore = 0,
  });

  final String id;
  final String username;
  final int level;
  final int xp;
  final int totalCoins;
  final int gamesPlayed;
  final int wins;
  final int bestScore;

  @override
  List<Object?> get props => [id, username, level, xp, totalCoins, gamesPlayed, wins, bestScore];
}
