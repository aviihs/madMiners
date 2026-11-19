import 'package:equatable/equatable.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({required this.rank, required this.playerId, required this.username, required this.level, required this.totalCoins, required this.wins, this.todayWins = 0, this.todayCoins = 0, this.look});
  final int rank;
  final String playerId;
  final String username;
  final int level;
  final int totalCoins;
  final int wins;
  final int todayWins;
  final int todayCoins;
  final Look? look;

  @override
  List<Object?> get props => [rank, playerId, username, level, totalCoins, wins, todayWins, todayCoins];
}
